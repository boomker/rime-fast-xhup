-- local logEnable, log = pcall(require, "lib/logger")
require("lib/string")
require("lib/metatable")
require("lib/rime_helper")

local T = {}
local F = {}
local M = {}

function M.init(env)
    local config = env.engine.schema.config
    local schema_id = config:get_string("schema/schema_id")
    local schema = Schema(schema_id)
    env.prev_word_pron_code = ""
    env.prev_word_shape_code_tbl = {}
    env.prev_word_pron_translation = nil
    env.reversedb = ReverseLookup(schema_id)
    -- env.mem = Memory(env.engine, schema, "translator")
    env.word_auto_commit = config:get_bool("speller/auto_select_phrase") or false
    env.script_tran = Component.ScriptTranslator(env.engine, schema, "translator", "script_translator")
end

function M.fini(env)
    -- if env.mem then
    --     env.mem:disconnect()
    --     env.mem = nil
    -- end
    if env.script_tran then
        env.script_tran:disconnect()
        env.script_tran = nil
    end
end

function T.func(input, seg, env)
    local context = env.engine.context
    -- local caret_pos = context.caret_pos
    local composition = context.composition
    -- local preedit_text = context:get_preedit().text
    -- local preedit_code = preedit_text:gsub("‸", "")
    if composition:empty() then return end

    -- 四码二字词, 通过形码过滤候选项并 给词条加权重后 yield
    if input:match("^%l%l%l%l/%l?%l?$") then
        local filtered_cand_text = ""
        local filtered_cand_count = 0
        local first_cand_confirmed_text = nil

        local word_pron_code = input:sub(1, 4)
        local hit_query_cache = (env.prev_word_pron_code == word_pron_code)
        if not hit_query_cache then
            local word_pron_translation = env.script_tran:query(word_pron_code, seg)
            env.prev_word_pron_code = word_pron_code
            env.prev_word_pron_translation = word_pron_translation
        end

        if (not hit_query_cache) and env.prev_word_pron_translation and input:match("^%l+/$") then
            local idx = 0
            local word_shape_code_tbl = {}
            for cand in env.prev_word_pron_translation:iter() do
                idx = idx + 1
                local cand_text = cand.text
                if (utf8.len(cand_text) == 2) and (not cand_text:match("[%a%d%p]")) then
                    local cand_header_text = string.utf8_sub(cand_text, 1, 1)
                    local cand_tailer_text = string.utf8_sub(cand_text, 2, 2)
                    local cand_header_code = cand_header_text
                        and env.reversedb:lookup(cand_header_text):sub(4, 5)
                    local cand_tailer_code = cand_tailer_text
                        and env.reversedb:lookup(cand_tailer_text):sub(4, 5)
                    local cand_shape_code = cand_tailer_code .. cand_header_code
                    word_shape_code_tbl[idx] = { cand_text, cand_shape_code }
                end
            end
            env.prev_word_shape_code_tbl = word_shape_code_tbl
        end
        if table.len(env.prev_word_shape_code_tbl) < 1 then return end

        for idx, val in ipairs(env.prev_word_shape_code_tbl) do
            local cand_text = val[1]
            local word_shape_code = val[2]
            local input_shape_code = input:sub(6)
            if idx == 1 then first_cand_confirmed_text = string.utf8_sub(cand_text, 1, 1) end
            local _p1 = input_shape_code and input_shape_code:sub(1, 1) or ""
            local _p2 = (input_shape_code:len() == 2) and (input_shape_code:sub(2)) or ""
            local _remain_code = word_shape_code:gsub(_p1, "", 1):gsub(_p2, "", 1)
            local remain_shape_code = ((_p1 .. _p2):len() == 2) and " ⌛~" or (" ~" .. _remain_code)
            local comment = remain_shape_code:gsub(".$", "")
            local shpae_match_pattern = "^" .. _p1 .. ".?" .. _p2
            -- local shpae_match_pattern = _p1 .. ".?" .. _p2 .. "?" .. _p1 .. "?" .. _p2
            if input_shape_code:len() < 1 then
                local cand = Candidate("cs", seg.start, seg._end, cand_text, comment)
                yield(cand)
            elseif word_shape_code:match(shpae_match_pattern) then
                filtered_cand_text = cand_text
                filtered_cand_count = filtered_cand_count + 1
                local cand = Candidate("cs", seg.start, seg._end, cand_text, comment)
                cand.quality = 999
                yield(cand)
                if first_cand_confirmed_text and (word_shape_code:sub(1, 2):match("^" .. input_shape_code .. "$")) then
                    filtered_cand_text = first_cand_confirmed_text .. string.utf8_sub(cand_text, -1, -1)
                    local scand = Candidate("cs", seg.start, seg._end, filtered_cand_text, " ⭐️️")
                    cand.quality = 888
                    yield(scand)
                end
            end
        end
    end
end

function F.func(input, env)
    local normal_cands = {}
    local symbol_cands = {}
    local preselecte_cands = {}
    local single_char_cands = {}
    local context = env.engine.context
    local preedit_code = context.input
    local caret_pos = context.caret_pos

    for cand in input:iter() do
        -- 符号自动上屏(;[a-z])
        if preedit_code:match("^;%l+$") and not symbol_cands[cand] then
            table.insert(symbol_cands, cand)
        end

        -- 单字全码唯一自动上屏(xy/ab?)
        if (not single_char_cands[cand]) and preedit_code:match("^%l%l/%l%l?$") then
            table.insert(single_char_cands, cand)
        end

        if cand.type:match("^cs") then
            table.insert(preselecte_cands, cand)
        end

        if #normal_cands >= 200 then break end
        table.insert(normal_cands, cand)
    end

    -- 符号自动上屏(;[a-z]+)
    if preedit_code:match("^;%l+$") and (#symbol_cands == 1) then
        env.engine:commit_text(symbol_cands[1].text)
        context:clear()
        return 1 -- kAccepted
    end

    -- 单字全码唯一自动上屏(xy/ab?)
    if (caret_pos == #preedit_code) and preedit_code:match("^%l%l/%l%l?$") then
        if env.word_auto_commit and (#single_char_cands == 1) then
            local cand_obj = single_char_cands[1]
            local cand_text = cand_obj.text
            local cand_text_fm = insert_space_to_candText(env, cand_text)
            set_committed_cand_is_chinese(env)
            env.engine:commit_text(cand_text_fm)
            context:clear()
            return 1 -- kAccepted
        end

        for _, cand in ipairs(single_char_cands) do
            local input_shape_code = preedit_code:sub(4)
            local current_cand_shape_code = cand.comment:match("%l") and cand.comment:sub(2):gsub("%[", "")
            if not current_cand_shape_code then return end
            local remain_shape_code, _ = string.gsub(current_cand_shape_code, input_shape_code, "", 1)
            local comment = (string.len(remain_shape_code) > 0) and string.format("~%s", remain_shape_code) or " "
            yield(ShadowCandidate(cand, cand.type, cand.text, comment, false))
        end
    end

    if #preselecte_cands > 0 then
        for _, cand in ipairs(preselecte_cands) do
            yield(cand)
        end
    end

    for _, cand in ipairs(normal_cands) do
        yield(cand)
    end
end

return {
    translator = {
        init = M.init,
        func = T.func,
        fini = M.fini,
    },
    filter = {
        init = M.init,
        func = F.func,
        fini = M.fini,
    },
}
