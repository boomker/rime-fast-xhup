-- 以词定字
-- https://github.com/BlindingDark/rime-lua-select-character
-- 删除了默认按键，需要在 key_binder（default.custom.yaml）下设置
-- http://lua-users.org/lists/lua-l/2014-04/msg00590.html

require("lib/rime_helper")
local P = {}

local function first_character(s)
    if not s then return nil end
    return string.utf8_sub(s, 1, 1)
end

local function last_character(s)
    if not s then return nil end
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
    local composition = context.composition
    if composition:empty() then return 2 end
    local segment = composition:back()
    if (not segment) then return 2 end
    local tags = segment.tags
    for tag, _ in pairs(tags) do
        if (tag ~= "abc") and (tag ~= "paging") then
            return 2
        end
    end

    if (key:repr() == env.first_key) then
        local cand = context:get_selected_candidate()
        local _cand_text, _commit_txt = (cand and cand.text), nil
        _commit_txt = _cand_text and first_character(_cand_text)
        local cand_txt = _commit_txt and insert_space_to_candText(env, _commit_txt)
        if cand_txt then
            engine:commit_text(cand_txt)
        else
            return 2
        end
        context:clear()

        set_committed_cand_is_chinese(env)
        return 1 -- kAccepted
    end

    if (key:repr() == env.last_key) then
        local cand = context:get_selected_candidate()
        local _cand_text, _commit_txt = (cand and cand.text), nil
        _commit_txt = _cand_text and last_character(_cand_text)
        local cand_txt = _commit_txt and insert_space_to_candText(env, _commit_txt)
        if cand_txt then
            engine:commit_text(cand_txt)
        else
            return 2
        end
        context:clear()

        set_committed_cand_is_chinese(env)
        return 1 -- kAccepted
    end

    return 2 -- kNoop
end

return P
