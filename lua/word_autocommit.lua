require("tools/string")
require("tools/metatable")

local rime_api_helper = require("tools/rime_api_helper")

local P = {}
local T = {}
local F = {}
local word_auto_commit = {}
local char_shape_code_tbl = {}

function word_auto_commit.init(env)
    local config = env.engine.schema.config
    local schema_id = config:get_string("schema/schema_id")
    local schema = Schema("flypy_xhfast") -- schema_id
    local rvdict_path = "radical_reverse_lookup/dictionary"
    local phrase_dict = config:get_string("flypy_phrase/dictionary")
    local reverse_dict = config:get_string(rvdict_path)
    env.reversedb = ReverseLookup(schema_id)
    env.reversedb_phrase = ReverseLookup(phrase_dict)
    env.radical_reversedb = ReverseLookup(reverse_dict)
    env.char_mode_suffix = config:get_string("key_binder/char_mode") or "|"
    env.autocommit_on = config:get_bool("flypy_phrase/auto_commit") or false
    env.mem = Memory(env.engine, schema, "translator")

end

function word_auto_commit.fini(env)
    if env.mem then
        env.mem:disconnect()
        env.mem = nil
    end
    env.commit_notifier:disconnect()
end

function P.func(key, env)
    local engine = env.engine
    local key_value = key:repr()
    local schema = engine.schema
    local context = engine.context
    local input_code = context.input
    local page_size = schema.page_size
    local caret_pos = context.caret_pos

    local composition = context.composition
    if composition:empty() then return 2 end
    local segment = composition:back()

    -- 四码二字词时, 按下 '/'  生成辅助码提示注解
    if (key:repr() == "slash") and (caret_pos == 4) and (input_code:match("^%l+")) then
        char_shape_code_tbl = {}
        for i = 1, 50, 1 do
            local word_cand = segment:get_candidate_at(i)
            if not word_cand then return 2 end
            local word_cand_text = word_cand.text
            if utf8.len(word_cand_text) ~= 2 then goto skip_cand end
            local cand_tail_text = string.utf8_sub(word_cand_text, 2)
            char_shape_code_tbl[word_cand_text] = env.reversedb:lookup(cand_tail_text)
            ::skip_cand::
        end
    end

    -- 按下 '/' 后, 数字键或符号键选单字时, 自动上屏
    local idx = segment.selected_index
    local seleted_cand_index = rime_api_helper.get_selected_candidate_index(key_value, idx, page_size)
    if (seleted_cand_index >= 0) and input_code:match("^%l+/$") and (caret_pos >= 3) then
        context:select(seleted_cand_index)
        local _cand_text = context:get_commit_text():utf8_sub(1, -2)
        local cand_txt = rime_api_helper.insert_space_to_candText(env, _cand_text)
        rime_api_helper.set_commited_cand_is_chinese(env)
        engine:commit_text(cand_txt)
        context:clear()
        return 1
    end

    if key:repr() == "Escape" then char_shape_code_tbl = {} end
    return 2 -- kNoop
end

function T.func(input, seg, env)
    local context = env.engine.context
    local caret_pos = context.caret_pos
    local composition = context.composition
    if composition:empty() then return end

    -- 四码时, 按下'|', 单字优先
    if input:match("%l%l%l%l?%" .. env.char_mode_suffix .. "$") and (caret_pos > 4) then
        local entry_matched_tbl = {}
        local yin_code = input:sub(1, 2)
        local ok = env.mem:dict_lookup(yin_code, true, 50) -- expand_search
        if not ok then return end
        for dictentry in env.mem:iter_dict() do
            local entry_text = dictentry.text

            if utf8.len(entry_text) == 1 then
                local reverse_char_code = env.reversedb:lookup(entry_text):gsub("%[", "")
                local pattern = "%f[%a](" .. input:gsub("%" .. env.char_mode_suffix, "") .. "%a*)"
                if reverse_char_code:match(pattern) then
                    table.insert(entry_matched_tbl, dictentry)
                end
            end
        end

        for _, de in ipairs(entry_matched_tbl) do
            local ph = Phrase(env.mem, "single_char", seg.start, seg._end, de)
            yield(ph:toCandidate())
        end
    end

    if table.len(char_shape_code_tbl) < 1 then return end

    -- 四码二字词, 通过形码过滤候选项并 给词条加权重后 yield
    if input:match("^%l%l%l%l/%l?%l?$") and (caret_pos >= 5) then
        local filtered_cand_text = ""
        local filtered_cand_count = 0

        for key, val in pairs(char_shape_code_tbl) do
            local tail_char_shape_code = string.sub(val, 4, 5)
            local input_shape_code = string.sub(input, 6)
            local remain_shape_code = tail_char_shape_code:gsub(input_shape_code, "", 1)
            local comment = (remain_shape_code:len() > 0) and string.format("~%s", remain_shape_code) or " "
            if tail_char_shape_code:match(input:sub(6)) then
                local cand = Candidate("wac", seg.start, seg._end, key, comment)
                filtered_cand_count = filtered_cand_count + 1
                filtered_cand_text = key
                cand.quality = 999
                yield(cand)
            elseif input:match("^%l%l%l%l/$") then
                local cand = Candidate("wac", seg.start, seg._end, key, comment)
                yield(cand)
            end
        end
        if (filtered_cand_count == 1) and (utf8.len(filtered_cand_text) == 2) then
            local cand_text = rime_api_helper.insert_space_to_candText(env, filtered_cand_text)
            rime_api_helper.set_commited_cand_is_chinese(env)
            env.engine:commit_text(cand_text)
            char_shape_code_tbl = {}
            context:clear()
            return
        end
    end
