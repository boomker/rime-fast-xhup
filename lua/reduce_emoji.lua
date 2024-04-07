local reduce_emoji = {}

function reduce_emoji.func(input, env)
	local engine = env.engine
	local config = engine.schema.config
	local emoji_cands = {}
	local emoji_texts = {}
	local other_cands = {}
	local prev_text = ""
	local emoji_pos = config:get_int("emoji_reduce_config/idx") or 6

	for cand in input:iter() do
		if
            (cand:get_dynamic_type() == "Shadow")
            and (not cand.text:match("[a-zA-Z]"))
            and (emoji_pos >= 1)
        then
			table.insert(emoji_cands, cand)
			table.insert(emoji_texts, prev_text)
			emoji_pos = emoji_pos - 1
		elseif emoji_pos > 0 then
			yield(cand)
			emoji_pos = emoji_pos - 1
			if cand.type ~= "LongWordUp" then
				prev_text = cand.text
			end
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
