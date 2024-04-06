local reduce_emoji = {}

---@diagnostic disable-next-line: unused-local
function reduce_emoji.func(input, env)
	local emoji_cands = {}
	local emoji_texts = {}
	local other_cands = {}
	local prev_text = ""
	local emoji_pos = 6
	for cand in input:iter() do
		if (cand:get_dynamic_type() == "Shadow") and (emoji_pos >= 1) then
			table.insert(emoji_cands, cand)
			table.insert(emoji_texts, prev_text)
			emoji_pos = emoji_pos - 1
		elseif emoji_pos > 0 then
			yield(cand)
			emoji_pos = emoji_pos - 1
			prev_text = cand.text
		else
			table.insert(other_cands, cand)
		end
	end

	if #emoji_texts > 0 then
		for i, cand in ipairs(emoji_cands) do
			yield(ShadowCandidate(cand, cand.type, cand.text, emoji_texts[i]))
		end
	end

	for _, cand in ipairs(other_cands) do
		yield(cand)
	end
end

return {
	filter = reduce_emoji.func,
}
