-- 输入的内容大写前2个字符，自动转小写词条为全词大写；大写第一个字符，自动转写小写词条为首字母大写
local function autocap_filter(input, env)
    for cand in input:iter() do
        local text = cand.text
        local commit = env.engine.context:get_commit_text()
        if string.find(text, "^%l%l.*") and string.find(commit, "^%u%u.*") then
            if string.len(text) == 2 then
                local cand_2 = Candidate("cap", 0, 2, commit, "+")
                yield(cand_2)
            else
                local cand_u = Candidate("cap", 0, string.len(commit),
                                         string.upper(text), "+AU")
                yield(cand_u)
            end
            --[[ 修改候选的注释 `cand.comment`
            因复杂类型候选项的注释不能被直接修改，
            因此使用 `get_genuine()` 得到其对应真实的候选项
            cand:get_genuine().comment = cand.comment .. " " .. s
        --]]
        elseif string.find(text, "^%l+$") and string.find(commit, "^%u+") then
            local suffix = string.sub(text, string.len(commit) + 1)
            local cand_ua = Candidate("cap", 0, string.len(commit),
                                      commit .. suffix, "+" .. suffix)
            yield(cand_ua)
        elseif string.find(cand.text, "^%l+") and (not string.find(cand.text, "[:/]+")) then
            local cand_a = Candidate("a", 0, string.len(commit), " " .. cand.text, "~AS")
            yield(cand_a)
        else
            yield(cand)
        end
    end
end

---@diagnostic disable-next-line: unused-local
local function autocap_translator(input, seg, env)
    if string.match(input, '%u%u%l+') then
        local cand = Candidate("word_caps", seg.start, seg._end, string.upper(input), '~AU')
        yield(cand)
    end
end
return {filter = autocap_filter, translator = autocap_translator}
