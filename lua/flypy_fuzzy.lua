require("lib/string")
local P = {}
local T = {}
local F = {}
local M = {}

local function ensure_processor_resources(env)
    if env.mem_flyhe and env.reversedb and env.reversedb_flyhe then return end

    local config = env.engine.schema.config
    local flyhe_schema = Schema("flyhe_fast")
    local schema_id = config:get_string("schema/schema_id")
    env.reversedb = env.reversedb or ReverseLookup(schema_id)
    env.reversedb_flyhe = env.reversedb_flyhe or ReverseLookup("flyhe_fast")
    env.mem_flyhe = env.mem_flyhe or Memory(env.engine, flyhe_schema, "translator")
end

local function ensure_translator_resources(env)
    if env.flyhe_fuzz_tran and env.reversedb then return end

    local config = env.engine.schema.config
    local flyhe_schema = Schema("flyhe_fast")
    local schema_id = config:get_string("schema/schema_id")
    env.reversedb = env.reversedb or ReverseLookup(schema_id)
    env.flyhe_fuzz_tran = env.flyhe_fuzz_tran or
        Component.ScriptTranslator(env.engine, flyhe_schema, "translator", "")
end

local function reverse_code_matches(env, text, code)
    local reverse_code = env.reversedb:lookup(text)
    for syllable in reverse_code:gmatch("%S+") do
        if syllable:match("^" .. code:gsub("([^%w])", "%%%1") .. "~") then
            return true
        end
    end
    return false
end

local function select_full_encode_by_code(env, text, full_encodes, code)
    local matched_index = nil
    local index = 0
    for syllable in env.reversedb:lookup(text):gmatch("%S+") do
        index = index + 1
        if syllable:match("^" .. code:gsub("([^%w])", "%%%1") .. "~") then
            matched_index = index
            break
        end
    end
    if not matched_index then return nil end

    index = 0
    for syllable in full_encodes:gmatch("%S+") do
        index = index + 1
        if index == matched_index then return syllable end
    end
    return nil
end

