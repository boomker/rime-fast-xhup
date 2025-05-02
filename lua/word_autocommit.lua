require("lib/string")
require("lib/metatable")
require("lib/rime_helper")

local P = {}
local T = {}
local F = {}
local word_auto_commit = {}

function word_auto_commit.init(env)
    local config = env.engine.schema.config
    local schema_id = config:get_string("schema/schema_id")
    local schema = Schema(schema_id)
    env.reversedb = ReverseLookup(schema_id)
    -- env.memory = Memory(env.engine, schema, "translator")
    env.word_auto_commit = config:get_bool("speller/auto_commit") or false
    env.script_tran = Component.ScriptTranslator(env.engine, schema, "translator", "script_translator")
end

function word_auto_commit.fini(env)
    -- env.memory:disconnect()
    -- if env.memory then env.memory = nil end
    env.script_tran:disconnect()
    if env.script_tran then env.script_tran = nil end
end

function P.func(key, env)
    local engine = env.engine
    local key_value = key:repr()
    local schema = engine.schema
    local context = engine.context
    local input_code = context.input
    local page_size = schema.page_size
    local caret_pos = context.caret_pos

    local composition = context.composition
    if composition:empty() then
        return 2
    end
    local segment = composition:back()
    local commit_history = context.commit_history

    -- 按下 '/' 后, 数字键或符号键选单字时, 自动上屏
    local idx = segment.selected_index
    local seleted_cand_index = get_selected_candidate_index(key_value, idx, page_size)
    if (seleted_cand_index >= 0) and input_code:match("^%l+/$") and (caret_pos >= 3) then
        context:select(seleted_cand_index)
        local _cand_text = context:get_commit_text():utf8_sub(1, -2)
        local cand_txt = insert_space_to_candText(env, _cand_text)
        set_commited_cand_is_chinese(env)
        engine:commit_text(cand_txt)
        commit_history:push("raw", cand_txt)
        context:clear()
        return 1
    end

    return 2 -- kNoop
end

function T.func(input, seg, env)
    local context = env.engine.context
    local caret_pos = context.caret_pos
    local composition = context.composition
    local preedit_code = context:get_preedit().text
    if composition:empty() then
        return
    end
    local commit_history = context.commit_history
    local auto_commit_enable = env.word_auto_commit

    -- 四码二字词, 通过形码过滤候选项并 给词条加权重后 yield
    if input:match("^%l%l%l%l/%l?%l?$") and (caret_pos >= 5) then
        local filtered_cand_text = ""
        local filtered_cand_count = 0
        local word_shape_code_tbl = {}

        local word_yin_code = input:sub(1, 4)
        local word_cands = env.script_tran:query(word_yin_code, seg) or nil

        if word_cands then
            local idx = 0
            for dictentry in word_cands:iter() do
                idx = idx + 1
                local entry_text = dictentry.text
                if (utf8.len(entry_text) == 2) and (not entry_text:match("%a%d%p")) then
                    local _cand_header_text = string.utf8_sub(entry_text, 1, 1)
                    local _cand_tailer_text = string.utf8_sub(entry_text, 2, 2)
                    local cand_header_code = _cand_header_text
                        and env.reversedb:lookup(_cand_header_text):sub(4, 4)
                    local cand_tailer_code = _cand_tailer_text
                        and env.reversedb:lookup(_cand_tailer_text):sub(4, 5)
                    local cand_shape_code = cand_tailer_code .. cand_header_code
                    word_shape_code_tbl[idx] = { entry_text, cand_shape_code }
                end
            end
        end
        if table.len(word_shape_code_tbl) < 1 then
            return
        end

        for _, val in ipairs(word_shape_code_tbl) do
            local input_shape_code = string.sub(input, 6)
            local _p1 = input_shape_code and input_shape_code:sub(1, 1) or ""
            local _p2 = (input_shape_code:len() == 2) and (input_shape_code:sub(2)) or ""
            local match_pattern = "^" .. _p1 .. ".?" .. _p2
            local remain_shape_code = val[2]:gsub(_p1, "", 1):gsub(_p2, "", 1)
            local comment = (remain_shape_code:len() > 0) and string.format("~%s", remain_shape_code) or " "
            if val[2]:match(match_pattern) then
                local cand = Candidate("wac", seg.start, seg._end, val[1], comment)
                filtered_cand_count = filtered_cand_count + 1
                filtered_cand_text = val[1]
                cand.quality = 999
                yield(cand)
            elseif input:match("^%l%l%l%l/$") then
                local cand = Candidate("wac", seg.start, seg._end, val[1], comment)
                yield(cand)
            end
        end

        if
            auto_commit_enable
            and (filtered_cand_count == 1)
            and (utf8.len(preedit_code) <= 8)
            and (utf8.len(filtered_cand_text) == 2)
        then
            local cand_text = insert_space_to_candText(env, filtered_cand_text)
            set_commited_cand_is_chinese(env)
            env.engine:commit_text(cand_text)
            commit_history:push("raw", cand_text)
            context:clear()
            return
        end
    end
end

function F.func(input, env)
    local normal_cands = {}
    local symbol_cands = {}
    local single_char_cands = {}
    local context = env.engine.context
    local preedit_code = context.input
    local caret_pos = context.caret_pos
    local commit_history = context.commit_history

    for cand in input:iter() do
        -- 符号自动上屏(;[a-z])
        if preedit_code:match("^;%l+$") and not symbol_cands[cand] then
            table.insert(symbol_cands, cand)
        end

        -- 单字全码唯一自动上屏(xy/ab?)
        if (not single_char_cands[cand]) and preedit_code:match("^%l%l/%l%l?$") then
            table.insert(single_char_cands, cand)
        end

        if #normal_cands >= 150 then
            break
        end
        table.insert(normal_cands, cand)
    end

    -- 符号自动上屏(;[a-z]+)
    if preedit_code:match("^;%l+$") and (#symbol_cands == 1) then
        env.engine:commit_text(symbol_cands[1].text)
        context:clear()
        return 1 -- kAccepted
    end

    -- 单字全码唯一自动上屏(xy/ab?)
    if (caret_pos >= 4) and preedit_code:match("^%l%l/%l%l?$") then
        if #single_char_cands == 1 then
            local cand_txt = insert_space_to_candText(env, single_char_cands[1].text)
            set_commited_cand_is_chinese(env)
            env.engine:commit_text(cand_txt)
            commit_history:push("raw", cand_txt)
            context:clear()
            return 1 -- kAccepted
        end

        for _, cand in ipairs(single_char_cands) do
            local input_shape_code = string.sub(preedit_code, 4):gsub("/", "")
            local current_cand_shape_code = cand.comment:match("%l") and cand.comment:sub(2):gsub("%[", "")
            local remain_shape_code, _ = string.gsub(current_cand_shape_code, input_shape_code, "", 1)
            local comment = (string.len(remain_shape_code) > 0) and string.format("~%s", remain_shape_code)
                or " "
            ---@diagnostic disable-next-line: missing-parameter
            yield(ShadowCandidate(cand, cand.type, cand.text, comment))
        end
    end

    for _, cand in ipairs(normal_cands) do
        yield(cand)
    end
end

return {
    processor = {
        init = word_auto_commit.init,
        func = P.func,
        fini = word_auto_commit.fini,
    },
    translator = {
        init = word_auto_commit.init,
        func = T.func,
        fini = word_auto_commit.fini,
    },
    filter = {
        init = word_auto_commit.init,
        func = F.func,
        fini = word_auto_commit.fini,
    },
}
