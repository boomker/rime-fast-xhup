---@diagnostic disable: undefined-global
local function long_word_filter(input, env)
	local cands = {}
	-- 记录第一个候选词的长度，提前的候选词至少要比第一个候选词长
	local length = 0
	-- 记录筛选了多少个英语词条(只提升2个词的权重，并且对comment长度过长的候选进行过滤)
	-- local s_onlyEN = 0
	-- 记录筛选了多少个汉语词条(只提升2个词的权重)
	local s_onlyCN = 0
	local sCNEN = 0
	local commit = env.engine.context:get_commit_text()
	for cand in input:iter() do
		local leng = utf8.len(cand.text)
		if length < 1 then
			length = leng or 0
			-- yield(cand)

			if (string.find(cand.text, "[^x00-xff]+")) then
                FirstWordType = "chinese"
                yield(cand)
            else
                if string.len(commit) > 3 then
                    yield(cand)
                end
			end
		--[[ elseif string.len(cand.text) > 15 then
			table.insert(cands, cand)]]
		elseif string.find(cand.text, "^[%w%u%l%s·-]+$") and FirstWordType ~= "chinese" then
			if
				string.len(cand.text) / string.len(commit) > 1.3
				and string.len(cand.text) / string.len(commit) <= 2.5
				and string.len(cand.comment) <= 4
				and string.len(commit) >= 3
			then
				yield(cand)
			end
		elseif ((leng > length) and (s_onlyCN < 2)) and (string.find(cand.text, "[%w%u]") == nil) then
			if string.len(commit) > 2 then
				yield(cand)
				s_onlyCN = s_onlyCN + 1
			end
		elseif
			((leng > length) and (sCNEN < 2))
			and (string.find(cand.text, "%w%u+"))
			and (string.find(cand.text, "[^x00-xff]+"))
		then
			if string.len(commit) > 3 then
				yield(cand)
				sCNEN = sCNEN + 1
			end
		else
			table.insert(cands, cand)
		end
	end
	for _, cand in ipairs(cands) do
		yield(cand)
	end
end

return { longwordfilter = long_word_filter }
