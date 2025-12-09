-- local logEnable, logger = pcall(require, "lib/logger")
-- if logEnable then
--     logger.writeLog('\n')
--     logger.writeLog('--- start ---')
--     logger.writeLog('log from fuzzy-word_expand.lua\n')
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
    local flyhe_fast = Schema("flyhe_fast") -- schema_id
    env.expand_idiom_key = config:get_string("key_binder/simpy_expand_key") or "Control+q"
    env.script_tran = Component.ScriptTranslator(env.engine, flyhe_fast, "translator", "script_translator")
    env.idiom_phrase_tran = Component.Translator(env.engine, schema, "", "table_translator@idiom_phrase")
    env.commit_idiom_notify = context.commit_notifier:connect(function(ctx)
        ctx:set_property("idiom_phrase_first", "0")
    end)
end

function M.fini(env)
    if env.commit_idiom_notify then
        env.commit_idiom_notify:disconnect()
        env.commit_idiom_notify = nil
    end
    if env.script_tran then
        env.script_tran:disconnect()
        env.script_tran = nil
    end
end

function P.func(key, env)
    local engine = env.engine
    local context = engine.context
    -- local caret_pos = context.caret_pos
    local composition = context.composition
    if composition:empty() then return 2 end
    local preedit_code = context:get_script_text():gsub(" ", "")

    if
        context:has_menu()
        and (#preedit_code >= 4)
        and (preedit_code:match("^[%a' ]+$"))
        and (key:repr() == env.expand_idiom_key)
    then
        local switch_val = (context:get_property("idiom_phrase_first") == "1") and "0" or "1"
        context:set_property("idiom_phrase_first", tostring(switch_val))
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1                                    -- kAccept
    end

    return 2 -- kNoop
end

function T.func(input, seg, env)
    local context = env.engine.context
    local composition = context.composition
    if composition:empty() then return end

    -- local segment = composition:back() (not segment.menu) and
    if (input:len() >= 2) and (input:len() <= 4) then
        local word_cands = env.script_tran:query(input, seg) or nil
        if not word_cands then return end
        for dictentry in word_cands:iter() do
            local entry_text = dictentry.text
            -- logger.writeLog("text: " .. entry_text)
            if utf8.len(entry_text) == #input then
                local cand = Candidate("fuzzy_word", seg.start, seg._end, entry_text, "~fw")
                yield(cand)
            end
        end
    end

    -- 四码时, 按下`Control+q`, 简拼成语优先
    if (input:match("^%l%l%l%l") and (context:get_property("idiom_phrase_first") == "1")) then
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
    -- local fuzzy_cands = {}

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
