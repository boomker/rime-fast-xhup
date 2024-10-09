local M = {}

function M.detect_os()
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

function M.get_selected_candidate_index(key_value, selected_index, page_size)
	local keyValue = key_value
	local selected_cand_idx = -1
	local page_cand_size = page_size or 7
	if keyValue == "space" then
		keyValue = -1
	elseif keyValue == "Return" then
		keyValue = -1
	elseif keyValue == "semicolon" then
		keyValue = 1
	elseif keyValue == "apostrophe" then
		keyValue = 2
	elseif keyValue:match("^[1-9]$") then
		keyValue = tonumber(keyValue) - 1
	elseif keyValue == "0" then
		keyValue = 9
	else
		return -1
	end

	local page_pos = math.floor(selected_index / page_cand_size) + 1
	local idx = (keyValue == -1) and selected_index or keyValue
	selected_cand_idx = ((type(keyValue) == "number") and (keyValue ~= -1) and (page_pos > 1))
			and (keyValue + (page_pos - 1) * page_cand_size) or idx
	return selected_cand_idx
end

function M.insert_space_to_candText(env, cand_text)
	local context = env.engine.context
	local ccand_text = cand_text
	if (context:get_property("prev_cand_is_preedit") == "1") or (context:get_property("prev_cand_is_word") == "1") then
		ccand_text = " " .. cand_text
	end
	return ccand_text
end

function M.reset_commited_cand_state(env)
	local context = env.engine.context
	context:set_property("prev_cand_is_null", "0")
	context:set_property("prev_cand_is_word", "0")
    context:set_property("prev_cand_is_symbol", "0")
	context:set_property("prev_cand_is_chinese", "0")
	context:set_property("prev_cand_is_preedit", "0")
	-- context:set_property("prev_commit_is_comma", "0")
	-- context:set_property("prev_commit_is_period", "0")
end

function M.set_commited_cand_is_chinese(env)
	local context = env.engine.context
	M.reset_commited_cand_state(env)
	context:set_property("prev_cand_is_chinese", "1")
end

function M.set_commited_cand_is_pairSymbol(env)
	local context = env.engine.context
	M.reset_commited_cand_state(env)
	context:set_property("prev_cand_is_symbol", "1")
end

return M
