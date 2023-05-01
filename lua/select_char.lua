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
        "space",
        "semicolon",
        "apostrophe",
        ["space"] = 0,
        ["semicolon"] = 1,
        ["apostrophe"] = 2
    }

    if (preedit_code_length > 1 and key:repr() == "bracketleft") then
        _G['Gcommit_code'] = reversedb:lookup(commit_text)
        -- puts(INFO, "-----=====", _G['Gcommit_code'])
    end

    if table.find(cand_kyes, key:repr()) and string.find(input_code, "^[%w]+%[$") then
        context:select(cand_kyes[key:repr()])
        local cand_text = context:get_commit_text()
        engine:commit_text(utf8_sub(cand_text, 1, -2))
        context:clear()

        return 1 -- kAccepted
    end

    if table.find(cand_kyes, key:repr()) and string.find(input_code, "^[%w]+%[%l+") then
        local pos = context.caret_pos
        if pos == 3 then
            local char_code = string.sub(Gcommit_code, 4, 4)
            -- puts(INFO, "||||||||||", _G['Gcommit_code'], char_code)
            context:push_input(char_code)
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
