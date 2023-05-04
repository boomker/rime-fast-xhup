-- 以词定字
-- https://github.com/BlindingDark/rime-lua-select-character
-- 删除了默认按键，需要在 key_binder（default.custom.yaml）下设置
-- http://lua-users.org/lists/lua-l/2014-04/msg00590.html

-- local puts = require("tools/debugtool")
local function utf8_sub(s, i, j)
    i = i or 1
    j = j or -1

    if i < 1 or j < 1 then
        local n = utf8.len(s)
        if not n then return nil end
        if i < 0 then i = n + 1 + i end
        if j < 0 then j = n + 1 + j end
        if i < 0 then
            i = 1
        elseif i > n then
            i = n
        end
        if j < 0 then
            j = 1
        elseif j > n then
            j = n
        end
    end

    if j < i then return "" end

    i = utf8.offset(s, i)
    j = utf8.offset(s, j + 1)

    if i and j then
        return s:sub(i, j - 1)
    elseif i then
        return s:sub(i)
    else
        return ""
    end
end

local function first_character(s) return utf8_sub(s, 1, 1) end

local function last_character(s) return utf8_sub(s, -1, -1) end

local tword_tail_char_shape_tbl = {}
local Gcommit_codes = {}

local function select_char(key, env)
    local engine              = env.engine
    local config              = engine.schema.config
    local context             = engine.context
    local commit_text         = context:get_commit_text()
    local input_code          = context.input
    local preedit_code_length = #input_code
    local pos = context.caret_pos

    local schema_id           = config:get_string("schema/schema_id")
    local reversedb           = ReverseLookup(schema_id)
    -- local first_cand_key = 'space'
    -- local second_cand_key = 'semicolon'
    -- local third_cand_key = 'apostrophe'
    local first_key           = config:get_string("key_binder/select_first_character")
    local last_key            = config:get_string("key_binder/select_last_character")
    local cand_kyes           = {
        ["space"] = 0,
        ["semicolon"] = 1,
        ["apostrophe"] = 2,
        ["1"] = 0,
        ["2"] = 1,
        ["3"] = 2,
        ["4"] = 3
    }

    if (preedit_code_length > 1 and pos ~= 4 and key:repr() == "bracketleft") then
        if utf8.len(commit_text) > 1 then return 2 end
        local composition = context.composition
        local cand_text1, cand_text2, cand_text3 = nil, nil, nil
        if (not composition:empty()) then
            local segment = composition:back()
            local cand_1 = segment:get_candidate_at(1)
            local cand_2 = segment:get_candidate_at(2)
            local cand_3 = segment:get_candidate_at(3)
            cand_text1 = cand_1.text
            cand_text2 = cand_2.text
            cand_text3 = cand_3.text
        end
        Gcommit_codes['Gcommit_code_0'] = reversedb:lookup(commit_text)
        Gcommit_codes['Gcommit_code_1'] = reversedb:lookup(cand_text1)
        Gcommit_codes['Gcommit_code_2'] = reversedb:lookup(cand_text2)
        Gcommit_codes['Gcommit_code_3'] = reversedb:lookup(cand_text3)
    end

    if (preedit_code_length == 4 and key:repr() == "bracketleft") then
        local composition = context.composition
        if (not composition:empty()) then
            local segment = composition:back()
            for i = 1, 10, 1 do
                local tword_cand = segment:get_candidate_at(i)
                if not tword_cand then return 2 end
                local tword_cand_text = tword_cand.text
                if utf8.len(tword_cand_text) < 2 then goto skip_cand end
                local cand_tail_text = utf8_sub(tword_cand_text, 2)
                tword_tail_char_shape_tbl[tword_cand_text] = reversedb:lookup(cand_tail_text)
                :: skip_cand ::
            end
        end
    end

    if (cand_kyes[key:repr()]) and string.find(input_code, "^[%w]+%[$") then
        context:select(cand_kyes[key:repr()])
        local cand_text = context:get_commit_text()
        engine:commit_text(utf8_sub(cand_text, 1, -2))
        context:clear()

        return 1 -- kAccepted
    end

    if (cand_kyes[key:repr()]) and string.find(input_code, "^[%w]+%[%l+") then
        if not Gcommit_codes['Gcommit_code_0'] then
            tword_tail_char_shape_tbl = {}
            return 2
        end    -- 键值对table ,不能使用 `#` 获取长度
        if pos == 3 then
            local selected_cand = string.format("Gcommit_code_%s", cand_kyes[key:repr()])
            local char_code = string.sub(Gcommit_codes[selected_cand], 4, 4)
            context:push_input(char_code)
            context:confirm_current_selection()
            Gcommit_codes = {}
            return 1
        else
            context:confirm_previous_selection()
        end
        tword_tail_char_shape_tbl = {}

        return 2 -- kAccepted
    end

    if key:repr() == first_key and commit_text ~= "" then
        engine:commit_text(first_character(commit_text))
        context:clear()

        return 1 -- kAccepted
    end

    if key:repr() == last_key and commit_text ~= "" then
        engine:commit_text(last_character(commit_text))
        context:clear()

        return 1 -- kAccepted
    end

    return 2 -- kNoop
end


---@diagnostic disable-next-line: unused-local
local function translator(input, seg, env)
    if table.len(tword_tail_char_shape_tbl) < 1 then return end
    if string.match(input, '^%l+%[%l+$') and #input > 5 then
        for key, val in pairs(tword_tail_char_shape_tbl) do
            local tail_char_hxm = string.sub(val, 4,5)
            local comment = string.format("~%s", tail_char_hxm)
            if string.match(tail_char_hxm, string.sub(input, 6)) then
                -- puts(INFO, '-------!!!', val, input)
                local cand = Candidate("custom", seg.start, seg._end, key, comment)
                cand.quality = 99
                yield(cand)
            end
            if #input == 7 then
                tword_tail_char_shape_tbl = {}
            end
        end
    end
end

return { processor = select_char, translator = translator }
