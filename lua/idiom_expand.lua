-- local logEnable, log = pcall(require, "lib/logger")
-- if logEnable then
--     log.writeLog('\n')
--     log.writeLog('--- start ---')
--     log.writeLog('log from idiom_expan.lua\n')
-- end

local M = {}
local P = {}
local T = {}
local F = {}

function M.init(env)
    local context = env.engine.context
    local config = env.engine.schema.config
    local schema_id = config:get_string("schema/schema_id")
    local schema = Schema(schema_id)
    M.idiom_phrase_first = false
    env.expand_idiom_key = config:get_string("key_binder/simpy_expand_key") or "Control+q"
    env.idiom_phrase_tran = Component.Translator(env.engine, schema, "", "table_translator@idiom_phrase")
    env.commit_idiom_notify = context.commit_notifier:connect(function()
        M.idiom_phrase_first = false
    end)
end

function M.fini(env)
    if env.commit_idiom_notify then
        env.commit_idiom_notify:disconnect()
        env.commit_idiom_notify = nil
    end
end

function P.func(key, env)
    local engine = env.engine
    local context = engine.context
    local caret_pos = context.caret_pos
    local composition = context.composition
    if composition:empty() then return 2 end
    local preedit_code = context:get_script_text():gsub(" ", "")

    if (#preedit_code >= caret_pos) and (key:repr() == "Tab") then
        engine:process_key(KeyEvent(tostring("Control+Right")))
        return 1
    elseif (#preedit_code < caret_pos) and (key:repr() == "Tab") then
        engine:process_key(KeyEvent(tostring("Right")))
        engine:process_key(KeyEvent(tostring("Right")))
        return 1
    end

    if
        context:has_menu()
        and (#preedit_code >= 4)
        and (preedit_code:match("^[%a' ]+$"))
        and (key:repr() == env.expand_idiom_key)
    then
        local switch_val = (M.idiom_phrase_first ~= true) and true or false
        M.idiom_phrase_first = switch_val
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1 -- kAccept
    end

    return 2 -- kNoop
end

function T.func(input, seg, env)
    local context = env.engine.context
    local composition = context.composition
    if composition:empty() then return end

    -- 四码时, 按下`Control+q`, 简拼成语优先
    if (input:match("^%l%l%l%l") and M.idiom_phrase_first) then
        local idiom_phrase_iter = env.idiom_phrase_tran:query(input, seg)
        if not idiom_phrase_iter then return end
        for cand in idiom_phrase_iter:iter() do
            cand.type = "idiom_phrase_" .. cand.type
            yield(cand)
        end
    end
end

---@diagnostic disable-next-line: unused-local
function F.func(input, env)
    local idiom_cands = {}
    local other_cands = {}

    for cand in input:iter() do
        if cand.type:match("^idiom_phrase") then
            table.insert(idiom_cands, cand)
        else
            table.insert(other_cands, cand)
        end

        if #other_cands >= 150 then break end
    end

    if #idiom_cands > 0 then
        for _, cand in ipairs(idiom_cands) do
            yield(cand)
        end
    end

    for _, cand in ipairs(other_cands) do
        yield(cand)
    end
end

return {
    processor = {
        init = M.init,
        func = P.func,
        fini = M.fini
    },
    translator = {
        init = M.init,
        func = T.func,
        fini = M.fini
    },
    filter = {
        init = M.init,
        func = F.func,
        fini = M.fini
    },
}
