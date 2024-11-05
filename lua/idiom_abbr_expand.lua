local P = {}

function P.init(env)
    local config = env.engine.schema.config
    env.expand_simp_key = config:get_string("key_binder/expand_abbr_py") or "Control+0"
    -- env.custom_Tab_key = Component.Processor(env.engine, "", "key_binder")
end

function P.func(key, env)
    local engine = env.engine
    local context = engine.context
    local caret_pos = context.caret_pos
    local input_code = context.input:gsub("%s", "")
    local preedit_code_length = #input_code
    local composition = context.composition
    if composition:empty() then return 2 end

    if
        context:has_menu()
        and (preedit_code_length >= 3)
        and (input_code:match("^[a-z][a-z']+$"))
        and (key:repr() == env.expand_simp_key)
    then
        context:clear()
        if string.find(input_code, "'") then -- 已经是展开模式，则退出
            context:push_input(input_code:gsub("[^%a]", ""))
        else -- 进入展开超级简拼模式
            local simp_code = input_code:gsub("[^%a]", ""):gsub("(.)", "%1'"):sub(1, -2)
            context:push_input(simp_code)
        end
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
    end

    -- local kstate = env.custom_Tab_key:process_key_event(KeyEvent(key:repr()))
    if (#input_code ~= caret_pos) and (key:repr() == "Tab") then
        engine:process_key(KeyEvent(tostring("Right")))
    elseif (#input_code == caret_pos) and (key:repr() == "Tab") then
        engine:process_key(KeyEvent(tostring("Control+Right")))
        return 1
    end

    return 2 -- kNoop
end

return P
