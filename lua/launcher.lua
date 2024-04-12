local processor = {}
local translator = {}
local filter = {}
local favor_items = nil
local first_menu_text = nil
-- local second_menu_items = nil

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
	local selected_candidate_index = (composition:empty() == false) and segment.selected_index or -1
	if keyValue == "space" then
		idx = selected_candidate_index
	elseif keyValue == "Return" and (inputCode == favorCmdPrefix) then
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

	if favor_items and context:has_menu() and (inputCode:match("^" .. favorCmdPrefix)) then
		if spec_keys[keyValue] and (preeditCodeLength >= string.len(favorCmdPrefix) + 1) then
			favor_items = nil
			context:pop_input(1)
			context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
			return 1 -- kAccepted 收下此key
		elseif spec_keys[keyValue] then
			favor_items = nil
			context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
			return 1 -- kAccepted 收下此key
		elseif idx >= 0 then
			local _candidateText = segment:get_candidate_at(idx).text
			local candidateText = _candidateText:gsub(" ", "")

			local action = app_command_items["Favors"][first_menu_text]["action"]
			local items = app_command_items["Favors"][first_menu_text]["items"]
			if (action == "commit") and not items[1] then
				local commitText = app_command_items["Favors"][first_menu_text]["items"][candidateText]
				engine:commit_text(commitText)
			elseif (action == "open") and (items[1] == nil) then
				local _path = app_command_items["Favors"][first_menu_text]["items"][candidateText]
				local path = _path:gsub(" ", "\\ ")
				cmd(system_name, "", path)
			elseif action == "open" and type(items[1]) == "string" then
				cmd(system_name, "", candidateText)
			elseif action == "exec" and (items[1] == nil) then
				local _cmdString = app_command_items["Favors"][first_menu_text]["items"][candidateText]
				local cmdString
				if _cmdString and _cmdString:match("^/") then
					cmdString = _cmdString:gsub(" ", "\\ ", 1)
				else
					cmdString = _cmdString
				end
				cmd(system_name, "exec", cmdString)
			else
				engine:commit_text(candidateText)
			end

			context:clear()
			favor_items = nil
			first_menu_text = nil
			return 1 -- kAccepted 收下此key
		end
	end

	if (not favor_items) and (idx >= 0) and context:has_menu() and (inputCode == favorCmdPrefix) then
		local candidateText = segment:get_candidate_at(idx).text
		first_menu_text = candidateText:gsub(" ", "") .. tostring(idx + 1)
		local candidateComment = segment:get_candidate_at(idx).comment
		if first_menu_text and candidateComment:match("快捷指令") then
			favor_items = app_command_items["Favors"][first_menu_text]["items"]
			context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
			return 1
		end
	end

	if context:has_menu() and (inputCode:match("^" .. appLaunchPrefix) or inputCode:match("^jj")) then
		if (idx >= 0) and (preeditCodeLength > appLaunchPrefix:len() + 1) then
			local items = app_command_items[system_name][inputCode]
			if appLaunchPrefix ~= "jj" and inputCode:sub(1, appLaunchPrefix:len()) == appLaunchPrefix then
				local appTriggerKey = "jj" .. inputCode:gsub(appLaunchPrefix, "", 1)
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
	local app_command_items = env.app_command_items
	local appLaunchPrefix = env.app_launch_prefix
	local favorCmdPrefix = env.favor_cmd_prefix
	local system_name = env.system_name
	local app_items = app_command_items[system_name][input]

	if appLaunchPrefix ~= "jj" and input:sub(1, appLaunchPrefix:len()) == appLaunchPrefix then
		local appTriggerKey = "jj" .. input:gsub(appLaunchPrefix, "", 1)
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

	if (not favor_items) and input:match("^" .. favorCmdPrefix .. "$") then
		for key, _ in pairs(app_command_items["Favors"]) do
			local cand = Candidate("favor", seg.start, seg._end, key, "〔快捷指令〕")
			cand.quality = 999
			yield(cand)
		end
	end

	local favor_cmd_length_range = string.len(favorCmdPrefix) + 1 .. string.len(favorCmdPrefix) + 2
	if (not favor_items) and input:match("^" .. favorCmdPrefix) and (favor_cmd_length_range:match(#input)) then
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
			local second_menu_items = matchMenuItems["items"]
			for k, v in pairs(second_menu_items) do
				local item = type(k) == "number" and v or k
				local cand = Candidate("favor", seg.start, seg._end, item, "")
				cand.quality = 999
				yield(cand)
			end
			favor_items = app_command_items["Favors"]
			first_menu_text = matchMenuKey
		end
	end

	if type(favor_items) == "table" and input:match("^" .. favorCmdPrefix .. "$") then
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
	env.favor_cmd_prefix = env.launcher_config[2]
	env.favor_items = env.launcher_config[3]["Favors"]
end

function filter.func(input, env)
	local input_code = env.engine.context:get_commit_text()
	local command_cands = {}
	for cand in input:iter() do
		if input_code:match("^" .. env.favor_cmd_prefix .. "$") then
			if cand.text:match("[1-9]$") then
				local pos = tostring(cand.text:sub(-1))
				command_cands[pos] = cand
			else
				yield(cand)
			end
		else
			yield(cand)
		end
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
			yield(ShadowCandidate(cand, cand.type, cand_text, cand.comment))
		end
	end
end

return {
	processor = { init = processor.init, func = processor.func },
	translator = { init = translator.init, func = translator.func },
	filter = { init = filter.init, func = filter.func },
}
