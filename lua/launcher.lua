local processor = {}
local translator = {}
local filter = {}
local favor_items = nil
local second_menu_items = nil
local first_menu_selected_text = nil
local second_menu_selected_text = nil

local function cmd(system, cmdArgs, objId)
    if system:lower():match("macos") and (cmdArgs == "exec") then
        local osascript = objId
        os.execute(osascript)
    elseif system:lower():match("ios") and (cmdArgs == "exec") then
        local osascript = objId
        os.execute(osascript)
    elseif system:lower():match("macos") then
        local osascript = "open " .. cmdArgs .. objId
        os.execute(osascript)
    elseif system:lower():match("ios") then
        local osascript = "open " .. cmdArgs .. objId
        os.execute(osascript)
    elseif system:lower():match("windows") then
        local script = "start " .. "" .. objId
        os.execute(script)
    end
end

local function detect_os()
    local system = ""
    local user_distribute_name = rime_api:get_distribution_code_name()
    if user_distribute_name:lower():match("weasel") then
        system = "Windows"
    elseif user_distribute_name:lower():match("squirrel") then
        system = "MacOS"
    elseif user_distribute_name:lower():match("ibus-rime") then
        system = "Linux"
    else
        system = "iOS"
    end
    return system
end

function processor.init(env)
    env.launcher_config = require("launcher_config")
    env.app_launch_prefix = env.launcher_config[1]
    env.favor_cmd_prefix = env.launcher_config[2]
    env.app_command_items = env.launcher_config[3]
    env.system_name = detect_os()
end

function processor.func(key, env)
    local engine = env.engine
    local app_command_items = env.app_command_items
    local appLaunchPrefix = env.app_launch_prefix
    local favorCmdPrefix = env.favor_cmd_prefix
    local system_name = env.system_name
    local context = engine.context
    local composition = context.composition
    local segment = composition:back()
    local inputCode = context.input
    local preeditCodeLength = #inputCode
    local keyValue = key:repr()

    local idx = -1
    local selected_candidate_index = (not composition:empty()) and segment.selected_index or -1
    if keyValue == "space" then
        idx = selected_candidate_index
    elseif keyValue == "Return" and (inputCode:match("^" .. favorCmdPrefix)) then
        idx = selected_candidate_index
    elseif keyValue == "semicolon" then
        idx = 1
    elseif keyValue == "apostrophe" then
        idx = 2
    end

    if keyValue == "1" then
        idx = 0
    elseif string.find(keyValue, "^[2-9]$") then
        idx = tonumber(keyValue) - 1
    elseif keyValue == "0" then
        idx = 9
    end

    local spec_keys = { ["Escape"] = true, ["BackSpace"] = true }

    if context:has_menu() and ((idx >= 0) or spec_keys[keyValue])
        and (inputCode:match("^" .. favorCmdPrefix))
    then
        if (idx >= 0) and (inputCode == favorCmdPrefix) and (segment.prompt:match("快捷指令")) then
            local cand = segment:get_candidate_at(idx)
            local candidateText = cand.text
            first_menu_selected_text = candidateText:gsub(" ", "") .. tostring(idx + 1)
            local prompt = first_menu_selected_text:gsub("[%a%d]", "")
            if first_menu_selected_text then
                second_menu_items = app_command_items["Favors"][first_menu_selected_text]["items"]
                context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
                segment.prompt = "〔" .. prompt .. "〕"
                return 1
            end
        end

        if spec_keys[keyValue] then
            if (inputCode ~= favorCmdPrefix) and (keyValue == "BackSpace") then
                context:pop_input(1)
                context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
            elseif (inputCode == favorCmdPrefix) and (keyValue == "BackSpace") and (segment.prompt:match("快捷指令")) then
                return 2
            elseif (inputCode == favorCmdPrefix) and (keyValue == "BackSpace") then
                context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
            else
                context:clear()
            end
            favor_items = nil
            second_menu_items = nil
            first_menu_selected_text = nil
            second_menu_selected_text = nil
            context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
            return 1                                    -- kAccepted 收下此key
        elseif idx >= 0 then
            local candidateText = segment:get_candidate_at(idx).text:gsub(" ", "")
            local action = app_command_items["Favors"][first_menu_selected_text]["action"]
            local items = app_command_items["Favors"][first_menu_selected_text]["items"]
            if type(items[1]) ~= "string" then
                candidateText = candidateText .. tostring(idx + 1)
            end
            if second_menu_selected_text then
                candidateText = second_menu_selected_text
            end

            if (action == "commit") and type(items[1]) ~= "string" then
                local commitText = app_command_items["Favors"][first_menu_selected_text]["items"][candidateText]
                engine:commit_text(commitText)
            elseif action == "open" and type(items[1]) == "string" then
                cmd(system_name, "", candidateText)
            elseif (action == "open") then
                local _path = app_command_items["Favors"][first_menu_selected_text]["items"][candidateText]
                local path = _path:gsub(" ", "\\ ")
                cmd(system_name, "", path)
            elseif action == "exec" then
                local _cmdString = app_command_items["Favors"][first_menu_selected_text]["items"][candidateText]
                local cmdString = _cmdString:match("^/") and _cmdString:gsub(" ", "\\ ", 1) or _cmdString
                cmd(system_name, "exec", cmdString)
            else
                engine:commit_text(candidateText)
            end
            context:clear()
            favor_items = nil
            first_menu_selected_text = nil
            second_menu_selected_text = nil
            second_menu_items = nil
            return 1 -- kAccepted 收下此key
        end
    end

    if context:has_menu() and (inputCode:match("^" .. appLaunchPrefix) or inputCode:match("^/j")) then
        if (idx >= 0) and (preeditCodeLength > appLaunchPrefix:len()) then
            local items = app_command_items[system_name][inputCode]
            if appLaunchPrefix ~= "/j" and inputCode:sub(1, appLaunchPrefix:len()) == appLaunchPrefix then
                local appTriggerKey = "/j" .. inputCode:gsub(appLaunchPrefix, "", 1)
                items = app_command_items[system_name][appTriggerKey]
            end

            local candidateText = segment:get_candidate_at(idx).text
            local candidateComment = segment:get_candidate_at(idx).comment
            local appId = nil
            if items and type(items[1]) == "table" then
                for _, val in pairs(items) do
                    if val[1] == candidateText then
                        appId = val[2]
                    end
                end
            elseif items and type(items[1]) == "string" then
                appId = items[2]
            end

            if items and candidateText and candidateComment:match("应用闪切") then
                context:clear()
                cmd(system_name, "-b ", appId)
                return 1 -- kAccepted 收下此key
            else
                engine:commit_text(candidateText)
                context:clear()
                return 1 -- kAccepted 收下此key
            end
        end
    end

    return 2
