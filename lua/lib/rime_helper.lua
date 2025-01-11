---@diagnostic disable: lowercase-global

function detect_os()
	local user_distribute_name = rime_api:get_distribution_code_name()
	if user_distribute_name:lower():match("weasel") then
		return "Windows"
	elseif user_distribute_name:lower():match("squirrel") then
		return "MacOS"
	elseif
		user_distribute_name:lower():match("fcitx%-rime")
        and io.popen("uname -s"):read("*l"):lower():match("darwin")
	then
		return "MacOS"
	elseif user_distribute_name:lower():match("^fcitx%-rime$") then
		return "Android"
	elseif user_distribute_name:lower():match("trime") then
		return "Android"
	elseif user_distribute_name:lower():match("^fcitx$") then
		return "Linux"
	elseif user_distribute_name:lower():match("ibus") then
		return "Linux"
	elseif user_distribute_name:lower():match("hamster") then
		return "iOS"
	else
		return "Unknown"
	end
end

function reset_commited_cand_state(env)
	local context = env.engine.context
	context:set_property("prev_cand_is_null", "0")
	context:set_property("prev_cand_is_word", "0")
    context:set_property("prev_cand_is_symbol", "0")
	context:set_property("prev_cand_is_chinese", "0")
	context:set_property("prev_cand_is_preedit", "0")
end

function set_commited_cand_is_chinese(env)
	local context = env.engine.context
	reset_commited_cand_state(env)
	context:set_property("prev_cand_is_chinese", "1")
end

function set_commited_cand_is_word(env)
	local context = env.engine.context
	reset_commited_cand_state(env)
	context:set_property("prev_cand_is_word", "1")
end

function set_commited_cand_is_symbol(env)
	local context = env.engine.context
	reset_commited_cand_state(env)
	context:set_property("prev_cand_is_symbol", "1")
end

function insert_space_to_candText(env, cand_text)
	local ccand_text = cand_text
	local context = env.engine.context
	local prev_cand_is_word = context:get_property("prev_cand_is_word")
	local prev_cand_is_preedit = context:get_property("prev_cand_is_preedit")
	if (prev_cand_is_preedit == "1") or (prev_cand_is_word == "1") then
		ccand_text = " " .. cand_text
	end
	return ccand_text
end

function get_selected_candidate_index(key_value, selected_index, page_size)
	local key_name = key_value
	local selected_cand_idx = -1
	local page_cand_size = page_size or 7
	if key_name == "space" then
		key_name = -1
	elseif key_name == "Return" then
		key_name = -1
	elseif key_name == "semicolon" then
		key_name = 1
	elseif key_name == "apostrophe" then
		key_name = 2
	elseif key_name:match("^[1-9]$") then
		key_name = tonumber(key_name) - 1
	elseif key_name == "0" then
		key_name = 9
	else
		return -1
	end

	local page_pos = math.floor(selected_index / page_cand_size) + 1
	local idx = (key_name == -1) and selected_index or key_name
	selected_cand_idx = ((type(key_name) == "number") and (key_name ~= -1) and (page_pos > 1))
			and (key_name + (page_pos - 1) * page_cand_size) or idx
	return selected_cand_idx
end
