-- 输入的内容大写前2个字符，自动转小写词条为全词大写；大写第一个字符，自动转写小写词条为首字母大写
local function autocap_filter(input, env)
	if true then
		--  if( env.engine.context:get_option("autocap_filter")) then
		for cand in input:iter() do
			local text = cand.text
			local commit = env.engine.context:get_commit_text()
			if string.find(text, "^%l%l.*") and string.find(commit, "^%u%u.*") then
				if string.len(text) == 2 then
					yield(Candidate("cap", 0, 2, commit, "+"))
				else
					yield(
						Candidate("cap", 0, string.len(commit), string.upper(text), "+" .. string.sub(cand.comment, 2))
					)
				end
			--[[ 修改候选的注释 `cand.comment`
            因复杂类型候选项的注释不能被直接修改，
            因此使用 `get_genuine()` 得到其对应真实的候选项
            cand:get_genuine().comment = cand.comment .. " " .. s
        --]]
			elseif string.find(text, "^%l+$") and string.find(commit, "^%u+") then
				local suffix = string.sub(text, string.len(commit) + 1)
				yield(Candidate("cap", 0, string.len(commit), commit .. suffix, "+" .. suffix))
			else
				yield(cand)
			end
		end
	else
		for cand in input:iter() do
			yield(cand)
		end
	end
end

return {autocapfilter=autocap_filter}
