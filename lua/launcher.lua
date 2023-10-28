-- local puts = require("tools/debugtool")
local processor = {}
local translator = {}
local of_items = nil
local first_menu_text = nil

local function cmd(system, cmdArgs, objId)
	if system:lower():match("darwin") and (cmdArgs == "exec") then
		local osascript = objId
		os.execute(osascript)
	elseif system:lower():match("darwin") then
		local osascript = "open " .. cmdArgs .. objId
		os.execute(osascript)
	elseif system:lower():match("windows") then
		local script = "start " .. "" .. objId
		os.execute(script)
	end
end

local function detect_os()
	local user_distribute_name = rime_api:get_distribution_code_name()
	if user_distribute_name:lower():match("weasel") then
		return "Windows"
	end
	local system = io.popen("uname -s"):read("*l")
	return system
end

function processor.init(env)
	env.launcher_config = require("launcher_config")
	env.app_launch_prefix = env.launcher_config[1]
	env.app_items = env.launcher_config[2]
	env.sysType = detect_os()
end

function processor.func(key, env)
	local engine = env.engine
	local app_items = env.app_items
	local appLaunchPrefix = env.app_launch_prefix
	local sys = env.sysType
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
	elseif keyValue == "Return" and (inputCode == "ofk") then
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

	if of_items and context:has_menu() and (inputCode:match("^ofk")) then
		if spec_keys[keyValue] and (preeditCodeLength >= 4) then
			of_items = nil
			context:pop_input(1)
			context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
			return 1 -- kAccepted 收下此key
		elseif spec_keys[keyValue] then
			of_items = nil
			context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
			return 1 -- kAccepted 收下此key
		elseif idx >= 0 then
			local _candidateText = segment:get_candidate_at(idx).text
			local candidateText = _candidateText:gsub(" ", "")

			local action = app_items["Favor"][first_menu_text]["action"]
			local items = app_items["Favor"][first_menu_text]["items"]
			if (action == "commit") and not items[1] then
				local commitText = app_items["Favor"][first_menu_text]["items"][candidateText]
				engine:commit_text(commitText)
			elseif (action == "open") and (items[1] == nil) then
				local _path = app_items["Favor"][first_menu_text]["items"][candidateText]
				local path = _path:gsub(" ", "\\ ")
				cmd(sys, "", path)
			elseif action == "open" and type(items[1]) == "string" then
				cmd(sys, "", candidateText)
			elseif action == "exec" and (items[1] == nil) then
				local cmdString = app_items["Favor"][first_menu_text]["items"][candidateText]
				cmd(sys, "exec", cmdString)
			else
				engine:commit_text(candidateText)
			end

			context:clear()
			of_items = nil
			first_menu_text = nil
			return 1 -- kAccepted 收下此key
		end
	end

	if (not of_items) and (idx >= 0) and context:has_menu() and (inputCode == "ofk") then
		local candidateText = segment:get_candidate_at(idx).text
		first_menu_text = candidateText:gsub(" ", "")
		local candidateComment = segment:get_candidate_at(idx).comment
		if first_menu_text and candidateComment:match("快捷指令") then
			of_items = app_items["Favor"][first_menu_text]["items"]
			context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
			return 1
		end
	end

	if context:has_menu() and (inputCode:match("^" .. appLaunchPrefix) or inputCode:match("^jj")) then
		if (idx >= 0) and (preeditCodeLength > appLaunchPrefix:len() + 1) then
			local items = app_items[sys][inputCode]
			if appLaunchPrefix ~= "jj" and inputCode:sub(1, appLaunchPrefix:len()) == appLaunchPrefix then
				local appTriggerKey = "jj" .. inputCode:gsub(appLaunchPrefix, "", 1)
				items = app_items[sys][appTriggerKey]
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
				cmd(sys, "-b ", appId)
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
	env.app_items = env.launcher_config[2]
	env.sysType = detect_os()
end

function translator.func(input, seg, env)
	local app_items = env.app_items
	local appLaunchPrefix = env.app_launch_prefix
	local sys = env.sysType
	local items = app_items[sys][input]
	if appLaunchPrefix ~= "jj" and input:sub(1, appLaunchPrefix:len()) == appLaunchPrefix then
		local appTriggerKey = "jj" .. input:gsub(appLaunchPrefix, "", 1)
		items = app_items[sys][appTriggerKey]
	end

	if items and type(items[1]) == "table" then
		for _, val in pairs(items) do
			local cand = Candidate("shortcut", seg.start, seg._end, val[1], "〔应用闪切〕")
			cand.quality = 999
			yield(cand)
		end
	elseif items and type(items[1]) == "string" then
		local cand = Candidate("shortcut", seg.start, seg._end, items[1], "〔应用闪切〕")
		cand.quality = 999
		yield(cand)
	end

	if (not of_items) and input:match("^ofk$") then
		for key, _ in pairs(app_items["Favor"]) do
			local cand = Candidate("favor", seg.start, seg._end, key, "〔快捷指令〕")
			cand.quality = 999
			yield(cand)
		end
	end

	if (not of_items) and input:match("^ofk") and (#input >= 4) then
		local item_prefix = input:sub(4)
		local matchCount = 0
		local matchMenuKey = ""
		local matchMenuItems = nil
		for key, val in pairs(app_items["Favor"]) do
			if key:match("^" .. item_prefix) then
				matchCount = matchCount + 1
				matchMenuKey = key
				matchMenuItems = val
			end
		end

		if matchCount == 1 and matchMenuItems then
			for k, v in pairs(matchMenuItems["items"]) do
				local item = type(k) == "number" and v or k
				local cand = Candidate("favor", seg.start, seg._end, item, "")
				cand.quality = 999
				yield(cand)
			end
			of_items = app_items["Favor"]
			first_menu_text = matchMenuKey
		end
	end

	if type(of_items) == "table" and input:match("^ofk$") then
		for key, val in pairs(of_items) do
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

return {
	processor = { init = processor.init, func = processor.func },
	translator = { init = translator.init, func = translator.func },
}
