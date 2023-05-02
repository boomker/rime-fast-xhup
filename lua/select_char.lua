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

local function select_char(key, env)
    local engine = env.engine
    local config = engine.schema.config
    local context = engine.context
    local commit_text = context:get_commit_text()
    local input_code = context.input
    local preedit_code_length = #input_code

    local schema_id         = config:get_string("schema/schema_id")
    local reversedb         = ReverseLookup(schema_id)
    -- local first_cand_key = 'space'
    -- local second_cand_key = 'semicolon'
    -- local third_cand_key = 'apostrophe'
    local first_key = config:get_string("key_binder/select_first_character")
    local last_key = config:get_string("key_binder/select_last_character")
    local cand_kyes = {
        ["space"] = 0,
        ["semicolon"] = 1,
        ["apostrophe"] = 2,
        ["1"] = 0,
        ["2"] = 1,
        ["3"] = 2,
        ["4"] = 3
    }

    if (preedit_code_length > 1 and key:repr() == "bracketleft") then
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
        _G['Gcommit_code_0'] = reversedb:lookup(commit_text)
        _G['Gcommit_code_1'] = reversedb:lookup(cand_text1)
        _G['Gcommit_code_2'] = reversedb:lookup(cand_text2)
        _G['Gcommit_code_3'] = reversedb:lookup(cand_text3)
    end

    if (cand_kyes[key:repr()]) and string.find(input_code, "^[%w]+%[$") then
        context:select(cand_kyes[key:repr()])
        local cand_text = context:get_commit_text()
        engine:commit_text(utf8_sub(cand_text, 1, -2))
        context:clear()

        return 1 -- kAccepted
    end

    if (cand_kyes[key:repr()]) and string.find(input_code, "^[%w]+%[%l+") then
        local pos = context.caret_pos
        if pos == 3 then
            local selected_cand = string.format("Gcommit_code_%s", cand_kyes[key:repr()])
            local char_code = string.sub(_G[selected_cand], 4, 4)
            -- puts(INFO, "__________", char_code, selected_cand, _G[selected_cand])
            context:push_input(char_code)
            context:confirm_current_selection()
            return 1
        else
            context:confirm_previous_selection()
        end

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

return { processor = select_char }
