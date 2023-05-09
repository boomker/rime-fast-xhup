-- local puts = require("tools/debugtool")
local reversedb = ReverseDb("build/flypy_phrase_fzm.reverse.bin")
local function top_word_autocommit(input, env)
    local cands = {}
    local single_char_cands = {}
    local tword_phrase_cands = {}
    local context = env.engine.context
    local preedit_code = context.input
    local pos = context.caret_pos
    local done = 0
    local when_done = 0
    local prev_cand_text_tbl = {}
    -- local preedit_code = context:get_commit_text()
    -- local preedit_code_length = #input_code
    for cand in input:iter() do
        if (#preedit_code == 4 or #preedit_code == 5) and
            string.find(preedit_code, "^[%l]+%[[%l]+$") then
            table.insert(single_char_cands, cand)
        end

        if string.len(preedit_code) == 7 and
            string.find(preedit_code, "^[%l]+%[[%l]+$") and
            (utf8.len(cand.text) == 2 or pos == 5) and
            string.sub(preedit_code, 5, 5) == "[" then
            tword_phrase_cands[cand.text] = cand
            -- TODO: drop_list 里的 排除, 可能会 内存使用过多
        end

        if #cands > 50 then break end
        table.insert(cands, cand)
    end

    if (#preedit_code == 4 or #preedit_code == 5) and string.find(preedit_code, "^[%l]+%[[%l]+$") then
        local prev_cand_text = nil
        for i, cand in ipairs(single_char_cands) do
            if #cand.text < 2 then table.remove(single_char_cands, i) end

            yield(cand)
            local res = cand.text == prev_cand_text
            -- local ccand_code = string.gsub(cand_code, '%[', '')
            -- local cpreedit_code = string.gsub(preedit_code, '%[', '')
            -- local char_cands = table.unique(single_char_cands)
            -- if string.find(ccand_code, cpreedit_code) and #single_char_cands <= 2 then
            -- puts(INFO, cand.text,  cand.quality, #single_char_cands)
            -- FIXME : 不可见的繁体生僻字,  脚本无法识别
            if #single_char_cands == 1 or (res and #single_char_cands <= 2) then
                env.engine:commit_text(cand.text)
                env.engine.context:clear()
                return 1 -- kAccepted
            end
            prev_cand_text = cand.text
        end
    end

    if string.len(preedit_code) == 7 and string.find(preedit_code, "^[%l]+%[[%l]+$") then
        local prev_cand_text = nil
        for k, cand in pairs(tword_phrase_cands) do
            yield(cand)

            if (#tword_phrase_cands == 1 or table.len(tword_phrase_cands) == 1) and
                pos == 7 then
                env.engine:commit_text(cand.text)
                env.engine.context:clear()
                return 1 -- kAccepted
            elseif (#tword_phrase_cands == 2 or table.len(tword_phrase_cands) ==
                    2) and pos == 7 and prev_cand_text == k then
                env.engine:commit_text(cand.text)
                context:clear()
                return 1 -- kAccepted
            end
            -- local prev_remain_code = string.sub(preedit_code, 6, 7)
            -- puts(INFO, '-----', pos, #tword_phrase_cands,prev_remain_code)
            -- context:push_input(prev_remain_code) -- FIX: 已上屏的编码残留，即便refresh_non_confirmed_composition 也没啥用
            prev_cand_text = k
        end
    end

    for i, cand in ipairs(cands) do
        yield(cand)

        if table.find({6, 8}, #preedit_code) and string.find(preedit_code, "^[%l]+$") and i <= 4
            and (not table.find(prev_cand_text_tbl, cand.text)) then
            local reverse_code = reversedb:lookup(cand.text)
            -- puts(INFO, "__________", cand.text, cand.quality, reverse_code, preedit_code)

            if string.match(reverse_code, preedit_code) then
                done = done + 1
                when_done = i
                table.insert(prev_cand_text_tbl, cand.text)
            end
        end
        if (i == 4 and done == 1 and when_done == 1 )  then
            env.engine:commit_text(prev_cand_text_tbl[1])
            env.engine.context:clear()
            return 1 -- kAccepted
        end
    end
end

return { filter = top_word_autocommit }
