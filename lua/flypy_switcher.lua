local Env = require("tools/env_api")

local flypy_switcher = {}

function flypy_switcher.init(env)
    Env(env)
end

function flypy_switcher.func(key, env)
    local engine = env.engine
    local config = engine.schema.config
    local schema = engine.schema
    local context = engine.context
    local preedit_code = context:get_script_text():gsub(" ", "")

    local comment_hints = config:get_int("translator/spelling_hints") or 1
    local comment_overwrited = config:get_bool("radical_reverse_lookup/overwrite_comment") or false
    local switch_comment_key = config:get_string("key_binder/switch_comment") or "Control+n"
    if context:has_menu() and (key:repr() == switch_comment_key) then
        if (not comment_overwrited) and (comment_hints > 0) then
            config:set_bool("radical_reverse_lookup/overwrite_comment", true) -- 重写注释为注音
        elseif (comment_overwrited) and (comment_hints > 0) then
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

    if context:has_menu() and (key:repr() == "Control+p") then
        local cand = context:get_selected_candidate()
        local cand_comment = cand.comment:gsub("%p", "")
        engine:commit_text(cand_comment)
        context:clear()
        return 1
    end
    return 2                                        -- kNoop, 不做任何操作, 交给下个组件处理
end

return {
    processor = { init = flypy_switcher.init, func = flypy_switcher.func },
}
