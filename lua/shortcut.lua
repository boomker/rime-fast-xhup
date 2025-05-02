local launcher = {}
local processor = {}
local translator = {}

require("lib/metatable")
require("lib/rime_helper")
local _ok_conf, shortcut_config = pcall(require, "shortcut_config")

local function cmd(system, cmdArgs, appId)
    if system:lower():match("macos") and (cmdArgs == "exec") then
        local osascript = appId
        os.execute(osascript)
    elseif system:lower():match("macos") then
        local osascript = "open " .. cmdArgs .. appId
        os.execute(osascript)
    elseif system:lower():match("windows") then
        local script = "start " .. "" .. appId
        os.execute(script)
    end
end

local function wrap_path(path_type, path)
    if path_type == "file" then
        return path:gsub(" ", "\\ "):gsub("~([%a]+)", "\\~%1")
    elseif path_type == "command" then
        return path:gsub(" ", "\\ ", 1):gsub("~([%a]+)", "\\~%1")
    end
end

local function get_app_obj(obj, obj_type)
    local key_idx_map = {
        ["name"] = 1,
        ["bundle_id"] = 2,
    }
    local res_tbl = {}
    local function recursive_get(obj_val)
        if (type(obj_val) == "table") and (#obj_val == 2) and (type(obj_val[1]) == "string") then
            if obj_type ~= "key_value" then
                table.insert(res_tbl, obj_val[key_idx_map[obj_type]])
            else
                res_tbl[obj_val[1]] = obj_val[2]
            end
        else
            for _, val in pairs(obj_val) do
                recursive_get(val)
            end
        end
    end
    recursive_get(obj)
    return res_tbl
end

local function reset_state()
    launcher["main_menu_keys"] = nil -- {}
    launcher["second_menu_keys"] = nil -- {}
    launcher["main_menu_orders"] = nil -- {}
    launcher["second_menu_orders"] = nil -- {}
    launcher["main_menu_selected"] = nil -- {}
    launcher["main_menu_selected_text"] = nil -- ""
    launcher["second_menu_selected_text"] = nil -- ""
end

local function action_handler(env, action, system_type, fact_item)
    local commit_history = env.engine.context.commit_history
    if ((action == "commit") or (system_type == "ios")) and fact_item then
        env.engine:commit_text(fact_item)
        commit_history:push("raw", fact_item)
    elseif (action == "open") and (system_type ~= "ios") and fact_item then
        if fact_item:match("^http") then
            cmd(system_type, "", fact_item)
        else
            local _path = fact_item
            local path = _path:match("[~ ]+") and wrap_path("file", _path) or _path
            cmd(system_type, "", path)
        end
    elseif (action == "exec") and (system_type ~= "ios") and fact_item then
        local _cmd_str = fact_item
        local cmd_string = _cmd_str:match("^/.*[~ ]+") and wrap_path("command", _cmd_str) or _cmd_str
        cmd(system_type, "exec", cmd_string)
    else
        env.engine:commit_text(fact_item)
        commit_history:push("raw", fact_item)
    end
end

-- 生成随机字符串的函数
local function generateRandomString(length)
    -- 设置随机种子
    math.randomseed(os.time())
    -- 定义字符集
    local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#^()_+-=[]{}|:,.<>?"
    local result = {}
    local charsetLength = #charset
    for i = 1, length do
        -- 随机选择一个字符
        local randIndex = math.random(charsetLength)
        result[i] = charset:sub(randIndex, randIndex)
    end
    -- 将表转换为字符串并返回
    return table.concat(result)
end

function launcher.init(env)
    local config = env.engine.schema.config
    local shortcuts_app_pat = config:get_string("recognizer/patterns/shortcuts_app") or nil
    local shortcuts_cmd_pat = config:get_string("recognizer/patterns/shortcuts_cmd") or nil
    env.system_name = detect_os()
    env.shortcut_config = _ok_conf and shortcut_config
    env._app_launch_prefix, env._favor_cmd_prefix, env.all_command_items = table.unpack(env.shortcut_config)
    env.favor_cmd_prefix = shortcuts_cmd_pat and shortcuts_cmd_pat:match("%^([a-zA-Z/]+).*") or env._favor_cmd_prefix
    env.app_launch_prefix = shortcuts_app_pat and shortcuts_app_pat:match("%^([a-zA-Z/]+).*") or env._app_launch_prefix
end

function processor.func(key, env)
    local engine = env.engine
    local key_value = key:repr()
    local context = engine.context
    local input_code = context.input
    local composition = context.composition
    local segment = composition:back()
    local page_size = engine.schema.page_size
    local system_name = env.system_name
    local favorcmd_prefix = env.favor_cmd_prefix
    local app_launch_prefix = env.app_launch_prefix
    local all_command_items = env.all_command_items

    -- check trigger conditions
    if
        not (
            input_code:match("^/j%l+")
            or input_code:match("^" .. favorcmd_prefix)
            or input_code:match("^" .. app_launch_prefix)
        ) or composition:empty()
    then
        return 2
    end

    if key_value == "Escape" then
        context:clear()
        reset_state()
        return 1 -- kAccepted 收下此key
    end
    if (key_value == "BackSpace") and (not segment.prompt:match("快捷指令")) then
        if (context.input == favorcmd_prefix) and launcher["main_menu_selected"] then
            reset_state()
            context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单
        elseif (context.input ~= favorcmd_prefix) and launcher["main_menu_selected"] then
            launcher["main_menu_selected"] = nil
            context:pop_input(1)
        elseif context.input ~= favorcmd_prefix then
            reset_state()
            context:pop_input(1)
            context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单
        else
            context:pop_input(1)
        end
        return 1 -- kAccepted 收下此key
    end
    if
        input_code:match("^" .. favorcmd_prefix)
        and key_value:match("^%a$")
        and not launcher["main_menu_selected_text"]
    then
        for idx, menu_name in ipairs(launcher["main_menu_orders"]) do
            if menu_name:lower():match("^" .. key_value) then
                engine:process_key(KeyEvent(tostring(idx)))
                return 1
            end
        end
    end
    if
        input_code:match("^" .. favorcmd_prefix)
        and key_value:match("^%a$")
        and not launcher["second_menu_selected_text"]
    then
        local index = 0
        local match_count = 0
        for idx, menu_name in ipairs(launcher["second_menu_orders"]) do
            if menu_name:lower():match("^" .. key_value) then
                match_count = match_count + 1
                index = idx
            end
        end
        if index > page_size then
            index = index - page_size
        end
        if match_count == 1 then
            launcher["second_menu_selected_text"] = "matched"
            engine:process_key(KeyEvent(tostring(index)))
            return 1
        end
    end

    local selected_index = segment.selected_index or -1
    local selected_cand_idx = get_selected_candidate_index(key_value, selected_index, page_size)
    if selected_cand_idx < 0 then return 2 end

    if input_code:match("^" .. favorcmd_prefix) then
        if (input_code == favorcmd_prefix) and segment.prompt:match("快捷指令") then
            local cand = segment:get_candidate_at(selected_cand_idx)
            local candidate_text = cand.text
            local prompt = candidate_text:gsub(" ", ""):gsub("[%a%p]", "")
            launcher["main_menu_selected_text"] = candidate_text:gsub(" ", "")
            context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单
            segment.prompt = "〔" .. prompt .. "〕"
            return 1
        end

        if (not segment.prompt:match("快捷指令")) and launcher["main_menu_selected"] then
            local candidate_text = segment:get_candidate_at(selected_cand_idx).text:gsub(" ", "")
            local idx = launcher["second_menu_keys"][candidate_text]
            local main_menu_obj = launcher["main_menu_selected"]
            local action = main_menu_obj and main_menu_obj["action"]
            local _second_menu_items = main_menu_obj and main_menu_obj["submenu_items"] or nil
            local second_menu_items = _second_menu_items or main_menu_obj and main_menu_obj["submenus"] or nil
            local second_menu_item = second_menu_items and second_menu_items[idx] or nil
            local selected_item_text = second_menu_item or candidate_text

            action_handler(env, action, system_name, selected_item_text)
            reset_state()
            context:clear()
            return 1 -- kAccepted 收下此key
        end
    end

    if input_code:match("^" .. app_launch_prefix) or input_code:match("^/j%l%l") then
        local app_bundle_id = nil
        local sys_name = env.system_name
        local candidate_text = segment:get_candidate_at(selected_cand_idx).text
        local selected_items = all_command_items[sys_name][input_code]
        if (not selected_items) and (input_code == app_launch_prefix) then
            selected_items = all_command_items[sys_name]
        end
        if (not selected_items) and (input_code:sub(1, app_launch_prefix:len()) == app_launch_prefix) then
            local app_trigger_key = "/j" .. input_code:gsub(app_launch_prefix, "", 1)
            selected_items = all_command_items[sys_name][app_trigger_key]
        end

        if selected_items then
            local app_name_id_tbl = get_app_obj(selected_items, "key_value")
            app_bundle_id = app_name_id_tbl[candidate_text]
        end

        if app_bundle_id and segment.prompt:match("应用闪切") then
            context:clear()
            cmd(sys_name, "-b ", app_bundle_id)
            return 1 -- kAccepted 收下此key
        else
            engine:commit_text(candidate_text)
            context:clear()
            return 1 -- kAccepted 收下此key
        end
    end

    return 2
end

function translator.func(input, seg, env)
    local context = env.engine.context
    local system_name = env.system_name
    local favorcmd_prefix = env.favor_cmd_prefix
    local app_launch_prefix = env.app_launch_prefix
    local all_command_items = env.all_command_items
    local composition = context.composition
    if composition:empty() then
        return
    end

    local segment = composition:back()
    local all_app_items = all_command_items[system_name] or nil
    local app_items = all_app_items and all_app_items[input]
    if (not app_items) and (input:sub(1, app_launch_prefix:len()) == app_launch_prefix) then
        local app_trigger_key = "/j" .. input:gsub(app_launch_prefix, "", 1)
        app_items = all_app_items and all_app_items[app_trigger_key]
    end
    if (not app_items) and (input == app_launch_prefix) then
        app_items = all_app_items
    end

    -- 应用闪切
    if app_items then
        local res_tbl = get_app_obj(app_items, "name")
        for _, value in ipairs(res_tbl) do
            segment.prompt = "〔应用闪切〕"
            local cand = Candidate("shortcut", seg.start, seg._end, value, "")
            cand.quality = 999
            yield(cand)
        end
        return
    end

    -- render main menu
    if
        input:match("^" .. favorcmd_prefix .. "$")
        and not launcher["main_menu_selected_text"]
        and not segment.prompt:match("快捷指令")
    then
        reset_state()
        segment.prompt = "〔快捷指令〕"

        launcher["main_menu_keys"] = {}
        launcher["main_menu_orders"] = {}
        local favor_menus = all_command_items["Favors"]
        for _, key in ipairs(table.sorted_keys(favor_menus)) do
            local submenu = favor_menus[key]
            local menu_name = submenu["menu_name"]:gsub(" ", "")
            launcher["main_menu_keys"][menu_name] = key
            table.insert(launcher["main_menu_orders"], menu_name)
            local cand = Candidate("favor", seg.start, seg._end, menu_name, "")
            cand.quality = 999
            yield(cand)
        end
        return
    end

    -- render unmatched second_menu_items
    if
        input:match("^" .. favorcmd_prefix)
        and (#input > favorcmd_prefix:len())
        and not launcher["main_menu_selected"]
        and not launcher["main_menu_selected_text"]
    then
        local match_count = 0
        local main_menu_items = launcher["main_menu_orders"]
        local main_menu_prefix = input:sub(favorcmd_prefix:len() + 1, -1)

        for _, key in ipairs(main_menu_items) do
            if key:lower():match("^" .. main_menu_prefix) then
                match_count = match_count + 1
            end
        end

        if match_count == 0 then
            local prompt = "Unknown"
            segment.prompt = "〔" .. prompt .. "〕"
            local cand = Candidate(prompt, seg.start, seg._end, "未匹配到一级菜单项", "")
            cand.quality = 999
            yield(cand)
        end
        return
    end

    if
        input:match("^" .. favorcmd_prefix)
        and launcher["main_menu_selected_text"]
        and not launcher["main_menu_selected"]
        and not launcher["second_menu_selected_text"]
        and not segment.prompt:match("快捷指令")
    then
        launcher["second_menu_keys"] = {}
        launcher["second_menu_orders"] = {}
        local prompt = launcher["main_menu_selected_text"]:gsub("[%a%p]", "")
        local main_menu_selected_text = launcher["main_menu_selected_text"]
        local index = launcher["main_menu_keys"][main_menu_selected_text]
        launcher["main_menu_selected"] = all_command_items["Favors"][index]
        local submenus = launcher["main_menu_selected"]["submenus"] or nil
        submenus = submenus or launcher["main_menu_selected"]["submenu_items"]
        segment.prompt = "〔" .. prompt .. "〕"
        for _, key in ipairs(table.sorted_keys(submenus)) do
            local sm_name = submenus[key]:gsub(" ", "")
            launcher["second_menu_keys"][sm_name] = key
            table.insert(launcher["second_menu_orders"], sm_name)
            local cand = Candidate("favor", seg.start, seg._end, sm_name, "")
            cand.quality = 999
            yield(cand)
        end
        if segment.prompt:match("密码") then
            local rpwd_submenu_itmes = launcher["main_menu_selected"]["submenus"]
            launcher["main_menu_selected"]["submenu_items"] = {}
            for _, key in ipairs(table.sorted_keys(rpwd_submenu_itmes)) do
                local val = rpwd_submenu_itmes[key]:match("%d+")
                local rpwd = generateRandomString(val)
                table.insert(launcher["main_menu_selected"]["submenu_items"], rpwd)
            end
        end
        return
    end

    -- get second_menu_selected_text
    if
        input:match("^" .. favorcmd_prefix)
        and launcher["main_menu_selected"]
        and not launcher["second_menu_selected_text"]
        and not segment.prompt:match("快捷指令")
    then
        local match_count = 0
        local submenus = launcher["main_menu_selected"]["submenus"]
        local prompt = launcher["main_menu_selected_text"]:gsub("[%a%p]", "")
        segment.prompt = "〔" .. prompt .. "〕"
        for _, key in ipairs(table.sorted_keys(submenus)) do
            local sm_name = submenus[key]
            if sm_name:lower():match("^" .. input:sub(-1)) then
                match_count = match_count + 1
                launcher["second_menu_selected_text"] = sm_name
            end
        end
        if match_count == 1 and launcher["second_menu_selected_text"] then
            local second_menu_selected_text = launcher["second_menu_selected_text"]
            local cand = Candidate("favor", seg.start, seg._end, second_menu_selected_text, "")
            cand.quality = 999
            yield(cand)
            return
        else
            prompt = "Unknown"
            segment.prompt = "〔" .. prompt .. "〕"
            local cand = Candidate(prompt, seg.start, seg._end, "未匹配到二级菜单项", "")
            cand.quality = 999
            yield(cand)
        end
    end
end

return {
    processor = {
        init = launcher.init,
        func = processor.func,
    },
    translator = {
        init = launcher.init,
        func = translator.func,
    },
}
