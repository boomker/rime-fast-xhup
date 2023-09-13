-- 以词定字
-- https://github.com/BlindingDark/rime-lua-select-character
-- 删除了默认按键，需要在 key_binder（default.custom.yaml）下设置
-- http://lua-users.org/lists/lua-l/2014-04/msg00590.html
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

-- local puts = require("tools/debugtool")
local function first_character(s) return utf8_sub(s, 1, 1) end

local function last_character(s) return utf8_sub(s, -1, -1) end

local function append_space_to_cand(env, cand_text)
    local context = env.engine.context
    local ccand_text = cand_text
    if
        (context:get_property('prev_cand_is_preedit') == "1") or
        (context:get_property('prev_cand_is_aword') == "1") then
        ccand_text = " " .. cand_text
    end
    return ccand_text
end

local function reset_cand_property(env)
    local context = env.engine.context
    context:set_property('prev_cand_is_null', "0")
    context:set_property('prev_cand_is_aword', "0")
    context:set_property('prev_cand_is_hanzi', "1")
    context:set_property('prev_cand_is_preedit', "0")
end

local function select_char(key, env)
    local engine = env.engine
    local config = engine.schema.config
    local context = engine.context
    local commit_text = context:get_commit_text()

    local first_key = config:get_string("key_binder/select_first_character")
    local last_key = config:get_string("key_binder/select_last_character")

    if key:repr() == first_key and commit_text ~= "" then
        local cand_text, commit_txt = context:get_selected_candidate().text, nil
        if cand_text then commit_txt = first_character(cand_text) end
        local cand_txt = append_space_to_cand(env, commit_txt)
        engine:commit_text(cand_txt)
        context:clear()

        reset_cand_property(env)
        return 1 -- kAccepted
    end

    if key:repr() == last_key and commit_text ~= "" then
        -- local commit_txt = last_character(commit_text)
        local cand_text, commit_txt = context:get_selected_candidate().text, nil
        if cand_text then commit_txt = last_character(cand_text) end
        local cand_txt = append_space_to_cand(env, commit_txt)
        engine:commit_text(cand_txt)
        context:clear()

        reset_cand_property(env)
        return 1 -- kAccepted
    end

    return 2 -- kNoop
end

return {processor = select_char}
