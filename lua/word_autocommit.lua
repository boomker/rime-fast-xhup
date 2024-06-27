require("tools/string")
require("tools/metatable")
local rime_api_helper = require("tools/rime_api_helper")

local word_shape_char_tbl = {}
local word_auto_commit = {}
local P = {}
local T = {}
local F = {}

local function append_space_to_cand(env, cand_text)
    local context = env.engine.context
    local ccand_text = cand_text
    if (context:get_property('prev_cand_is_preedit') == "1") or
        (context:get_property('prev_cand_is_word') == "1") then
        ccand_text = " " .. cand_text
    end
    return ccand_text
end

local function reset_cand_property(env)
    local context = env.engine.context
    context:set_property("prev_cand_is_null", "0")
    context:set_property("prev_cand_is_word", "0")
    context:set_property("prev_cand_is_hanzi", "0")
    context:set_property("prev_cand_is_preedit", "0")
    context:set_property("prev_commit_is_comma", "0")
end

function word_auto_commit.init(env)
    local config          = env.engine.schema.config
    local schema_id       = config:get_string("schema/schema_id")
    local phrase_dict     = config:get_string("flypy_phrase/dictionary")
    local reverse_dict    = config:get_string("radical_reverse_lookup/dictionary")
    env.autocommit_on     = config:get_bool("flypy_phrase/auto_commit")
    env.spelling_hints    = config:get_int("translator/spelling_hints")
    env.overwrite_comment = config:get_bool("radical_reverse_lookup/overwrite_comment")
    env.reversedb         = ReverseLookup(schema_id)
    env.reversedb_phrase  = ReverseLookup(phrase_dict)
    env.radical_reversedb = ReverseLookup(reverse_dict)
end

