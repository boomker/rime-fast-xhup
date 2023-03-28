function select_character(key, env)
	local engine = env.engine
	local context = engine.context
	local commit_text = context:get_commit_text()
	local config = engine.schema.config

	local first_key = config:get_string('key_binder/select_first_character') or 'bracketleft'
	local last_key = config:get_string('key_binder/select_last_character') or 'bracketright'
	-- local first_key = config:get_string("key_binder/select_first_character")
	-- local last_key = config:get_string("key_binder/select_last_character")

	if key:repr() == first_key and commit_text ~= "" then
		engine:commit_text(first_character(commit_text))
		context:clear()

		return 1 -- kAccepted
	end

	if key:repr() == last_key and commit_text ~= "" then
		engine:commit_text(last_character(commit_text))
		context:clear()

		return 1 -- kAccepted
	end

	return 2 -- kNoop
end
