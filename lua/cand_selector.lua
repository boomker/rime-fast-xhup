require("lib/string")
require("lib/metatable")
require("lib/rime_helper")

local P = {}
local T = {}
local F = {}
local M = {}

function M.init(env)
    local config = env.engine.schema.config
    local schema_id = config:get_string("schema/schema_id")
    local schema = Schema(schema_id)
    env.prev_word_pron_code = ""
    env.prev_word_shape_code_tbl = {}
    env.prev_word_pron_translation = nil
    env.reversedb = ReverseLookup(schema_id)
    env.reversedb_flyhe = ReverseLookup("flyhe_fast")
    env.mem = Memory(env.engine, schema, "translator")
    env.tone_filter_code = config:get_string("cand_selector/tone_filter_code")
    env.char_auto_commit = config:get_bool("cand_selector/auto_select_char") or false
    env.word_auto_commit = config:get_bool("cand_selector/auto_select_phrase") or false
    env.char_mode_switch_key = config:get_string("key_binder/char_mode") or "Control+s"
    env.script_tran = Component.Translator(env.engine, schema, "", "script_translator@translator")
end

function M.fini(env)
    if env.mem then
        env.mem:disconnect()
        env.mem = nil
    end
    if env.script_tran then
        env.script_tran:disconnect()
        env.script_tran = nil
    end
end