local function check_fuzzy_cand(env, cand, input, expected_length, tail_code)
    if not cand then return false end
    if cand.quality < 0.1 then return false end

    local cand_text = cand.text
    local cand_length = utf8.len(cand_text)
    if utf8.len(cand_text) <= 1 then return false end
    if #input - cand_length > 1 then return false end
    if expected_length and cand_text:match("[%a%d%p%s]") then return false end
    if expected_length and cand_length ~= expected_length then return false end
    if (not expected_length) and (cand_length ~= #input) then return false end

    local tail_text = string.utf8_sub(cand_text, -1, -1)
    if not tail_text then return false end

    if not tail_text:match("[%a%d%p]") then
        if tail_code then
            return reverse_code_matches(env, tail_text, tail_code)
        end

        local reverse_code = env.reversedb:lookup(tail_text)
        local fuzzy_tail_code = reverse_code:gsub("%l~%l%l ?", "")
        if fuzzy_tail_code:match(input:sub(-1, -1)) then return true end
        return false
    end
    return true
end

local function update_flyhe_userdb(env, input_code, cand_text, input_codes)
    local function get_full_encode(input, text, codes)
        local loop_count = 0
        local full_encode = ""
        local zero_text_exist = false
        local zcs_viu_map = {
            ["v"] = "zh",
            ["i"] = "ch",
            ["u"] = "sh",
        }
        for _, code in utf8.codes(text) do
            loop_count = (not zero_text_exist) and (loop_count + 1) or loop_count
            local match_slab_encode = nil
            local per_text = utf8.char(code)
            local per_encode = codes and codes[loop_count] or input:sub(loop_count, loop_count)
            local is_full_code = #per_encode > 1
            local text_encode = env.reversedb_flyhe:lookup(per_text)
            if tostring(per_text):match("0") then
                if per_encode == "" then
                    per_encode = "o0"
                elseif not text_encode:match(per_encode) then
                    zero_text_exist = true
                    per_encode = "o0"
                end
            else
                per_encode = zcs_viu_map[per_encode] or per_encode
            end
            if per_text:match("^[A-Z]$") then
                text_encode = text_encode:sub(3, 4)
            end
            if text_encode:match("^[a-zA-Z]+$") then
                full_encode = (#full_encode < 1) and text_encode or (full_encode .. " " .. text_encode)
            else
                -- 多音字
                if text_encode:match(" ") and text_encode:match("[a-z]") then
                    if is_full_code then
                        match_slab_encode = select_full_encode_by_code(env, per_text, text_encode, per_encode)
                    else
                        local slabs = string.split(text_encode, " ")
                        for _, value in ipairs(slabs) do
                            if value:match("^" .. per_encode) then
                                match_slab_encode = value
                            end
                        end
                    end
                else -- 单音字
                    match_slab_encode = text_encode
                end
                if match_slab_encode then
                    full_encode = (#full_encode < 1) and match_slab_encode
                        or (full_encode .. " " .. match_slab_encode)
                end
            end
        end
        if full_encode:match("o0 o0 o0") then
            full_encode = full_encode:gsub("o0 o0 o0", "qm")
        elseif full_encode:match("o0 o0") then
            full_encode = full_encode:gsub("o0 o0", "bd")
        elseif full_encode:match("o0") then
            full_encode = full_encode:gsub("o0", "ui")
        end
        return full_encode
    end
    local text = cand_text:gsub(" ", "")
    local full_encode = get_full_encode(input_code, text, input_codes)
    local de = DictEntry()
    de.text = cand_text
    de.weight = 1
    de.custom_code = full_encode .. " "
    env.mem_flyhe:update_userdict(de, 1, "")
end

function M.init(env)
    local config = env.engine.schema.config
    env.fuzz_max_length = config:get_int("flypy_fuzzy/fuzz_max_length") or 7
    env.fuzz_start_length = config:get_int("flypy_fuzzy/fuzz_start_length") or 2
    -- env.fuzz_scan_limit = config:get_int("flypy_fuzzy/fuzz_scan_limit") or 100
    env.word_lookup_limit = config:get_int("flypy_fuzzy/word_lookup_limit") or 300
    env.enable_fuzz_func = config:get_bool("flypy_fuzzy/enable_fuzz_func") or false
    env.expand_idiom_key = config:get_string("key_binder/fuzz_algebra_first") or "Control+q"
end

function P.init(env)
    M.init(env)
    ensure_processor_resources(env)

    local context = env.engine.context
    env.commit_fuzz_cand_notify = context.commit_notifier:connect(function(ctx)
        ctx:set_property("idiom_phrase_first", "0")

        local raw_input = ctx.input
        local cand = context:get_selected_candidate()
        if (not raw_input) or (not cand)
            or (
                (cand.type ~= "fuzzy_word")
                and (cand.type ~= "idiom_phrase")
            )
        then
            return
        end

        local cand_length = utf8.len(cand.text)
        local input_codes = nil
        if #raw_input == 4 and cand_length == 3 and not cand.text:match("[%a%d%p%s]") then
            input_codes = {
                raw_input:sub(1, 1),
                raw_input:sub(2, 2),
                raw_input:sub(3, 4),
            }
        end
        update_flyhe_userdb(env, raw_input, cand.text, input_codes)
    end)
end

function M.fini(env)
    if env.commit_fuzz_cand_notify then
        env.commit_fuzz_cand_notify:disconnect()
        env.commit_fuzz_cand_notify = nil
    end
    if env.mem_flyhe then
        env.mem_flyhe:disconnect()
        env.mem_flyhe = nil
        collectgarbage('collect')
    end
    if env.flyhe_fuzz_tran then
        env.flyhe_fuzz_tran = nil
    end
    if env.reversedb then
        env.reversedb = nil
    end
    if env.reversedb_flyhe then
        env.reversedb_flyhe = nil
    end
end

function T.init(env)
    M.init(env)
    ensure_translator_resources(env)
end

function P.func(key, env)
    local engine = env.engine
    local context = engine.context
    local composition = context.composition
    if composition:empty() then return 2 end

    local raw_input = context.input
    local phrase_first_state = context:get_property("idiom_phrase_first")

    -- 简拼候选, 按下`8/Control+q`, 简拼优先
    if
        context:has_menu()
        and (key:repr() == env.expand_idiom_key)
        and (raw_input:match("^%l%l%l%l?%l?%l?$"))
    then
        local switch_val = (phrase_first_state == "1") and "0" or "1"
        context:set_property("idiom_phrase_first", tostring(switch_val))
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1                                    -- kAccept
    end

    return 2 -- kNoop
end

function T.func(input, seg, env)
    ensure_translator_resources(env)

    local context = env.engine.context
    local composition = context.composition
    if composition:empty() then return end

    -- 简拼候选, 按下`8/Control+q`, 简拼优先
    local raw_input = context.input
    local phrase_first_state = context:get_property("idiom_phrase_first")
    local match_pattern = string.format("^[a-z]{%d,%d}$", env.fuzz_start_length, env.fuzz_max_length)
    if env.enable_fuzz_func and rime_api.regex_match(raw_input, match_pattern) then
        local yielded_text = {}
        local query_specs = {
            {
                query = raw_input,
                expected_length = nil,
            },
        }
        if #raw_input == 4 then
            table.insert(query_specs, {
                query = raw_input:sub(1, 1) .. "'" .. raw_input:sub(2, 2) .. "'" .. raw_input:sub(3, 4),
                expected_length = 3,
                tail_code = raw_input:sub(3, 4),
            })
        end

        for _, query_spec in ipairs(query_specs) do
            local word_cands = env.flyhe_fuzz_tran:query(query_spec.query, seg) or nil
            if word_cands then
                local yielded_count = 0
                for cand in word_cands:iter() do

                    if not yielded_text[cand.text]
                        and check_fuzzy_cand(
                            env,
                            cand,
                            raw_input,
                            query_spec.expected_length,
                            query_spec.tail_code
                        )
                    then
                        local fuzz_cand = nil
                        if phrase_first_state == "1" then
                            fuzz_cand = Candidate("idiom_phrase", seg.start, seg._end, cand.text, "")
                        else
                            fuzz_cand = Candidate("fuzzy_word", seg.start, seg._end, cand.text, "")
                        end
                        yield(fuzz_cand)
                        yielded_text[cand.text] = true
                        yielded_count = yielded_count + 1
                        if yielded_count >= env.word_lookup_limit then break end
                    end
                end
            end
        end
    end
end

---@diagnostic disable-next-line: unused-local
function F.func(input, env)
    local idiom_cands = {}
    local other_cands = {}

    for cand in input:iter() do
        if cand.type:match("^idiom_phrase") then
            table.insert(idiom_cands, cand)
        else
            table.insert(other_cands, cand)
        end

        if #other_cands >= 666 then break end
    end

    if #idiom_cands > 0 then
        for _, cand in ipairs(idiom_cands) do
            yield(cand)
        end
    end

    for _, cand in ipairs(other_cands) do yield(cand) end
end

return {
    processor = {
        init = P.init,
        func = P.func,
        fini = M.fini,
    },
    translator = {
        init = T.init,
        func = T.func,
        fini = M.fini,
    },
    filter = {
        init = M.init,
        func = F.func,
        fini = M.fini,
    },
}
