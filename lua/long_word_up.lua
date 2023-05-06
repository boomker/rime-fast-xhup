---@diagnostic disable: undefined-global

-- local puts = require("tools/debugtool")
-- local opencc_emoji = Opencc('emoji.json')
-- local arr = opencc_emoji:convert_word(cand.text) or {}

local function long_word_up(input, env)
	local cands = {}
	-- 记录第一个候选词的长度，提前的候选词至少要比第一个候选词长
	local first_word_length = 0
	local first_word_quality = 0
    local count = 1
	-- 记录筛选了多少个汉语词条(只提升1个词的权重)
	local ocn_count = 0
	local preedit_code = env.engine.context:get_commit_text()
	for cand in input:iter() do
		local cand_per_length = utf8.len(cand.text)
		local cand_per_quality = cand.quality

		if first_word_length < 1 then
			first_word_length = cand_per_length or 0
	        first_word_quality = cand_per_quality or 0

			if (string.find(cand.text, "[^x00-xff]+")) then
                FirstWordType = "chinese"
                yield(cand)
            else
                if string.len(preedit_code) > 3 then
                    yield(cand)
                end
			end
		elseif string.find(cand.text, "^[%w%u%l%s·-]+$") and FirstWordType ~= "chinese" then
			if
				-- string.len(cand.text) / string.len(preedit_code) > 1.3
				string.len(cand.text) / string.len(preedit_code) <= 2.5
				and string.len(cand.comment) <= 4
				and string.len(preedit_code) >= 3
			then
				yield(cand)
			end
		elseif (cand_per_length > first_word_length) and (cand_per_length > 3)
            and (ocn_count < count) and (cand_per_quality * 10 > first_word_quality)
            and (string.find(cand.text, "[%w%u]") == nil)
            and string.len(preedit_code) > 2 then
				yield(cand)
				ocn_count = ocn_count + 1
		else
			table.insert(cands, cand)
		end

        if #cands > 40 then
            break
        end
	end

	for _, cand in ipairs(cands) do
		yield(cand)
	end
end

return {filter = long_word_up}
