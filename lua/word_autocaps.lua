-- 输入的内容大写前2个字符，自动转小写词条为全词大写；大写第一个字符，自动转写小写词条为首字母大写

local function autocap_filter(input, env)
    local u_cands = {}
	for cand in input:iter() do
		local text = cand.text
		local preedit_code = env.engine.context:get_commit_text()
		if string.find(text, "^%l%l.*") and string.find(preedit_code, "^%u%u.*") then
			if string.len(text) == 2 then
				local cand_2 = Candidate("cap", 0, 2, preedit_code, "+")
				yield(cand_2)
			else
				local cand_u = Candidate("cap", 0, string.len(preedit_code), string.upper(text), "+AU")
                table.insert(u_cands, cand_u)
				-- yield(cand_u)
			end
		--[[ 修改候选的注释 `cand.comment`
            因复杂类型候选项的注释不能被直接修改，
            因此使用 `get_genuine()` 得到其对应真实的候选项
            cand:get_genuine().comment = cand.comment .. " " .. s
        --]]
		elseif string.find(text, "^%l+$") and string.find(preedit_code, "^%u+") then
			local suffix = string.sub(text, string.len(preedit_code) + 1)
			local cand_at = Candidate("cap", 0, string.len(preedit_code), preedit_code .. suffix, "~AT")
            table.insert(u_cands, cand_at)
			-- yield(cand_ua)
		else
			yield(cand)
		end
        if #u_cands >= 100 then
            break
        end
	end
    for _, cand in ipairs(u_cands) do
        yield(cand)
    end
end

local function autocap_translator(input, seg, env)
	if string.match(input, "^%u%u%l+") then
		local cand = Candidate("word_caps", seg.start, seg._end, string.upper(input), "~AU")
		yield(cand)
	end
end

return { filter = autocap_filter, translator = autocap_translator }