function P.func(key, env)
    local engine = env.engine
    local key_value = key:repr()
    local context = engine.context
    local composition = context.composition
    if composition:empty() then return 2 end

    local caret_pos = context.caret_pos
    local preedit_text = context:get_preedit().text
    local preedit_code = preedit_text:gsub("[‸ ]", "")
    local char_mode_state = context:get_option("char_mode")

    if key:release() or key:alt() or key:caps() then return 2 end
    -- 触发单字优先
    if
        context:has_menu()
        and (preedit_code:match("^%l%l%l%l?$"))
        and (key:repr() == env.char_mode_switch_key)
    then
        local switch_to_val = not char_mode_state
        context:set_option("char_mode", switch_to_val)
        context:refresh_non_confirmed_composition()
        return 1 -- kAccept
    end

    -- 单字全码唯一自动顶屏(abxy?c?)
    if
        (caret_pos == #preedit_code)
        and preedit_code:match("^%l%l%l%l?%l?$")
        and (context:get_property("matched_char_cand_count") == "1")
    then
        local cand = context:get_selected_candidate()
        local cand_text = cand and cand.text or ""
        if env.char_auto_commit and (utf8.len(cand_text) == 1) then
            if key_value:match("^[a-z]$") then
                engine:commit_text(cand_text)
                context:pop_input(#preedit_code)
                context:push_input(key_value)
                return 1 -- kAccepted
            end
        end
        context:set_property("matched_char_cand_count", "0")
    end
    return 2 -- kNoop
end

function T.func(input, seg, env)
    local context = env.engine.context
    local composition = context.composition
    context:set_property("enable_tone_filter", "0")
    context:set_property("matched_char_cand_count", "0")
    if composition:empty() then return end

    -- 二码时, 按下`/` 后补大写字母过滤出指定声调的候选
    if input:match("^%l%l/[%u]") then
        local entry_matched_tbl = {}
        local yin_code = input:sub(1, 2)
        local stone_code = yin_code:sub(1, 1)
        local filter_code = input:sub(-1, -1)
        local define_tone_filter_code = env.tone_filter_code or "HJKL"
        local tone_code_map = {
            [define_tone_filter_code:sub(1, 1)] = { 257, 333, 275, 299, 363, 470, 252, }, -- "āōēīūǖü"
            [define_tone_filter_code:sub(2, 2)] = { 225, 243, 233, 237, 250, 472, },      -- "áóéíúǘ"
            [define_tone_filter_code:sub(3, 3)] = { 462, 466, 283, 464, 468, 474, },      -- "ǎǒěǐǔǚ"
            [define_tone_filter_code:sub(4, 4)] = { 224, 242, 232, 236, 249, 476, },      -- "àòèìùǜ"
        }
        local zcs_viu_map = {
            ["v"] = "zh",
            ["i"] = "ch",
            ["u"] = "sh",
        }
        local ok = env.mem:dict_lookup(yin_code, true, 300)                               -- expand_search
        if not ok then return end

        local zcs_tone = zcs_viu_map[stone_code]
        for dictentry in env.mem:iter_dict() do
            local char_tone_codepoint_tbl = {}
            local entry_text = dictentry.text

            if (utf8.len(entry_text) == 1) and (not entry_text:match("[a-zA-Z%p]")) then
                local reverse_char_code = env.reversedb_flyhe:lookup(entry_text)
                local yin_code_tbl = reverse_char_code:match(" ") and string.split(reverse_char_code, " ") or { reverse_char_code }
                for _, y_code in ipairs(yin_code_tbl) do
                    if y_code:match("^" .. stone_code) or (zcs_tone and y_code:match("^" .. zcs_tone)) then
                        local tone_code = y_code:gsub("[a-z]+", "")
                        local tone_code_point = (tone_code:len() > 0) and utf8.codepoint(tone_code, 1) or 252
                        table.insert(char_tone_codepoint_tbl, tone_code_point)
                    end
                end
                for _, code in ipairs(char_tone_codepoint_tbl) do
                    if table.find_index(tone_code_map[filter_code], code) then
                        table.insert(entry_matched_tbl, dictentry)
                    end
                end
            end
        end

        if #entry_matched_tbl < 1 then
            local hint_cand = Candidate("unmatched", seg.start, seg._end, "🈳", "")
            yield(hint_cand)
            return
        else
            context:set_property("enable_tone_filter", "1")
        end

        for _, entry in ipairs(entry_matched_tbl) do
            local ph = Phrase(env.mem, "single_char", seg.start, seg._end, entry)
            local cand = ph:toCandidate()
            cand.type = "single_char_" .. cand.type
            yield(cand)
        end
    end

    -- 四码时, 按下`Control+s`, 单字优先
    local char_mode_state = context:get_option("char_mode")
    if input:match("^%l%l%l%l?$") and char_mode_state then
        local entry_matched_tbl = {}
        local yin_code = input:sub(1, 2)
        local ok = env.mem:dict_lookup(yin_code, true, 300) -- expand_search
        if not ok then return end

        for dictentry in env.mem:iter_dict() do
            local entry_text = dictentry.text

            if (utf8.len(entry_text) == 1) and (not entry_text:match("[a-zA-Z%p]")) then
                local reverse_char_code = env.reversedb:lookup(entry_text):gsub("%[", "")
                if reverse_char_code:match(input) then
                    table.insert(entry_matched_tbl, dictentry)
                end
            end
        end

        if table.len(entry_matched_tbl) < 1 then return end

        local prev_cand_text = ""
        local matched_char_cand_count = 0
        for _, entry in ipairs(entry_matched_tbl) do
            local ph = Phrase(env.mem, "single_char", seg.start, seg._end, entry)
            local cand = ph:toCandidate()
            cand.type = "single_char_" .. cand.type
            yield(cand)
            if prev_cand_text ~= cand.text then
                prev_cand_text = cand.text
                matched_char_cand_count = matched_char_cand_count + 1
            end
        end
        context:set_property("matched_char_cand_count", tostring(matched_char_cand_count))
    end

    -- 四码二字词, 通过形码过滤候选项并 给词条加权重后 yield
    if input:match("^%l%l%l%l/%l?%l?$") then
        local filtered_cand_text = ""
        local filtered_cand_count = 0
        local first_cand_confirmed_text = nil

        local word_pron_code = input:sub(1, 4)
        local hit_query_cache = (env.prev_word_pron_code == word_pron_code)
        if not hit_query_cache then
            local word_pron_translation = env.script_tran:query(word_pron_code, seg)
            env.prev_word_pron_code = word_pron_code
            env.prev_word_pron_translation = word_pron_translation
        end

        if (not hit_query_cache) and env.prev_word_pron_translation and input:match("^%l+/$") then
            local idx = 0
            local word_shape_code_tbl = {}
            for cand in env.prev_word_pron_translation:iter() do
                idx = idx + 1
                local cand_text = cand.text
                if (utf8.len(cand_text) == 2) and (not cand_text:match("[%a%d%p]")) then
                    local cand_header_text = string.utf8_sub(cand_text, 1, 1)
                    local cand_tailer_text = string.utf8_sub(cand_text, 2, 2)
                    local cand_header_code = cand_header_text
                        and env.reversedb:lookup(cand_header_text):sub(4, 5)
                    local cand_tailer_code = cand_tailer_text
                        and env.reversedb:lookup(cand_tailer_text):sub(4, 5)
                    local cand_shape_code = cand_tailer_code .. cand_header_code
                    word_shape_code_tbl[idx] = { cand_text, cand_shape_code }
                end
            end
            env.prev_word_shape_code_tbl = word_shape_code_tbl
        end

        if table.len(env.prev_word_shape_code_tbl) < 1 then return end

        for idx, val in ipairs(env.prev_word_shape_code_tbl) do
            local cand_text = val[1]
            local word_shape_code = val[2]
            local input_shape_code = input:sub(6)
            if idx == 1 then
                first_cand_confirmed_text = string.utf8_sub(cand_text, 1, 1)
            end
            local _p1 = input_shape_code and input_shape_code:sub(1, 1) or ""
            local _p2 = (input_shape_code:len() == 2) and (input_shape_code:sub(2)) or ""
            local _remain_code = word_shape_code:gsub(_p1, "", 1):gsub(_p2, "", 1)
            local remain_shape_code = ((_p1 .. _p2):len() == 2) and " ⌛~" or (" ~" .. _remain_code)
            local comment = remain_shape_code:gsub(".$", "")
            local shape_match_pattern = "^" .. _p1 .. ".?" .. _p2
            -- local shape_match_pattern = _p1 .. ".?" .. _p2 .. "?" .. _p1 .. "?" .. _p2
            if input_shape_code:len() < 1 then
                local cand = Candidate("pre_select", seg.start, seg._end, cand_text, comment)
                yield(cand)
            elseif word_shape_code:match(shape_match_pattern) then
                filtered_cand_text = cand_text
                filtered_cand_count = filtered_cand_count + 1
                local cand = Candidate("pre_select", seg.start, seg._end, cand_text, comment)
                cand.quality = 999
                yield(cand)
                if
                    first_cand_confirmed_text
                    and (word_shape_code:sub(1, 2):match("^" .. input_shape_code .. "$"))
                then
                    filtered_cand_text = first_cand_confirmed_text .. string.utf8_sub(cand_text, -1, -1)
                    local scand = Candidate("pre_select", seg.start, seg._end, filtered_cand_text, " ⭐️️")
                    cand.quality = 888
                    yield(scand)
                end
            end
        end
    end
end

function F.func(input, env)
    local normal_cands = {}
    local symbol_cands = {}
    local preselected_cands = {}
    local single_char_cands = {}
    local context = env.engine.context
    local preedit_code = context.input
    local caret_pos = context.caret_pos

    for cand in input:iter() do
        -- 符号自动上屏(;[a-z])
        if preedit_code:match("^;%l+$") and not symbol_cands[cand] then
            table.insert(symbol_cands, cand)
        end

        -- 单字全码唯一自动上屏(xy/ab?)
        if (not single_char_cands[cand]) and preedit_code:match("^%l%l/%l%l?$") then
            table.insert(single_char_cands, cand)
        end

        if cand.type:match("^single_char") then
            table.insert(single_char_cands, cand)
        end

        if cand.type:match("^pre_select") then
            table.insert(preselected_cands, cand)
        end

        if #normal_cands >= 200 then
            break
        end
        table.insert(normal_cands, cand)
    end

    -- 符号自动上屏(;[a-z]+)
    if preedit_code:match("^;%l+$") and (#symbol_cands == 1) then
        env.engine:commit_text(symbol_cands[1].text)
        context:clear()
        return 1 -- kAccepted
    end

    -- 单字全码唯一自动上屏(xy/ab?)
    if (caret_pos == #preedit_code) and preedit_code:match("^%l%l/%l%l?$") then
        if env.char_auto_commit and (#single_char_cands == 1) then
            local cand_obj = single_char_cands[1]
            local cand_text = cand_obj.text
            local cand_text_fm = insert_space_to_candText(env, cand_text)
            set_committed_cand_is_chinese(env)
            env.engine:commit_text(cand_text_fm)
            context:clear()
            return 1 -- kAccepted
        end

        for _, cand in ipairs(single_char_cands) do
            local input_shape_code = preedit_code:sub(4)
            local current_cand_shape_code = cand.comment:match("%l") and cand.comment:sub(2):gsub("%[", "")
            if not current_cand_shape_code then return end

            local remain_shape_code, _ = string.gsub(current_cand_shape_code, input_shape_code, "", 1)
            local comment = (string.len(remain_shape_code) > 0) and string.format("~%s", remain_shape_code)
                or " "
            yield(ShadowCandidate(cand, cand.type, cand.text, comment, false))
        end
    end

    if #preselected_cands > 0 then
        for _, cand in ipairs(preselected_cands) do
            yield(cand)
        end
    elseif #single_char_cands > 0 then
        for _, cand in ipairs(single_char_cands) do
            yield(cand)
        end
    end

    if context:get_property("enable_tone_filter") ~= "1" then
        for _, cand in ipairs(normal_cands) do
            yield(cand)
        end
    end
end

return {
    processor = {
        init = M.init,
        func = P.func,
        fini = M.fini,
    },
    translator = {
        init = M.init,
        func = T.func,
        fini = M.fini,
    },
    filter = {
        init = M.init,
        func = F.func,
        fini = M.fini,
    },
}
