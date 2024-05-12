local reload_env = require("tools/env_api")

local flypy_switcher = {}

function flypy_switcher.init(env)
    reload_env(env)
    local config = env.engine.schema.config
    env.comment_hints = config:get_int("translator/spelling_hints") or 1
    env.cn_comment_overwrited = config:get_bool("radical_reverse_lookup/overwrite_comment") or false
    env.en_comment_overwrited = config:get_bool("ecdict_reverse_lookup/overwrite_comment") or false
    env.switch_comment_key = config:get_string("key_binder/switch_comment") or "Control+n"
    env.commit_comment_key = config:get_string("key_binder/commit_comment") or "Control+p"
    env.switch_english_key = config:get_string("key_binder/switch_english") or "Control+g"
    -- env.switch_easy_en_key = config:get_string("key_binder/switch_easy_en") or "Control+q"
    env.easy_en_prefix = config:get_string("recognizer/patterns/easy_en"):match("%^([a-z/]+).*") or "/oe"
end

function flypy_switcher.func(key, env)
    local engine = env.engine
    local schema = engine.schema
    local context = engine.context
    local config = engine.schema.config
    local preedit_code = context:get_script_text():gsub(" ", "")

    if context:has_menu() and (key:repr() == env.switch_comment_key) then
        if (preedit_code:match("^" .. env.easy_en_prefix) and env.en_comment_overwrited) then
            config:set_bool("ecdict_reverse_lookup/overwrite_comment", false) -- 重写英文注释为空
        elseif (preedit_code:match("^" .. env.easy_en_prefix) and (not env.en_comment_overwrited)) then
            config:set_bool("ecdict_reverse_lookup/overwrite_comment", true)  -- 重写英文注释为中文
        elseif (not env.cn_comment_overwrited) and (env.comment_hints > 0) then
            config:set_bool("radical_reverse_lookup/overwrite_comment", true) -- 重写注释为注音
        elseif (env.cn_comment_overwrited) and (env.comment_hints > 0) then
            config:set_int("translator/spelling_hints", 0)
            config:set_bool("radical_reverse_lookup/overwrite_comment", false) -- 重写注释为空
            env:Config_set('radical_reverse_lookup/comment_format/@last', "xform/^.+$//")
        else
            config:set_int("translator/spelling_hints", 1) -- 重写注释为小鹤形码
            config:set_bool("radical_reverse_lookup/overwrite_comment", false)
            env:Config_set('radical_reverse_lookup/comment_format/@last', "xform/^/~/")
        end
        env.engine:apply_schema(Schema(schema.schema_id))
        context:push_input(preedit_code)
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1                                    -- kAccept
    end

    if context:has_menu() and (key:repr() == env.commit_comment_key) then
        local cand = context:get_selected_candidate()
        local cand_comment = cand.comment:gsub("%p", "")
        engine:commit_text(cand_comment)
        context:clear()
        return 1
    end

    if context:has_menu() and (key:repr() == env.switch_english_key) and (schema.schema_id ~= "easy_en") then
        --[[
        context:clear()
        context:push_input(env.easy_en_prefix .. preedit_code)
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1                                    -- kAccept
    elseif context:has_menu() and (key:repr() == env.switch_easy_en_key) then
    --]]
        context:clear()
        env.engine:apply_schema(Schema("easy_en"))
        context:push_input(preedit_code)
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1                                    -- kAccept
    end

    return 2 -- kNoop, 不做任何操作, 交给下个组件处理
end

return {
    processor = { init = flypy_switcher.init, func = flypy_switcher.func },
}
