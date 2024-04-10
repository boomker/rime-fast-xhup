local reduce_emoji = {}

function reduce_emoji.func(input, env)
	local engine = env.engine
	local config = engine.schema.config
	local normal_cands = {}
	local emoji_cands = {}
	local other_cands = {}
	local prev_cand_text = ""
	local emoji_pos = config:get_int("emoji_reduce_config/idx") or 6
	local top_cand_cnt = (emoji_pos + 1)
	local opencc_emoji = Opencc("emoji.json")

	for cand in input:iter() do
		local cand_text = cand.text:gsub(" ", "")

		if
			(top_cand_cnt >= 0)
			and (cand:get_dynamic_type() == "Shadow")
			and not (cand_text:find("([\228-\233][\128-\191]-)") and cand_text:find("[%a]"))
		then
			table.insert(emoji_cands, { prev_cand_text, cand })
			top_cand_cnt = top_cand_cnt - 1
		elseif top_cand_cnt >= 0 then
			local emoji_tab = opencc_emoji:convert_word(cand_text) or { cand_text }
			for _, emoji_txt in ipairs(emoji_tab) do
				if #emoji_tab > 1 and emoji_txt == cand_text then
					prev_cand_text = cand_text
				end
			end
			table.insert(normal_cands, cand)
			top_cand_cnt = top_cand_cnt - 1
		else
			table.insert(other_cands, cand)
		end
	end

	for _, normal_cand in ipairs(normal_cands) do
		yield(normal_cand)
		emoji_pos = emoji_pos - 1
		-- TODO: 取出前 N 个非表情候选词条里有*多少个*可转换为表情的候选词条
		if (emoji_pos == 1) and (#emoji_cands > 0) then
			for _, emoji_cand_item in ipairs(emoji_cands) do
				yield(
					ShadowCandidate(
						emoji_cand_item[2],
						emoji_cand_item[2].type,
						emoji_cand_item[2].text,
						emoji_cand_item[1]
					)
				)
			end
			emoji_pos = emoji_pos - 1
		end
		if emoji_pos == 0 then
			yield(normal_cand)
		end
	end

	for _, cand in ipairs(other_cands) do
		yield(cand)
	end
end

return {
	filter = reduce_emoji.func,
}
