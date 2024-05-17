local idiom_abbr_expand = {}

function idiom_abbr_expand.init(env)
    local config = env.engine.schema.config
    env.expand_simp_key = config:get_string("key_binder/expand_abbr_py") or "Control+0"
end

function idiom_abbr_expand.func(key, env)
    local engine = env.engine
    local context = engine.context
    local input_code = context.input:gsub("%s", "")
    local preedit_code_length = #input_code

    if context:has_menu() and (preedit_code_length >= 3)
        and (input_code:match("^[a-z][a-z']+$"))
        and (key:repr() == env.expand_simp_key)
    then
        context:clear()
        if string.find(input_code, "'") then -- 已经是展开模式，则退出
            -- 清空编码中的'并发送给上下文供Rime引擎处理
            context:push_input(input_code:gsub("[^%a]", ""))
        else -- 进入展开超级简拼模式
            -- 将新的简拼编码发送给上下文供Rime引擎处理
            local simp_code = input_code:gsub("[^%a]", ""):gsub("(.)", "%1'"):sub(1, -2)
            context:push_input(simp_code)
        end
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
    end
    return 2                                        -- kNoop
end

return {
    processor = { init = idiom_abbr_expand.init, func = idiom_abbr_expand.func },
}
