-- local puts = require("tools/debugtool")
require("tools/string")

local reversedb_fzm = ReverseDb("build/flypy_phrase.reverse.bin")
local tword_tail_char_shape_tbl = {}
local Gcommit_codes = {}

local function append_space_to_cand(env, cand_text)
    local context = env.engine.context
    local ccand_text = cand_text
    if (context:get_property('prev_cand_is_preedit') == "1") or
        (context:get_property('prev_cand_is_aword') == "1") then
        ccand_text = " " .. cand_text
    end
    return ccand_text
end

local function reset_cand_property(env)
    local context = env.engine.context
    context:set_property('prev_cand_is_null', "0")
    context:set_property('prev_cand_is_aword', "0")
    context:set_property('prev_cand_is_hanzi', "0")
    context:set_property('prev_cand_is_preedit', "0")
end

local function twac_processor(key, env)
    local engine = env.engine
    local config = engine.schema.config
    local context = engine.context
    local commit_text = context:get_commit_text()
    local pos = context.caret_pos
    local input_code = context.input
    local preedit_code_length = #input_code

    local schema_id = config:get_string("schema/schema_id")
    local reversedb = ReverseLookup(schema_id)
    local cand_kyes = {
        ["space"] = 0,
        ["semicolon"] = 1,
        ["apostrophe"] = 2,
        ["1"] = 0,
        ["2"] = 1,
        ["3"] = 2,
        ["4"] = 3,
        ["5"] = 4,
        ["6"] = 5,
        ["7"] = 6,
        ["8"] = 7,
        ["9"] = 8,
        ["10"] = 9
    }

    -- '[' 造字时, 选单字 存单字编码, 后面用于形码自动填充
    if (preedit_code_length > 1) and (pos ~= 4) and
        (key:repr() == "bracketleft") then
        if utf8.len(commit_text) > 1 then return 2 end
        local composition = context.composition
        if (not composition:empty()) then
            local segment = composition:back()

            for i = 0, 50, 1 do
                local single_cand = segment:get_candidate_at(i)
                if not single_cand then return 2 end
                local cand_text = single_cand.text
                if (utf8.len(cand_text) ~= 1) then
                    goto skip_cand1
                end
                local commit_code_num = string.format("commit_code_%s", i)
                Gcommit_codes[commit_code_num] = reversedb:lookup(cand_text)
                ::skip_cand1::
            end
        end
    end

    -- 四码二字词时, 按下 '['  生成辅助码提示注解
    if ((preedit_code_length == 4) and (key:repr() == "bracketleft") and
        (pos == 4) and (#tword_tail_char_shape_tbl < 1)) then
        local composition = context.composition
        if (not composition:empty()) then
            local segment = composition:back()
            for i = 1, 50, 1 do
                local tword_cand = segment:get_candidate_at(i)
                if not tword_cand then return 2 end
                local tword_cand_text = tword_cand.text
                if (utf8.len(tword_cand_text) ~= 2) then
                    goto skip_cand
                end
                local cand_tail_text = string.utf8_sub(tword_cand_text, 2)
                table.insert(tword_tail_char_shape_tbl, {
                    tword_cand_text, reversedb:lookup(cand_tail_text)
                })
                ::skip_cand::
            end
        end
    end

    --  按下 '[' 后, 数字键或符号键快捷选词条
    if (cand_kyes[key:repr()]) and string.match(input_code, "^%l+[%l%[]*%[$") then
        tword_tail_char_shape_tbl = {}
        Gcommit_codes = {}
        context:select(cand_kyes[key:repr()])
        local cand_text = context:get_commit_text()
        engine:commit_text(string.utf8_sub(cand_text, 1, -2))
        context:clear()

        return 1 -- kAccepted
    end

    -- '[' 造字时, 数字键或符号键选单字时, 形码自动填充
    if (cand_kyes[key:repr()]) and string.find(input_code, "^%l+%[[%l%[]*") then
        if not Gcommit_codes['commit_code_0'] then
            tword_tail_char_shape_tbl = {}
            return 2
        end -- 键值对table ,不能使用 `#` 获取长度
        if (pos == 3) or (pos == 7) then
            local selected_cand = string.format("commit_code_%s",
                                                cand_kyes[key:repr()])
            local char_code = string.sub(Gcommit_codes[selected_cand], 4, 5)
            context:push_input(char_code)
            context:confirm_current_selection()
            Gcommit_codes = {}
            return 1
        else
            context:confirm_previous_selection()
        end
        Gcommit_codes = {}
        tword_tail_char_shape_tbl = {}

        return 2 -- kNoop
    end

    if key:repr() == "Escape" then
        tword_tail_char_shape_tbl = {}
        Gcommit_codes = {}
    end
    return 2 -- kNoop
end

local function twac_translator(input, seg, env)
    local context = env.engine.context
    local pos = context.caret_pos
    if table.len(tword_tail_char_shape_tbl) < 1 then return end
    -- 四码二字词, 按下'['时, 生成辅助码提示
    if string.match(input, '^%l+%[$') and (#input == 5) and (pos == 5) then
        for _, val in ipairs(tword_tail_char_shape_tbl) do
            local tail_char_hxm = string.sub(val[2], 4, 5)
            local comment = string.format("~%s", tail_char_hxm)
            local cand = Candidate("custom", seg.start, seg._end, val[1],
                                   comment)
            -- local cand_uniq = UniquifiedCandidate(cand, cand.type, cand.text, comment)
            yield(cand)
        end
    end

    --  四码二字词, 通过形码过滤候选项并 给词条加权重后 yield
    if string.match(input, '^%l+%[%l+$') and (#input > 5) and (pos > 5) then
        for _, val in ipairs(tword_tail_char_shape_tbl) do
            local tail_char_hxm = string.sub(val[2], 4, 5)
            local comment = string.format("~%s", tail_char_hxm)
            if string.match(tail_char_hxm, string.sub(input, 6)) then
                local cand = Candidate("custom", seg.start, seg._end, val[1],
                                       comment)
                cand.quality = 999
                yield(cand)
            end
            -- if #input == 7 then tword_tail_char_shape_tbl = {} end
        end
    end
end

local function twac_filter(input, env)
    local cands = {}
    local single_char_cands = {}
    local tword_phrase_cands = {}
    local tfchars_word_cands = {}
    local context = env.engine.context
    local preedit_code = context.input
    local pos = context.caret_pos
    local done = 0
    for cand in input:iter() do
        if (pos >= 4) and (table.find_index({4, 5}, #preedit_code)) and
            string.find(preedit_code, "^%l+%[%l*$") and
            (not table.find(single_char_cands, cand.text)) then
            single_char_cands[cand.text] = cand
            table.insert(single_char_cands, cand)
        end

        if (pos >= 6) and (table.find({6, 7}, #preedit_code)) and
            string.find(preedit_code, "^[%l]+%[[%l]+$") and
            (utf8.len(cand.text) == 2) and
            (string.sub(preedit_code, 5, 5) == "[") and
            (tonumber(utf8.codepoint(cand.text, 1)) >= 19968) and
            (not (table.find(tword_phrase_cands, cand.text) or
                (cand.quality == 0))) then
            tword_phrase_cands[cand.text] = cand
            table.insert(tword_phrase_cands, cand)
        end

        if table.find({6, 8}, #preedit_code) and
            string.find(preedit_code, "^[%l]+$") and
            (table.len(tfchars_word_cands) < 6) and
            (not table.find(tfchars_word_cands, cand.text)) then
            tfchars_word_cands[cand.text] = cand
        end

        if #cands > 50 then break end
        table.insert(cands, cand)
    end

    if (pos >= 4) and (table.find_index({4, 5}, #preedit_code)) and
        string.find(preedit_code, "^%l+%[%l+$") then
        for _, cand in ipairs(single_char_cands) do
            local input_shape_code = string.sub(preedit_code, 4):gsub('%[', '')
            local current_cand_shape_code =
                string.sub(cand.comment, 2):gsub('%[', '')
            local remain_shape_code, _ =
                string.gsub(current_cand_shape_code, input_shape_code, '', 1)
            local comment = (string.len(remain_shape_code) > 0) and
                                string.format('~%s', remain_shape_code) or "~"
            yield(ShadowCandidate(cand, cand.type, cand.text, comment))
            if (#single_char_cands == 1) and (single_char_cands[cand.text]) then
                tword_tail_char_shape_tbl = {}
                Gcommit_codes = {}

                local cand_txt = append_space_to_cand(env, cand.text)
                env.engine:commit_text(cand_txt)
                context:clear()
                reset_cand_property(env)
                return 1 -- kAccepted
            end
        end
    end

    if (pos >= 6) and (table.find({6, 7}, #preedit_code)) and
        string.find(preedit_code, "^%l+%[%l+$") then
        for _, cand in ipairs(tword_phrase_cands) do
            local input_shape_code = string.sub(preedit_code, 6)
            local current_cand_shape_code = string.sub(cand.comment, 2)
            local remain_shape_code, _ =
                string.gsub(current_cand_shape_code, input_shape_code, '', 1)
            local comment = (string.len(remain_shape_code) > 0) and
                                string.format('~%s', remain_shape_code) or "~"
            yield(ShadowCandidate(cand, cand.type, cand.text, comment))
            if (#tword_phrase_cands == 1) and (tword_phrase_cands[cand.text]) and
                (tonumber(utf8.codepoint(cand.text, 1)) >= 19968) then
                local cand_txt = append_space_to_cand(env, cand.text)
                env.engine:commit_text(cand_txt)
                context:clear()
                reset_cand_property(env)
                tword_tail_char_shape_tbl = {}
                Gcommit_codes = {}
                return 1 -- kAccepted
            end
        end
    end

    if table.find({6, 8}, #preedit_code) and string.find(preedit_code, "^%l+") then
        local i, when_done, commit_text = 1, 0, nil
        for _, cand in pairs(tfchars_word_cands) do
            local reverse_code = reversedb_fzm:lookup(cand.text)

            local match_res = string.match(reverse_code, preedit_code)
            if reverse_code and match_res then
                done = done + 1
                when_done = when_done + 1
                if done == 1 then commit_text = cand.text end
            end

            if (i >= 5) and (done == 1) and (pos >= 6) and (when_done == 1) and
                ((#preedit_code / 2 == utf8.len(commit_text)) or
                    (#preedit_code / 3 == utf8.len(commit_text))) then
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
    filter = twac_filter,
    processor = twac_processor,
    translator = twac_translator
}
