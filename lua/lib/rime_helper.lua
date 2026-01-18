---@diagnostic disable: lowercase-global

function detect_os()
    local user_data_dir = rime_api.get_user_data_dir() or ""
    local rime_distribute_name = rime_api:get_distribution_code_name()
    if rime_distribute_name:lower():match("weasel") then
        return "Windows"
    elseif rime_distribute_name:lower():match("squirrel") then
        return "MacOS"
    elseif
        rime_distribute_name:lower():match("fcitx%-rime")
        and user_data_dir:match("local/share/fcitx5/rime") then
        return "MacOS"
    elseif rime_distribute_name:lower():match("^fcitx%-rime$") then
        return "Android"
    elseif rime_distribute_name:lower():match("trime") then
        return "Android"
    elseif rime_distribute_name:lower():match("^fcitx$") then
        return "Linux"
    elseif rime_distribute_name:lower():match("ibus") then
        return "Linux"
    elseif rime_distribute_name:lower():match("hamster") then
        return "iOS"
    else
        return "Unknown"
    end
end

function reset_committed_cand_state(env)
    local context = env.engine.context
    context:set_property("prev_cand_is_null", "0")
    context:set_property("prev_cand_is_word", "0")
    context:set_property("prev_cand_is_symbol", "0")
    context:set_property("prev_cand_is_chinese", "0")
    context:set_property("prev_cand_is_preedit", "0")
end

function set_committed_cand_is_chinese(env)
    local context = env.engine.context
    reset_committed_cand_state(env)
    context:set_property("prev_cand_is_chinese", "1")
end

function set_committed_cand_is_word(env)
    local context = env.engine.context
    reset_committed_cand_state(env)
    context:set_property("prev_cand_is_word", "1")
end

function set_committed_cand_is_symbol(env)
    local context = env.engine.context
    reset_committed_cand_state(env)
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

function get_selected_candidate_index(key_value, selected_index, select_keys, page_size)
    page_size = page_size or 7
    local selected_cand_idx = -1
    local key_map = {
        ["space"] = "-1",
        ["return"] = "-1",
        ["period"] = ".",
        ["semicolon"] = ";",
        ["apostrophe"] = "'",
    }
    local kv = key_map[key_value:lower()] or key_value
    local key_name = select_keys:find("[" .. kv .. "]") or tonumber(kv)
    if not key_name then
        return -1
    elseif key_name == -1 then
        return selected_index
    elseif key_name > page_size then
        return -1
    elseif tostring(key_name):match("^[1-9]$") then
        key_name = tonumber(key_name) - 1
    elseif key_name == "0" then
        key_name = 10
    else
        return -1
    end

    local page_pos = math.floor(selected_index / page_size) + 1
    selected_cand_idx = ((type(key_name) == "number") and (key_name ~= -1) and (page_pos > 1))
        and (key_name + (page_pos - 1) * page_size) or key_name
    return selected_cand_idx
end
