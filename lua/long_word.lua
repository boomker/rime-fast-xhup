-- 长词优先（从后方移动2个英文候选和3个中文长词，提前为第2-6候选；当后方候选长度全部不超过第一候选词时，不产生作用）
local function long_word_filter(input)
	local l = {}
	-- 记录第一个候选词的长度，提前的候选词至少要比第一个候选词长
	local length = 0
	-- 记录筛选了多少个英语词条(只提升3个词的权重，并且对comment长度过长的候选进行过滤)
	local s1 = 0
	-- 记录筛选了多少个汉语词条(只提升3个词的权重)
	local s2 = 0
	for cand in input:iter() do
		leng = utf8.len(cand.text)
		if length < 1 then
			length = leng
			yield(cand)
		elseif #table > 30 then
			table.insert(l, cand)
		elseif ((leng > length) and (s1 < 1)) and (string.find(cand.text, "^[%w%p%s]+$")) then
			s1 = s1 + 1
			if string.len(cand.text) / string.len(cand.comment) > 1.5 then
				yield(cand)
			end
		elseif ((leng > length) and (s2 < 2)) and (string.find(cand.text, "^[%w%p%s]+$") == nil) then
			yield(cand)
			s2 = s2 + 1
		else
			table.insert(l, cand)
		end
	end
	for i, cand in ipairs(l) do
		yield(cand)
	end
end

return {longwordfilter=long_word_filter}