function P.func(key, env)
    local engine = env.engine
    local key_value = key:repr()
    local schema = engine.schema
    local context = engine.context
    local input_code = context.input
    local page_size = schema.page_size
    local caret_pos = context.caret_pos
    local preedit_code_length = #input_code

    local composition = context.composition
    if (composition:empty()) then return 2 end
    local segment = composition:back()

    if (input_code:match("^%l%l%l%l$")) and (key:repr() == "slash") and (caret_pos == 4) then
        local char_code_matched_tbl = {}
        for i = 1, 100, 1 do
            local char_cand = segment:get_candidate_at(i)
            if not char_cand then goto check_matched_tbl end
            local char_cand_text = char_cand.text
            if (utf8.len(char_cand_text) ~= 1) then goto skip_char_cand end
            local reverse_char_code = env.reversedb:lookup(char_cand_text):gsub("%[", "")
            local char_code_tbl = string.split(reverse_char_code, " ")
            if table.find_index(char_code_tbl, input_code) then
                table.insert(char_code_matched_tbl, char_cand_text)
            end
            ::skip_char_cand::
        end
        ::check_matched_tbl::
        if #char_code_matched_tbl == 1 then
            engine:commit_text(char_code_matched_tbl[1])
            context:clear()
            return 1
        end
    end

    -- 四码二字词时, 按下 '['  生成辅助码提示注解
    if ((preedit_code_length == 4) and (key:repr() == "bracketleft")
            and (caret_pos == 4) and (#word_shape_char_tbl < 1))
    then
        for i = 1, 50, 1 do
            local word_cand = segment:get_candidate_at(i)
            if not word_cand then return 2 end
            local word_cand_text = word_cand.text
            if (utf8.len(word_cand_text) ~= 2) then goto skip_cand end
            local cand_tail_text = string.utf8_sub(word_cand_text, 2)
            table.insert(word_shape_char_tbl, {
                word_cand_text, env.reversedb:lookup(cand_tail_text)
            })
            ::skip_cand::
        end
    end

    -- 按下 '[' 后, 数字键或符号键选单字时, 自动上屏
    local idx = segment.selected_index
    local seleted_cand_index = rime_api_helper.get_selected_candidate_index(key_value, idx, page_size)
    if (seleted_cand_index > 0) and input_code:match("^%l+%[[%l%[]*") then
        if (table.find({ 3, 5 }, caret_pos)) and (input_code:match("%[$")) then
            context:select(seleted_cand_index)
            local cand_text = context:get_commit_text():utf8_sub(1, -2)
            engine:commit_text(cand_text)
            context:clear()
            return 1
            -- else
            --     context:confirm_previous_selection()
        end
        word_shape_char_tbl = {}

        return 2 -- kNoop
    end

    if key:repr() == "Escape" then
        word_shape_char_tbl = {}
    end
    return 2 -- kNoop
end

function T.func(input, seg, env)
    local context = env.engine.context
    local caret_pos = context.caret_pos
    local composition = context.composition
    if (composition:empty()) then return end

    if table.len(word_shape_char_tbl) < 1 then return end
    -- 四码二字词, 按下'['时, 生成辅助码提示
    if string.match(input, '^%l+%[$') and (#input == 5) and (caret_pos == 5) then
        for _, val in ipairs(word_shape_char_tbl) do
            local tail_char_hxm = string.sub(val[2], 4, 5)
            local comment = string.format("~%s", tail_char_hxm)
            local cand = Candidate("custom", seg.start, seg._end, val[1], comment)
            yield(cand)
        end
    end

    --  四码二字词, 通过形码过滤候选项并 给词条加权重后 yield
    if string.match(input, '^%l+%[%l+$') and (#input > 5) and (caret_pos > 5) then
        for _, val in ipairs(word_shape_char_tbl) do
            local tail_char_hxm = string.sub(val[2], 4, 5)
            local comment = string.format("~%s", tail_char_hxm)
            if string.match(tail_char_hxm, input:sub(6)) then
                local cand = Candidate("custom", seg.start, seg._end, val[1], comment)
                cand.quality = 999
                yield(cand)
            end
        end
    end
end

function F.func(input, env)
    local cands = {}
    local symbol_cands = {}
    local single_char_cands = {}
    local tchars_word_cands = {}
    local fchars_word_cands = {}
    local context = env.engine.context
    local preedit_code = context.input
    local caret_pos = context.caret_pos
    local spelling_hints = env.spelling_hints
    local overwrite_comment = env.overwrite_comment

    for cand in input:iter() do
        if preedit_code:match("^;%l+$") and (not symbol_cands[cand.text]) then
            symbol_cands[cand.text] = cand
            table.insert(symbol_cands, cand)
        end

        if (caret_pos >= 4) and (table.find_index({ 4, 5 }, #preedit_code))
            and string.find(preedit_code, "^%l+%[%l?%l?$")
            and (not single_char_cands[cand.text])
        then
            single_char_cands[cand.text] = cand
            table.insert(single_char_cands, cand)
        end

        if (utf8.len(cand.text) == 2) and (table.find({ 6, 7 }, #preedit_code))
            and string.find(preedit_code, "^%l+%[%l+$")
            and (string.sub(preedit_code, 5, 5) == "[")
            and (not tchars_word_cands[cand.text])
        then
            tchars_word_cands[cand.text] = cand
            table.insert(tchars_word_cands, cand)
        end

        if (#preedit_code == 8) and preedit_code:match("^%l+$")
            and (not fchars_word_cands[cand.text])
        then
            fchars_word_cands[cand.text] = cand
        end

        if #cands >= 100 then break end
        table.insert(cands, cand)
    end

    -- 符号自动上屏
    if preedit_code:match("^;%l+$") and (#symbol_cands == 1) then
        env.engine:commit_text(symbol_cands[1].text)
        context:clear()
        return 1 -- kAccepted
    end

    if (caret_pos >= 4) and (table.find({ 4, 5 }, #preedit_code))
        and preedit_code:match("^%l+%[%l%l?$")
    then
        for _, cand in ipairs(single_char_cands) do
            local comment = ""
            if spelling_hints > 0 then
                local input_shape_code = string.sub(preedit_code, 4):gsub('%[', '')
                local current_cand_shape_code = cand.comment:match('[%l]') and cand.comment:sub(2):gsub('%[', '')
                local remain_shape_code, _ =
                    string.gsub(current_cand_shape_code, input_shape_code, '', 1)
                comment = (string.len(remain_shape_code) > 0) and
                    string.format('~%s', remain_shape_code) or "~"
            end
            if overwrite_comment then
                comment = env.radical_reversedb:lookup(cand.text) or comment
            end
            yield(ShadowCandidate(cand, cand.type, cand.text, comment))

            if (#single_char_cands == 1) then
                word_shape_char_tbl = {}

                local cand_txt = append_space_to_cand(env, cand.text)
                env.engine:commit_text(cand_txt)
                context:clear()
                reset_cand_property(env)
                return 1 -- kAccepted
            end
        end
    end

    if (caret_pos >= 6) and (table.find({ 6, 7 }, #preedit_code))
        and string.find(preedit_code, "^%l+%[%l+$")
    then
        for _, cand in ipairs(tchars_word_cands) do
            local input_shape_code = string.sub(preedit_code, 6)
            local current_cand_shape_code = cand.comment:match('[%a]') and cand.comment:sub(2):gsub('%[', '')
            local remain_shape_code, _ =
                string.gsub(current_cand_shape_code, input_shape_code, '', 1)
            local comment = (string.len(remain_shape_code) > 0) and
                string.format('~%s', remain_shape_code) or "~"
            ---@diagnostic disable-next-line: missing-parameter
            yield(ShadowCandidate(cand, cand.type, cand.text, comment))
            if (#tchars_word_cands == 1) and (tchars_word_cands[cand.text]) and
                (tonumber(utf8.codepoint(cand.text, 1)) >= 19968) then
                local cand_txt = append_space_to_cand(env, cand.text)
                env.engine:commit_text(cand_txt)
                context:clear()
                reset_cand_property(env)
                word_shape_char_tbl = {}
                return 1 -- kAccepted
            end
        end
    end

    if (#preedit_code == 8) and preedit_code:match("^%l+") and (env.autocommit_on) then
        local i, done, when_done, commit_text = 1, 0, 0, ""
        for _, cand in pairs(fchars_word_cands) do
            local reverse_code = env.reversedb_phrase:lookup(cand.text)

            local match_res = string.match(reverse_code, preedit_code)
            if reverse_code and match_res then
                done = done + 1
                when_done = when_done + 1
                if done == 1 then commit_text = cand.text end
            end

            if (i >= 5) and (done == 1) and (caret_pos >= 6) and (when_done == 1) and
                ((#preedit_code / 2 == utf8.len(commit_text)) or
                    (#preedit_code / 3 == utf8.len(commit_text)))
            then
                local cand_txt = append_space_to_cand(env, commit_text)
                env.engine:commit_text(cand_txt)
                context:clear()
                reset_cand_property(env)
                return 1 -- kAccepted
            end
            i = i + 1
        end
    end

    for _, cand in ipairs(cands) do yield(cand) end
end

return {
    processor = { init = word_auto_commit.init, func = P.func },
    translator = { func = T.func },
    filter = { init = word_auto_commit.init, func = F.func },
}