end

function translator.init(env)
    env.launcher_config = require("launcher_config")
    env.app_launch_prefix = env.launcher_config[1]
    env.favor_cmd_prefix = env.launcher_config[2]
    env.app_command_items = env.launcher_config[3]
    env.system_name = detect_os()
end

function translator.func(input, seg, env)
    local composition = env.engine.context.composition
    local app_command_items = env.app_command_items
    local appLaunchPrefix = env.app_launch_prefix
    local favorCmdPrefix = env.favor_cmd_prefix
    local system_name = env.system_name
    local app_items = app_command_items[system_name][input]

    if appLaunchPrefix ~= "/j" and input:sub(1, appLaunchPrefix:len()) == appLaunchPrefix then
        local appTriggerKey = "/j" .. input:gsub(appLaunchPrefix, "", 1)
        app_items = app_command_items[system_name][appTriggerKey]
    end

    if app_items and type(app_items[1]) == "table" then
        for _, val in pairs(app_items) do
            local cand = Candidate("shortcut", seg.start, seg._end, val[1], "〔应用闪切〕")
            cand.quality = 999
            yield(cand)
        end
    elseif app_items and type(app_items[1]) == "string" then
        local cand = Candidate("shortcut", seg.start, seg._end, app_items[1], "〔应用闪切〕")
        cand.quality = 999
        yield(cand)
    end

    if (composition:empty()) then return end
    local segment = composition:back()

    if input:match("^" .. favorCmdPrefix .. "$")
        and (not favor_items) and (not first_menu_selected_text)
        and (not second_menu_items) and (segment.prompt == "")
    then
        second_menu_items = nil
        first_menu_selected_text = nil
        segment.prompt = "〔快捷指令〕"

        for key, _ in pairs(app_command_items["Favors"]) do
            local cand = Candidate("favor", seg.start, seg._end, key, "")
            cand.quality = 999
            yield(cand)
        end
        favor_items = app_command_items["Favors"]
    end

    if input:match("^" .. favorCmdPrefix) and (#input > favorCmdPrefix:len())
        -- and segment.prompt:match("快捷指令")
        and (not first_menu_selected_text) and (not second_menu_items)

    then
        local first_menu_prefix = input:sub(favorCmdPrefix:len() + 1, -1)
        local matchCount = 0
        local matchMenuKey = ""
        local matchMenuItems = nil
        for key, val in pairs(app_command_items["Favors"]) do
            if key:match("^" .. first_menu_prefix) then
                matchCount = matchCount + 1
                matchMenuKey = key
                matchMenuItems = val
            end
        end

        if matchCount == 1 and matchMenuItems then
            local prompt = matchMenuKey:gsub("[%a%d]", "")
            segment.prompt = "〔" .. prompt .. "〕"
            second_menu_items = matchMenuItems["items"]
            for k, v in pairs(second_menu_items) do
                local item = type(k) == "number" and v or k
                local cand = Candidate("favor", seg.start, seg._end, item, "")
                cand.quality = 999
                yield(cand)
            end
            favor_items = app_command_items["Favors"]
            first_menu_selected_text = matchMenuKey
        end
    end

    if (first_menu_selected_text) and (second_menu_items)
        and input:match("^" .. favorCmdPrefix .. "$")
    then
        for k, v in pairs(second_menu_items) do
            local item = type(k) == "number" and v or k
            local cand = Candidate("favor", seg.start, seg._end, item, "")
            cand.quality = 999
            yield(cand)
        end
    end

    if (not segment.prompt:match("快捷指令")) and (second_menu_items)
        and (not second_menu_selected_text)
        and (input:match("^" .. favorCmdPrefix))
        and (#input >= (favorCmdPrefix:len() + 2))
    then
        local prompt = first_menu_selected_text and first_menu_selected_text:gsub("[%a%d]", "")
        segment.prompt = "〔" .. prompt .. "〕"
        for k, v in pairs(second_menu_items) do
            local item = type(k) == "number" and v or k
            if item:lower():match("^" .. input:sub(-1)) and (type(item) == "string") then
                second_menu_selected_text = item:gsub(" ", "")
            end
        end
        if second_menu_selected_text then
            local _text = second_menu_selected_text:gsub("[%d]", "")
            local cand = Candidate("favor", seg.start, seg._end, _text, "")
            cand.quality = 999
            yield(cand)
        else
            local cand = Candidate("unknown", seg.start, seg._end, "未匹配到二级菜单", "")
            cand.quality = 999
            yield(cand)
        end
    end

    if (type(favor_items) == "table") and (not second_menu_items)
        and input:match("^" .. favorCmdPrefix .. "$")
    then
        segment.prompt = "〔快捷指令〕"
        first_menu_selected_text = nil
        second_menu_items = nil
        for key, val in pairs(favor_items) do
            if type(key) == "number" and type(val) == "string" then
                local cand = Candidate("favor", seg.start, seg._end, val, "")
                cand.quality = 999
                yield(cand)
            else
                local cand = Candidate("favor", seg.start, seg._end, key, "")
                cand.quality = 999
                yield(cand)
            end
        end
    end
end

function filter.init(env)
    env.launcher_config = require("launcher_config")
    env.app_launch_prefix = env.launcher_config[1]
    env.favor_cmd_prefix = env.launcher_config[2]
    env.favor_items = env.launcher_config[3]["Favors"]
    env.system_name = detect_os()
end

function filter.func(input, env)
    local input_code = env.engine.context:get_commit_text():gsub(" ", "")
    local favorCmdPrefix = env.favor_cmd_prefix
    local appLaunchPrefix = env.app_launch_prefix
    local fav_items = env.favor_items
    local system_name = env.system_name
    local command_cands = {}
    local other_cands = {}
    for cand in input:iter() do
        if input_code:match("^" .. favorCmdPrefix) and cand.text:match("[1-9]$") then
            local pos = tostring(cand.text:sub(-1))
            command_cands[pos] = cand
        elseif input_code:match("^" .. appLaunchPrefix) and cand.comment:match("应用闪切") then
            yield(cand)
        else
            table.insert(other_cands, cand)
        end
    end

    if input_code:match("^" .. favorCmdPrefix) and (second_menu_selected_text) then
        local commitText = fav_items[first_menu_selected_text]["items"][second_menu_selected_text]
        local action = fav_items[first_menu_selected_text]["action"]
        if action == "open" then
            cmd(system_name, "", commitText)
        elseif action == "exec" then
            local cmdString = commitText:match("^/") and commitText:gsub(" ", "\\ ", 1) or commitText
            cmd(system_name, "exec", cmdString)
        else
            env.engine:commit_text(commitText)
        end
        env.engine.context:clear()
        favor_items = nil
        second_menu_items = nil
        first_menu_selected_text = nil
        second_menu_selected_text = nil
        return 1 -- kAccepted
    end

    if command_cands then
        -- 首先把表转换为数组,并按键值排序
        local sorted_keys = {}
        for k, _ in pairs(command_cands) do
            table.insert(sorted_keys, k)
        end
        table.sort(sorted_keys, function(a, b)
            return tonumber(a) < tonumber(b)
        end)

        -- 创建一个新表,按排序后的键值存储数据
        local sorted_command_cands = {}
        for i, k in ipairs(sorted_keys) do
            sorted_command_cands[i] = command_cands[k]
        end

        for _, cand in ipairs(sorted_command_cands) do
            local cand_text = cand.text:gsub("[1-9]$", "")
            yield(ShadowCandidate(cand, cand.type, cand_text))
        end
    end

    if other_cands then
        for _, cand in ipairs(other_cands) do
            yield(cand)
        end
    end
end

return {
    processor = { init = processor.init, func = processor.func },
    translator = { init = translator.init, func = translator.func },
    filter = { init = filter.init, func = filter.func },
}
