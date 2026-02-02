require("lib/string")
local P = {}
local T = {}
local F = {}

local function check_fuzzy_cand(env, cand, input)
    if not cand then
        return false
    end
    if cand.quality < 0.1 then
        return false
    end
    local cand_text = cand.text
    if utf8.len(cand_text) <= 1 then
        return false
    end
    if (not cand_text:match("[%a%d%p]")) and utf8.len(cand_text) ~= #input then
        return false
    end
    if #input - utf8.len(cand_text) > 1 then
        return false
    end
    local tail_text = string.utf8_sub(cand_text, -1, -1)
    if not tail_text then
        return false
    end
    if not tail_text:match("[%a%d%p]") then
        local _tail_code = env.reversedb:lookup(tail_text)
        local tail_code = _tail_code:gsub("%l~%l%l ?", "")
        if tail_code:match(input:sub(-1, -1)) then
            return true
        end
        return false
    end
    return true
end

local function update_flyhe_userdb(env, input_code, cand_text)
    local function get_full_encode(input, text)
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
            local per_encode = input:sub(loop_count, loop_count)
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
                    local slabs = string.split(text_encode, " ")
                    for _, value in ipairs(slabs) do
                        if value:match("^" .. per_encode) then
                            match_slab_encode = value
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
    local full_encode = get_full_encode(input_code, text)
    local de = DictEntry()
    de.text = cand_text
    de.weight = 1
    de.custom_code = full_encode .. " "
    env.mem_flyhe:update_userdict(de, 1, "")
end

function P.init(env)
    local context = env.engine.context
    local config = env.engine.schema.config
    local flyhe_schema = Schema("flyhe_fast")
    env.reversedb_flyhe = ReverseLookup("flyhe_fast")
    env.mem_flyhe = Memory(env.engine, flyhe_schema, "translator")
    env.expand_idiom_key = config:get_string("key_binder/simpy_expand_key") or "Control+q"

    env.commit_fuzz_cand_notify = context.commit_notifier:connect(function(ctx)
        ctx:set_property("idiom_phrase_first", "0")

        local input_code = ctx.input
        local cand = context:get_selected_candidate()
        if (not input_code) or not cand then
            return
        end
        if cand.type ~= "fuzzy_word" then
            return
        end
        update_flyhe_userdb(env, input_code, cand.text)
    end)
end

function P.fini(env)
    if env.commit_fuzz_cand_notify then
        env.commit_fuzz_cand_notify:disconnect()
        env.commit_fuzz_cand_notify = nil
    end
    if env.mem_flyhe then
        env.mem_flyhe:disconnect()
        env.mem_flyhe = nil
    end
end

function T.init(env)
    local config = env.engine.schema.config
    local schema_id = config:get_string("schema/schema_id")
    local flyhe_schema = Schema("flyhe_fast")
    env.reversedb = ReverseLookup(schema_id)
    env.enable_fuzz_func = config:get_bool("speller/enable_fuzz_algebra") or false
    -- env.flyhe_fuzz_tran = Component.Translator(env.engine, schema, "", "script_translator@flyhe_fuzz")
    env.flyhe_fuzz_tran = Component.Translator(env.engine, flyhe_schema, "", "script_translator@translator")
end

function T.fini(env)
    if env.flyhe_fuzz_tran then
        env.flyhe_fuzz_tran = nil
    end
end

function P.func(key, env)
    local engine = env.engine
    local context = engine.context
    local composition = context.composition
    if composition:empty() then
        return 2
    end
    local preedit_text = context:get_preedit().text
    local preedit_code = preedit_text:gsub("[‸ ]", "")
    local phrase_first_state = context:get_property("idiom_phrase_first")

    -- 触发简码成语优先
    if
        context:has_menu()
        and (preedit_code:match("^%l%l%l%l?%l?%l?$"))
        and (key:repr() == env.expand_idiom_key)
    then
        local switch_val = (phrase_first_state == "1") and "0" or "1"
        context:set_property("idiom_phrase_first", tostring(switch_val))
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1 -- kAccept
    end

    return 2 -- kNoop
end

function T.func(input, seg, env)
    local context = env.engine.context
    local composition = context.composition
    if composition:empty() then return end

    -- 简拼候选, 按下`8/Control+q`, 简拼优先
    local input_code = context.input
    local phrase_first_state = context:get_property("idiom_phrase_first")
    if env.enable_fuzz_func and (input_code:match("^[a-z]+$")) and (input_code:len() >= 2) and (input_code:len() <= 7) then
        local word_cands = env.flyhe_fuzz_tran:query(input, seg) or nil
        if not word_cands then return end

        for cand in word_cands:iter() do
            if check_fuzzy_cand(env, cand, input_code) then
                local fuzz_cand = nil
                if phrase_first_state == "1" then
                    fuzz_cand = Candidate("idiom_phrase", seg.start, seg._end, cand.text, "")
                else
                    fuzz_cand = Candidate("fuzzy_word", seg.start, seg._end, cand.text, "")
                end
                yield(fuzz_cand)
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

        if #other_cands >= 200 then
            break
        end
    end

    if #idiom_cands > 0 then
        for _, cand in ipairs(idiom_cands) do
            yield(cand)
        end
    end

    for _, cand in ipairs(other_cands) do
        yield(cand)
    end
end

return {
    processor = {
        init = P.init,
        func = P.func,
        fini = P.fini,
    },
    translator = {
        init = T.init,
        func = T.func,
        fini = T.fini,
    },
    filter = {
        func = F.func,
    },
}
