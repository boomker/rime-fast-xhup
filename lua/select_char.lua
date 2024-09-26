-- 以词定字
-- https://github.com/BlindingDark/rime-lua-select-character
-- 删除了默认按键，需要在 key_binder（default.custom.yaml）下设置
-- http://lua-users.org/lists/lua-l/2014-04/msg00590.html

local rime_api_helper = require("tools/rime_api_helper")
local P = {}

local function first_character(s)
    return string.utf8_sub(s, 1, 1)
end

local function last_character(s)
    return string.utf8_sub(s, -1, -1)
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
	local composition = env.engine.context.composition
	if composition:empty() then return end
	local segment = composition:back()

    if (key:repr() == env.first_key) and (input_code ~= "") and (not segment.prompt:match('计算器')) then
        local _cand_text, _commit_txt = context:get_selected_candidate().text, nil
        if _cand_text then _commit_txt = first_character(_cand_text) end
        local cand_txt = rime_api_helper.insert_space_to_candText(env, _commit_txt)
        engine:commit_text(cand_txt)
        context:clear()

        rime_api_helper.set_commited_cand_is_chinese(env)
        return 1 -- kAccepted
    end

    if (key:repr() == env.last_key) and (input_code ~= "") and (not segment.prompt:match('计算器')) then
        local _cand_text, _commit_txt = context:get_selected_candidate().text, nil
        if _cand_text then _commit_txt = last_character(_cand_text) end
        local cand_txt = rime_api_helper.insert_space_to_candText(env, _commit_txt)
        engine:commit_text(cand_txt)
        context:clear()

        rime_api_helper.set_commited_cand_is_chinese(env)
        return 1 -- kAccepted
    end

    return 2 -- kNoop
end

return P
