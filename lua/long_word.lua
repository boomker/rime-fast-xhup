---@diagnostic disable: undefined-global

-- local puts = require("tools/debugtool")
-- local opencc_emoji = Opencc('emoji.json')
-- local arr = opencc_emoji:convert_word(cand.text) or {}

-- require("tools/metatable")
local reverse_dict = ReverseDb("build/flypy_xhfast.reverse.bin") -- 从编译文件中获取反查词库
local function long_word_filter(input, env)
	local cands = {}
    local single_char_cands = {}
    local tword_phrase_cands = {}
	-- 记录第一个候选词的长度，提前的候选词至少要比第一个候选词长
	local length = 0
    local count = 1
    local done = 0
	-- 记录筛选了多少个英语词条(只提升2个词的权重，并且对comment长度过长的候选进行过滤)
	-- local s_onlyEN = 0
	-- 记录筛选了多少个汉语词条(只提升2个词的权重)
	local s_onlyCN = 0
	local sCNEN = 0
	local commit_text = env.engine.context:get_commit_text()
	for cand in input:iter() do
		local leng = utf8.len(cand.text)

		if length < 1 then
			length = leng or 0

			if (string.find(cand.text, "[^x00-xff]+")) then
                FirstWordType = "chinese"
                yield(cand)
            else
                if string.len(commit_text) > 3 then
                    yield(cand)
                end
			end
		elseif string.find(cand.text, "^[%w%u%l%s·-]+$") and FirstWordType ~= "chinese" then
			if
				string.len(cand.text) / string.len(commit_text) > 1.3
				and string.len(cand.text) / string.len(commit_text) <= 2.5
				and string.len(cand.comment) <= 4
				and string.len(commit_text) >= 3
			then
				yield(cand)
			end
		elseif ((leng > length) and leng > 3 and (s_onlyCN < count)) and (string.find(cand.text, "[%w%u]") == nil) then
			if string.len(commit_text) > 2 then
				yield(cand)
				s_onlyCN = s_onlyCN + 1
                done = done + 1
			end
		elseif
			((leng > length) and (sCNEN < count))
			and (string.find(cand.text, "%w%u+"))
			and (string.find(cand.text, "[^x00-xff]+"))
		then
			if string.len(commit_text) > 3 then
				yield(cand)
				sCNEN = sCNEN + 1
                done = done + 1
			end
		else
			table.insert(cands, cand)
		end
        if string.len(commit_text) == 5 and string.find(commit_text, "^[%l]+%[[%l]+$") then
            table.insert(single_char_cands, cand)
        end
        if string.len(commit_text) == 7 and string.find(commit_text, "^[%l]+%[[%l]+$") then
            if utf8.len(cand.text) == 2 then
                table.insert(tword_phrase_cands , cand)
            end
        end

        -- 找齐了或者 l 太大了，就不找了
        if (done == count) or (#cands > 30) then
            break
        end
	end
    if string.len(commit_text) == 5 and string.find(commit_text, "^[%l]+%[[%l]+$") then
        for _, cand in ipairs(single_char_cands) do
            yield(cand)
            local cand_code = reverse_dict:lookup(cand.text) or "" -- 待自动上屏的候选项编码
            local ccand_code = string.gsub(cand_code, '%[', '')
            local ccommit_text = string.gsub(commit_text, '%[', '')
            -- local char_cands = table.unique(single_char_cands)
            if string.find(ccand_code, ccommit_text) and #single_char_cands <= 2 then
                env.engine:commit_text(cand.text)
                env.engine.context:clear()
                return 1 -- kAccepted
            end
        end
    end
    -- puts(INFO, '______', string.len(commit_text), commit_text, #tword_phrase_cands)
    if string.len(commit_text) == 7 and string.find(commit_text, "^[%l]+%[[%l]+$") then
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

return { longwordfilter = long_word_filter }
