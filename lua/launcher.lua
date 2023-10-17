-- local puts = require("tools/debugtool")
local launcher = {}
local app_items = require("launcher_config")
local of_items = nil
local first_menu_text = nil

local function cmd(system, cmdArgs)
	if system:lower():match("darwin") then
		local osascript = "open " .. cmdArgs
		os.execute(osascript)
	elseif system:lower():match("windows") then
		local script = "start" .. "" .. cmdArgs
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

function launcher.processor(key, env)
	local engine = env.engine
	local context = engine.context
	local composition = context.composition
	local segment = composition:back()
	local input_code = context.input
	local preedit_code_length = #input_code
	local keyvalue = key:repr()

	local idx = -1
	local selected_candidate_index = (composition:empty() == false) and segment.selected_index or -1
	if keyvalue == "space" then
		idx = selected_candidate_index
	elseif keyvalue == "Return" and (input_code == "ofk") then
		idx = selected_candidate_index
	elseif keyvalue == "semicolon" then
		idx = 1
	elseif keyvalue == "apostrophe" then
		idx = 2
	end

	if keyvalue == "1" then
		idx = 0
	elseif string.find(keyvalue, "^[2-9]$") then
		idx = tonumber(keyvalue) - 1
	elseif keyvalue == "0" then
		idx = 9
	end

	local spec_keys = { ["Escape"] = true, ["BackSpace"] = true }

	if of_items and context:has_menu() and (input_code:match("^ofk")) then
		if spec_keys[keyvalue] and (preedit_code_length >= 4) then
			of_items = nil
            context:pop_input(1)
			context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
			return 1 -- kAccepted 收下此key
        elseif spec_keys[keyvalue] then
			of_items = nil
			context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
			return 1 -- kAccepted 收下此key
		elseif idx >= 0 then
			local sys = detect_os()
			local _candidateText = segment:get_candidate_at(idx).text
			local candidateText = _candidateText:gsub(' ', '')
			if candidateText:match("^http") then
				cmd(sys, candidateText)
				of_items = nil
				first_menu_text = nil
				context:clear()
				return 1 -- kAccepted 收下此key
			elseif first_menu_text and first_menu_text:match("目录位置") then
				local _path = app_items["Favor"][first_menu_text][candidateText]
                local path = _path:gsub(' ', '\\ ')
				cmd(sys, path)
				of_items = nil
				first_menu_text = nil
				context:clear()
				return 1 -- kAccepted 收下此key
			elseif first_menu_text and first_menu_text:match("卡号") then
				local card_text = app_items["Favor"][first_menu_text][candidateText]
				engine:commit_text(card_text)
				context:clear()
				of_items = nil
				first_menu_text = nil
				return 1 -- kAccepted 收下此key
			else
				engine:commit_text(candidateText)
				context:clear()
				of_items = nil
				first_menu_text = nil
				return 1 -- kAccepted 收下此key
			end
		end
	end

	if (not of_items) and (idx >= 0) and context:has_menu() and (input_code == "ofk") then
		local candidateText = segment:get_candidate_at(idx).text
		first_menu_text = candidateText:gsub(" ", "")
		local candidateComment = segment:get_candidate_at(idx).comment
		if first_menu_text and candidateComment:match("快捷指令") then
			of_items = app_items["Favor"][first_menu_text]
			context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
			return 1
		end
	end

	if context:has_menu() and (input_code:match("^jj")) then
		if (idx >= 0) and (preedit_code_length >= 4) then
			local sys = detect_os()
			local items = app_items[sys][input_code]

			local candidateText = segment:get_candidate_at(idx).text
			local candidateComment = segment:get_candidate_at(idx).comment
			local tgtId = nil
			if items and type(items[1]) == "table" then
				for _, val in pairs(items) do
					if val[1] == candidateText then
						tgtId = val[2]
					end
				end
			elseif items and type(items[1]) == "string" then
				tgtId = items[2]
			end

			if items and candidateText and candidateComment:match("快捷命令") then
				local commandArgs
				if tgtId then
					commandArgs = "-b " .. tgtId
				end
				context:clear()
				cmd(sys, commandArgs)
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

function launcher.translator(input, seg, env)
	local sys = detect_os()
	local items = app_items[sys][input]
	if items and type(items[1]) == "table" then
		for _, val in pairs(items) do
			local cand = Candidate("shortcut", seg.start, seg._end, val[1], "〔快捷命令〕")
			cand.quality = 999
			yield(cand)
		end
	elseif items and type(items[1]) == "string" then
		local cand = Candidate("shortcut", seg.start, seg._end, items[1], "〔快捷命令〕")
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
		for key, val in pairs(app_items["Favor"]) do
			if key:match(item_prefix) and (key:sub(1, 1) == item_prefix:sub(1, 1)) then
				for k, v in pairs(val) do
					local item = type(k) == "number" and v or k
					local cand = Candidate("favor", seg.start, seg._end, item, "")
					cand.quality = 999
					yield(cand)
				end
                of_items = app_items["Favor"]
                first_menu_text = key
			end
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

return launcher
