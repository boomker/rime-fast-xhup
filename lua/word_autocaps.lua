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
				local cand_u = Candidate("cap", 0, preedit_code:len(), text:upper(), "+AU")
				table.insert(u_cands, cand_u)
			end
		elseif string.find(text, "^%l+$") and string.find(preedit_code, "^%u+") then
			local suffix = string.sub(text, string.len(preedit_code) + 1)
			local cand_t = Candidate("cap", 0, preedit_code:len(), preedit_code .. suffix, "~AT")
			table.insert(u_cands, cand_t)
		else
			yield(cand)
		end

        if #u_cands >= 120 then break end
	end

	for _, cand in ipairs(u_cands) do yield(cand) end
end

---@diagnostic disable-next-line: unused-local
local function autocap_translator(input, seg, env)
	if input:match("^%u%l%l?%l?%l?%l?%l?%l?$") and input:match("^[^V].*") then
		local cand = Candidate("Word", seg.start, seg._end, input, "")
		cand.quality = 999
		yield(cand)
	elseif input:match("^%u%u%a+") then
		yield(Candidate("word_caps", seg.start, seg._end, input:upper(), "~AU"))
	elseif input:match("^%u%l+%u%a?") then
		yield(Candidate("en_custom", seg.start, seg._end, input, "~AC"))
	elseif input:match("^%a+[.:_-]%/?%/?%/?%a+") then
		yield(Candidate("en_custom", seg.start, seg._end, input, "~AC"))
	end
end

return { filter = autocap_filter, translator = autocap_translator }