end

function F.func(input, env)
    local normal_cands = {}
    local symbol_cands = {}
    local single_char_cands = {}
    local fchars_word_cands = {}
    local context = env.engine.context
    local preedit_code = context.input
    local caret_pos = context.caret_pos

    for cand in input:iter() do
        -- 符号自动上屏(;[a-z])
        if preedit_code:match("^;%l+$") and (not symbol_cands[cand]) then
            table.insert(symbol_cands, cand)
        end

        -- 单字全码唯一自动上屏(xy/ab?)
        if
            (not single_char_cands[cand])
            and preedit_code:match("^%l%l/%l%l?$")
        then
            table.insert(single_char_cands, cand)
        end

        -- 四字短语自动上屏
        if (#preedit_code == 8)
            and preedit_code:match("^%l+$")
            and (not fchars_word_cands[cand.text])
        then
            fchars_word_cands[cand.text] = cand
        end

        if #normal_cands >= 120 then break end
        table.insert(normal_cands, cand)
    end

    -- 符号自动上屏(;[a-z]+)
    if preedit_code:match("^;%l+$") and (#symbol_cands == 1) then
        env.engine:commit_text(symbol_cands[1].text)
        context:clear()
        return 1 -- kAccepted
    end

    -- 单字全码唯一自动上屏(xy/ab?)
    if (caret_pos >= 4) and preedit_code:match("^%l%l/%l%l?$") then
        if #single_char_cands == 1 then
            local cand_txt = rime_api_helper.insert_space_to_candText(env, single_char_cands[1].text)
            rime_api_helper.set_commited_cand_is_chinese(env)
            env.engine:commit_text(cand_txt)
            context:clear()
            return 1 -- kAccepted
        end

        for _, cand in ipairs(single_char_cands) do
            local input_shape_code = string.sub(preedit_code, 4):gsub("/", "")
            local current_cand_shape_code = cand.comment:match("%l") and cand.comment:sub(2):gsub("%[", "")
            local remain_shape_code, _ = string.gsub(current_cand_shape_code, input_shape_code, "", 1)
            local comment = (string.len(remain_shape_code) > 0) and string.format("~%s", remain_shape_code) or " "
            ---@diagnostic disable-next-line: missing-parameter
            yield(ShadowCandidate(cand, cand.type, cand.text, comment))
        end
    end

    -- 四字短语自动上屏
    if (#preedit_code == 8) and (table.len(fchars_word_cands) > 0) and preedit_code:match("^%l+")
        and env.autocommit_on
    then
        local done, commit_text = 0, ""
        for _, cand in pairs(fchars_word_cands) do
            local reverse_code = env.reversedb_phrase:lookup(cand.text)

            local match_res = reverse_code:match("^" .. preedit_code .. "$")
            if reverse_code and match_res then
                done = done + 1
                commit_text = cand.text
            end

        end
        if (done == 1) and (caret_pos == 8) and (#commit_text >= 4) then
            local cand_txt = rime_api_helper.insert_space_to_candText(env, commit_text)
            rime_api_helper.set_commited_cand_is_chinese(env)
            env.engine:commit_text(cand_txt)
            context:clear()
            return 1 -- kAccepted
        end
    end

    for _, cand in ipairs(normal_cands) do
        yield(cand)
    end
end

return {
    processor = { init = word_auto_commit.init, func = P.func, fini = word_auto_commit.fini },
    translator = { init = word_auto_commit.init, func = T.func, fini = word_auto_commit.fini },
    filter = { init = word_auto_commit.init, func = F.func, fini = word_auto_commit.fini },
}
