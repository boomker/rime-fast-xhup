local filter = {}
local processor = {}
local translator = {}
local favor_items = nil
local second_menu_items = nil
local first_menu_selected_text = nil
local second_menu_selected_text = nil
require("tools/metatable")
local reload_env = require("tools/env_api")
local rime_api_helper = require("tools/rime_api_helper")
-- local logger = require("tools/logger")

local function cmd(system, cmdArgs, appId)
    if system:lower():match("macos") and (cmdArgs == "exec") then
        local osascript = appId
        os.execute(osascript)
        -- elseif system:lower():match("ios") and (cmdArgs == "exec") then
        --     local osascript = appId
        --     os.execute(osascript)
    elseif system:lower():match("macos") then
        local osascript = "open " .. cmdArgs .. appId
        os.execute(osascript)
        -- elseif system:lower():match("ios") then
        -- local osascript = "open " .. cmdArgs .. appId
        -- os.execute(osascript)
    elseif system:lower():match("windows") then
        local script = "start " .. "" .. appId
        os.execute(script)
    end
end

function processor.init(env)
    reload_env(env)
    env.launcher_config = require("launcher_config")
    env.app_launch_prefix = env.launcher_config[1]
    env.favor_cmd_prefix = env.launcher_config[2]
    env.all_command_items = env.launcher_config[3]
    env.system_name = rime_api_helper.detect_os()
    env.filters = env:Config_get("engine/filters")
    env.spacer_filter = "lua_filter@*word_append_space*filter"
end

