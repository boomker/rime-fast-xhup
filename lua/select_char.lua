-- 以词定字
-- https://github.com/BlindingDark/rime-lua-select-character
-- 删除了默认按键，需要在 key_binder（default.custom.yaml）下设置
-- http://lua-users.org/lists/lua-l/2014-04/msg00590.html

local P = {}

local function first_character(s)
    return string.utf8_sub(s, 1, 1)
end

local function last_character(s)
    return string.utf8_sub(s, -1, -1)
end

local function append_space_to_cand(env, cand_text)
    local context = env.engine.context
    local ccand_text = cand_text
    if (context:get_property("prev_cand_is_preedit") == "1")
        or (context:get_property("prev_cand_is_word") == "1")
    then
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

function P.init(env)
    local engine = env.engine
    local config = engine.schema.config
    env.first_key = config:get_string("key_binder/select_first_character")
    env.last_key = config:get_string("key_binder/select_last_character")
end

function P.func(key, env)
    local engine = env.engine
    local context = engine.context
    local input_code = context.input

    if (key:repr() == env.first_key) and (input_code ~= "") and context:has_menu() then
        local _cand_text, _commit_txt = context:get_selected_candidate().text, nil
        if _cand_text then _commit_txt = first_character(_cand_text) end
        local cand_txt = append_space_to_cand(env, _commit_txt)
        engine:commit_text(cand_txt)
        context:clear()

        reset_cand_property(env)
        return 1 -- kAccepted
    end

    if (key:repr() == env.last_key) and (input_code ~= "") and context:has_menu() then
        local _cand_text, _commit_txt = context:get_selected_candidate().text, nil
        if _cand_text then _commit_txt = last_character(_cand_text) end
        local cand_txt = append_space_to_cand(env, _commit_txt)
        engine:commit_text(cand_txt)
        context:clear()

        reset_cand_property(env)
        return 1 -- kAccepted
    end

    return 2 -- kNoop
end

return P
