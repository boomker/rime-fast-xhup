local M = {}


function M.detect_os()
    local user_distribute_name = rime_api:get_distribution_code_name()
    if user_distribute_name:lower():match("weasel") then
        return "Windows"
    elseif user_distribute_name:lower():match("squirrel") then
        return "MacOS"
    elseif user_distribute_name:lower():match("fcitx%-rime") then -- fcitx-rime
        return "MacOS"
    elseif user_distribute_name:lower():match("^fcitx$") then
        return "Linux"
    elseif user_distribute_name:lower():match("ibus") then
        return "Linux"
    elseif user_distribute_name:lower():match("hamster") then
        return "iOS"
    else
        return "iOS"
    end
end

function M.get_selected_candidate_index(keyValue, selected_index, page_size)
    local key_value = keyValue
    local selected_cand_idx = -1
    if keyValue == "space" then
        key_value = -1
    elseif keyValue == "Return" then
        key_value = -1
    elseif keyValue == "semicolon" then
        key_value = 1
    elseif keyValue == "apostrophe" then
        key_value = 2
    elseif string.find(keyValue, "^[1-9]$") then
        key_value = tonumber(keyValue) - 1
    elseif keyValue == "0" then
        key_value = 9
    else
        return -1
    end

    local page_pos = (selected_index // page_size) + 1
    local idx = (key_value == -1) and selected_index or key_value
    selected_cand_idx = (
        (type(key_value) == "number") and (key_value ~= -1) and (page_pos > 1)
    ) and (key_value + (page_pos - 1) * page_size) or idx
    return selected_cand_idx
end

return M