function processor.func(key, env)
    local engine = env.engine
    local system_name = env.system_name:lower()
    local favorCmdPrefix = env.favor_cmd_prefix
    local appLaunchPrefix = env.app_launch_prefix
    local allCommandItems = env.all_command_items
    local context = engine.context
    local page_size = engine.schema.page_size
    local composition = context.composition
    local inputCode = context.input
    local preeditCodeLength = #inputCode
    local keyValue = key:repr()
    local segment = composition:back()

    if
        not (
            inputCode:match("^" .. favorCmdPrefix)
            or inputCode:match("^" .. appLaunchPrefix)
            or inputCode:match("^/j%l+")
        ) or composition:empty()
    then
        return 2
    end

    local spec_keys = { ["Escape"] = true, ["BackSpace"] = true }

    if spec_keys[keyValue] then
        if (keyValue == "BackSpace")
            and (inputCode == env.favor_cmd_prefix)
            and (not segment.prompt:match("快捷指令"))
        then
            second_menu_items = nil
            first_menu_selected_text = nil
            second_menu_selected_text = nil
            context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
            return 1                                    -- kAccepted 收下此key
        elseif (keyValue == "BackSpace") then
            context:pop_input(1)
        else
            context:clear()
        end
        favor_items = nil
        second_menu_items = nil
        first_menu_selected_text = nil
        second_menu_selected_text = nil
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1                                    -- kAccepted 收下此key
    end

    local selected_index = segment.selected_index or -1
    local selected_cand_idx = rime_api_helper.get_selected_candidate_index(keyValue, selected_index, page_size)
    if (selected_cand_idx < 0) then return 2 end

    if (inputCode:match("^" .. favorCmdPrefix)) then
        if (selected_cand_idx >= 0) and (inputCode == favorCmdPrefix) and segment.prompt:match("快捷指令") then
            local cand = segment:get_candidate_at(selected_cand_idx)
            local candidateText = cand.text
            first_menu_selected_text = candidateText:gsub(" ", "") .. tostring(selected_cand_idx + 1)
            local prompt = first_menu_selected_text:gsub("[%a%d]", "")
            if first_menu_selected_text then
                second_menu_items = allCommandItems["Favors"][first_menu_selected_text]["items"]
                context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
                segment.prompt = "〔" .. prompt .. "〕"
                return 1
            end
        end

        if selected_cand_idx >= 0 then
            local candidateText = segment:get_candidate_at(selected_cand_idx).text
            if table.find_index(env.filters, env.spacer_filter) then
                candidateText = candidateText:gsub(" ", "")
            end
            local action = allCommandItems["Favors"][first_menu_selected_text]["action"]
            local items = allCommandItems["Favors"][first_menu_selected_text]["items"]
            if type(items[1]) ~= "string" then
                candidateText = candidateText .. tostring(selected_cand_idx + 1)
            end
            if second_menu_selected_text then
                candidateText = second_menu_selected_text
            end

            if (action == "commit") and type(items[1]) ~= "string" then
                local commitText = allCommandItems["Favors"][first_menu_selected_text]["items"][candidateText]
                engine:commit_text(commitText)
            elseif action == "open" and type(items[1]) == "string" and (system_name ~= "ios") then
                cmd(system_name, "", candidateText)
            elseif (action == "open") and (system_name ~= "ios") then
                local _path = allCommandItems["Favors"][first_menu_selected_text]["items"][candidateText]
                local path = _path:gsub(" ", "\\ ")
                cmd(system_name, "", path)
            elseif (action == "exec") and (system_name ~= "ios") then
                local _cmdString = allCommandItems["Favors"][first_menu_selected_text]["items"][candidateText]
                local cmdString = _cmdString:match("^/") and _cmdString:gsub(" ", "\\ ", 1) or _cmdString
                cmd(system_name, "exec", cmdString)
            elseif (system_name == "ios") and type(items[1]) ~= "string" then
                local commitText = allCommandItems["Favors"][first_menu_selected_text]["items"][candidateText]
                engine:commit_text(commitText)
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

    if (preeditCodeLength >= appLaunchPrefix:len())
        and (inputCode:match("^" .. appLaunchPrefix) or inputCode:match("^/j"))
    then
        local sys_name = env.system_name
        local selected_items = allCommandItems[sys_name][inputCode]
        if (appLaunchPrefix ~= "/j") and (inputCode:sub(1, appLaunchPrefix:len()) == appLaunchPrefix) then
            local appTriggerKey = "/j" .. inputCode:gsub(appLaunchPrefix, "", 1)
            selected_items = allCommandItems[sys_name][appTriggerKey]
        end

        if not selected_items then
            selected_items = allCommandItems[sys_name]
        end

        local appId = nil
        -- local candidateText = nil
        local candidateText = segment:get_candidate_at(selected_cand_idx).text
        if selected_items and table.len(selected_items) > 2 then
            for _, val in pairs(selected_items) do
                if val[1] == candidateText then appId = val[2] end
            end
        elseif type(selected_items[1]) == "table" then
            for _, v in pairs(selected_items) do
                if v[1] == candidateText then
                    appId = v[2]
                end
            end
        elseif selected_items and (selected_items[1] == candidateText) then
            appId = selected_items[2]
        end

        if appId and segment.prompt:match("应用闪切") then
            context:clear()
            cmd(sys_name, "-b ", appId)
            return 1 -- kAccepted 收下此key
        else
            engine:commit_text(candidateText)
            context:clear()
            return 1 -- kAccepted 收下此key
        end
    end

    return 2
end

-- function processor.fini(env)
--     env.notifier_commit_launcher:disconnect()
-- end

function translator.init(env)
    env.launcher_config = require("launcher_config")
    env.app_launch_prefix = env.launcher_config[1]
    env.favor_cmd_prefix = env.launcher_config[2]
    env.all_command_items = env.launcher_config[3]
    env.system_name = rime_api_helper.detect_os()
end

