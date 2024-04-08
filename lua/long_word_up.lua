-- local puts = require("tools/debugtool")

local function long_word_up(input, env)
	local engine = env.engine
	local config = engine.schema.config

	local cands = {}
	local longWord_cands = {}
	-- 记录第一个候选词的长度，提前的候选词至少要比第一个候选词长
	local prev_word_length = 0
	-- 记录筛选了多少个汉语词条(只提升1个词的权重)
	local pickup_count = 1
	local idx = config:get_int("long_word_up_config/idx") or 3

	local preedit_code = env.engine.context:get_commit_text()
	for cand in input:iter() do
		local cand_length = utf8.len(cand.text)
		if (cand.quality > 9) or (idx > 1) then
			prev_word_length = cand_length or 0
			idx = idx - 1
			yield(cand)
		elseif
			(cand_length > prev_word_length)
			and (cand_length >= 3)
			and (pickup_count >= 1)
			and (#cand.comment < 3)
			and (preedit_code:len() > 2)
			and (not cand.text:match("[a-zA-Z]"))
			and (cand:get_dynamic_type() ~= "Shadow")
		then
			local cand_uniq = UniquifiedCandidate(cand, "LongWordUp", cand.text, cand.comment)
			yield(cand_uniq)
			pickup_count = pickup_count - 1
		else
			if ((utf8.len(cand.text) / #preedit_code) <= 1.5) or (cand.quality > 9) then
				table.insert(cands, cand)
			else
				table.insert(longWord_cands, cand)
			end
		end

		if #cands > 80 then
			break
		end
	end

	for _, cand in ipairs(cands) do
		yield(cand)
	end
	for _, long_cand in ipairs(longWord_cands) do
		yield(long_cand)
	end
end

return { filter = long_word_up }
