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
    local flyhe_schema = Schema("flyhe_fast") -- schema_id
    env.reversedb = ReverseLookup(schema_id)
    env.mem = Memory(env.engine, schema, "translator")
    env.enable_fuzz_func = config:get_bool("speller/enable_fuzz_algebra") or false
    env.char_mode_switch_key = config:get_string("key_binder/char_mode") or "Control+s"
    env.expand_idiom_key = config:get_string("key_binder/simpy_expand_key") or "Control+q"
    env.script_tran = Component.ScriptTranslator(env.engine, flyhe_schema, "translator", "script_translator")
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
    if env.mem then
        env.mem:disconnect()
        env.mem = nil
    end
end

function P.func(key, env)
    local engine = env.engine
    local context = engine.context
    local composition = context.composition
    if composition:empty() then return 2 end
    local preedit_text = context:get_preedit().text
    local preedit_code = preedit_text:gsub("[‸ ]", "")
    local char_mode_state = context:get_option("char_mode")
    local phrase_first_state = context:get_property("idiom_phrase_first")

    -- 触发简码成语优先
    if context:has_menu() and (preedit_code:match("^%l%l%l%l+$")) and (key:repr() == env.expand_idiom_key) then
        local switch_val = (phrase_first_state == "1") and "0" or "1"
        context:set_property("idiom_phrase_first", tostring(switch_val))
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1                                    -- kAccept
    end

    -- 触发单字优先
    if context:has_menu() and (preedit_code:match("^%l%l%l%l$")) and (key:repr() == env.char_mode_switch_key) then
        local switch_to_val = (not char_mode_state)
        context:set_option("char_mode", switch_to_val)
        context:refresh_non_confirmed_composition()
        return 1 -- kAccept
    end

    return 2 -- kNoop
end

function T.func(input, seg, env)
    local context = env.engine.context
    local composition = context.composition
    if composition:empty() then return end

    -- -- 简拼候选
    if env.enable_fuzz_func and (input:len() >= 2) and (input:len() <= 7) then
        local word_cands = env.script_tran:query(input, seg) or nil
        if not word_cands then return end
        for dictentry in word_cands:iter() do
            local entry_text = dictentry.text
            if utf8.len(entry_text) == #input then
                local cand = Candidate("fuzzy_word", seg.start, seg._end, entry_text, "")
                yield(cand)
            end
        end
    end

    -- 四码时, 按下`Control+q`, 简拼成语优先
    local phrase_first_state = context:get_property("idiom_phrase_first")
    if (input:match("^%l%l%l%l") and (phrase_first_state == "1")) then
        local idiom_phrase_iter = env.idiom_phrase_tran:query(input, seg)
        if not idiom_phrase_iter then return end
        for cand in idiom_phrase_iter:iter() do
            cand.type = "idiom_phrase_" .. cand.type
            yield(cand)
        end
    end

    -- 四码时, 按下`Control+s`, 单字优先
    local char_mode_state = context:get_option("char_mode")
    if input:match("^%l%l%l%l$") and char_mode_state then
        local entry_matched_tbl = {}
        local yin_code = input:sub(1, 2)
        local ok = env.mem:dict_lookup(yin_code, true, 300) -- expand_search
        if not ok then return end
        for dictentry in env.mem:iter_dict() do
            local entry_text = dictentry.text

            if (utf8.len(entry_text) == 1) and (not entry_text:match("[a-zA-Z]")) then
                local reverse_char_code = env.reversedb:lookup(entry_text):gsub("%[", "")
                if reverse_char_code:match(input) then
                    table.insert(entry_matched_tbl, dictentry)
                end
            end
        end

        if table.len(entry_matched_tbl) < 1 then return end
        for _, de in ipairs(entry_matched_tbl) do
            local ph = Phrase(env.mem, "single_char", seg.start, seg._end, de)
            local cand = ph:toCandidate()
            cand.type = "single_char_" .. cand.type
            cand.quality = 9999
            yield(cand)
        end
    end
end

---@diagnostic disable-next-line: unused-local
function F.func(input, env)
    local idiom_cands = {}
    local schar_cands = {}
    local other_cands = {}

    for cand in input:iter() do
        if cand.type:match("^idiom_phrase") then
            table.insert(idiom_cands, cand)
        elseif cand.type:match("^single_char") then
            table.insert(schar_cands, cand)
        else
            table.insert(other_cands, cand)
        end

        if #other_cands >= 200 then break end
    end

    if (#idiom_cands > 0) or (#schar_cands > 0) then
        for _, cand in ipairs(idiom_cands) do
            yield(cand)
        end
        for _, cand in ipairs(schar_cands) do
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