function translator.func(input, seg, env)
    local composition = env.engine.context.composition
    local allCommandItems = env.all_command_items
    local appLaunchPrefix = env.app_launch_prefix
    local favorCmdPrefix = env.favor_cmd_prefix
    local system_name = env.system_name
    local all_app_items = allCommandItems[system_name] or nil
    local app_items = all_app_items and all_app_items[input] or nil

    if (appLaunchPrefix ~= "/j") and (input:sub(1, appLaunchPrefix:len()) == appLaunchPrefix) then
        local appTriggerKey = "/j" .. input:gsub(appLaunchPrefix, "", 1)
        app_items = all_app_items and all_app_items[appTriggerKey]
    end

    if composition:empty() then return end
    local segment = composition:back()

    if app_items and type(app_items[1]) == "table" then
        segment.prompt = "〔应用闪切〕"
        for _, val in pairs(app_items) do
            local cand = Candidate("shortcut", seg.start, seg._end, val[1], "")
            cand.quality = 999
            yield(cand)
        end
    elseif app_items and type(app_items[1]) == "string" then
        segment.prompt = "〔应用闪切〕"
        local cand = Candidate("shortcut", seg.start, seg._end, app_items[1], "")
        cand.quality = 999
        yield(cand)
    elseif input:match("^" .. appLaunchPrefix) then
        if not all_app_items then return end
        segment.prompt = "〔应用闪切〕"
        for _, val in pairs(all_app_items) do
            if type(val[1]) == "string" then
                local cand = Candidate("shortcut", seg.start, seg._end, val[1], "")
                cand.quality = 999
                yield(cand)
            else
                for _, v in pairs(val) do
                    local cand = Candidate("shortcut", seg.start, seg._end, v[1], "")
                    cand.quality = 999
                    yield(cand)
                end
            end
        end
    end

    if
        input:match("^" .. favorCmdPrefix .. "$") and not (
            favor_items or second_menu_items or first_menu_selected_text
        ) and not segment.prompt:match("快捷指令")
    then
        second_menu_items = nil
        first_menu_selected_text = nil
        segment.prompt = "〔快捷指令〕"

        for key, _ in pairs(allCommandItems["Favors"]) do
            local cand = Candidate("favor", seg.start, seg._end, key, "")
            cand.quality = 999
            yield(cand)
        end
        favor_items = allCommandItems["Favors"]
    end

    if
        input:match("^" .. favorCmdPrefix)
        and (#input > favorCmdPrefix:len())
        and not first_menu_selected_text
        and not second_menu_items
    then
        local first_menu_prefix = input:sub(favorCmdPrefix:len() + 1, -1)
        local matchCount = 0
        local matchMenuKey = ""
        local matchMenuItems = nil
        for key, val in pairs(allCommandItems["Favors"]) do
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
            favor_items = allCommandItems["Favors"]
            first_menu_selected_text = matchMenuKey
        else
            local cand = Candidate("unknown", seg.start, seg._end, "未匹配到一级菜单", "")
            cand.quality = 999
            yield(cand)
        end
    end

    if first_menu_selected_text and second_menu_items
        and input:match("^" .. favorCmdPrefix .. "$")
    then
        for k, v in pairs(second_menu_items) do
            local item = type(k) == "number" and v or k
            local cand = Candidate("favor", seg.start, seg._end, item, "")
            cand.quality = 999
            yield(cand)
        end
    end

    if
        second_menu_items
        and not second_menu_selected_text
        and (input:match("^" .. favorCmdPrefix))
        and (#input >= (favorCmdPrefix:len() + 2))
        and not segment.prompt:match("快捷指令")
    then
        local prompt = first_menu_selected_text and first_menu_selected_text:gsub("[%a%d]", "")
        segment.prompt = "〔" .. prompt .. "〕"
        for k, v in pairs(second_menu_items) do
            local item = type(k) == "number" and v or k
            if item:lower():match("^" .. input:sub(-1)) and (type(item) == "string") then
                second_menu_selected_text = item
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
    env.system_name = rime_api_helper.detect_os()
end

function filter.func(input, env)
    local context = env.engine.context
    local input_code = context.input:gsub(" ", "")
    local favorCmdPrefix = env.favor_cmd_prefix
    local appLaunchPrefix = env.app_launch_prefix
    local fav_items = env.favor_items
    local system_name = env.system_name
    local command_cands = {}
    local other_cands = {}
    for cand in input:iter() do
        if input_code:match("^" .. favorCmdPrefix) and cand.text:match("[0-9]+$") then
            local pos = tostring(cand.text:sub(-2):match("[0-9]+$"))
            command_cands[pos] = cand
        elseif input_code:match("^" .. appLaunchPrefix) then
            yield(cand)
        else
            table.insert(other_cands, cand)
        end
    end

    if input_code:match("^" .. favorCmdPrefix) and second_menu_selected_text then
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
            local cand_text = cand.text:gsub("[0-9]+$", "")
            ---@diagnostic disable-next-line: missing-parameter
            yield(ShadowCandidate(cand, cand.type, cand_text, ""))
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
