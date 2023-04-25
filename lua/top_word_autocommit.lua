
local reverse_dict = ReverseDb("build/flypy_xhfast.reverse.bin") -- 从编译文件中获取反查词库
local function top_word_autocommit(input, env)
	local cands = {}
    local single_char_cands = {}
    local tword_phrase_cands = {}
	local preedit_code = env.engine.context:get_commit_text()
	for cand in input:iter() do

        if string.len(preedit_code) == 5 and string.find(preedit_code, "^[%l]+%[[%l]+$") then
            table.insert(single_char_cands, cand)
        end

        if string.len(preedit_code) == 7 and string.find(preedit_code, "^[%l]+%[[%l]+$") then
            if utf8.len(cand.text) == 2 then
                table.insert(tword_phrase_cands , cand)
            end
        end
        table.insert(cands, cand)
    end

    if string.len(preedit_code) == 5 and string.find(preedit_code, "^[%l]+%[[%l]+$") then
        for _, cand in ipairs(single_char_cands) do
            yield(cand)
            local cand_code = reverse_dict:lookup(cand.text) or "" -- 待自动上屏的候选项编码
            local ccand_code = string.gsub(cand_code, '%[', '')
            local ccommit_text = string.gsub(preedit_code, '%[', '')
            -- local char_cands = table.unique(single_char_cands)
            if string.find(ccand_code, ccommit_text) and #single_char_cands <= 2 then
                env.engine:commit_text(cand.text)
                env.engine.context:clear()
                return 1 -- kAccepted
            end
        end
    end
    -- puts(INFO, '______', string.len(commit_text), commit_text, #tword_phrase_cands)
    if string.len(preedit_code) == 7 and string.find(preedit_code, "^[%l]+%[[%l]+$") then
        for _, cand in ipairs(tword_phrase_cands) do
            yield(cand)
            if #tword_phrase_cands == 1 then
                env.engine:commit_text(cand.text)
                env.engine.context:clear()
                return 1 -- kAccepted
            end
        end
    end

    for _, cand in ipairs(cands) do
        yield(cand)
    end
end

return {filter = top_word_autocommit}
