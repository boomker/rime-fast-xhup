-- local puts = require("tools/debugtool")
local launcher = {}
local app_items = require("launcher_config")
local of_items = nil

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
	local selected_candidate_index = (context:has_menu() or context:is_composing()) and segment.selected_index
	if keyvalue == "space" then
		idx = selected_candidate_index
	elseif keyvalue == "Return" and (input_code == "ofkc") then
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

	if of_items and (idx >= 0) and context:has_menu() and (input_code == "ofkc") then
		if keyvalue == "Escape" then
			of_items = nil
			return 1 -- kAccepted 收下此key
		end

		local sys = detect_os()
		local candidateText = segment:get_candidate_at(idx).text
		if candidateText:match("^http") then
			cmd(sys, candidateText)
			of_items = nil
			context:clear()
			return 1 -- kAccepted 收下此key
		else
			engine:commit_text(candidateText)
			context:clear()
			of_items = nil
			return 1 -- kAccepted 收下此key
		end
	end

	if (not of_items) and (idx >= 0) and context:has_menu() and (input_code == "ofkc") then
		local candidateText = segment:get_candidate_at(idx).text
		local candidateComment = segment:get_candidate_at(idx).comment
		if candidateText and candidateComment:match("快捷指令") then
			of_items = app_items["Favor"][candidateText]
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
				if
					candidateText:match("文件夹")
					or candidateText:match("链接")
					or candidateText:match("首页")
				then
					commandArgs = tgtId
				else
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

	if (not of_items) and input:match("^ofkc") then
		for key, _ in pairs(app_items["Favor"]) do
			local cand = Candidate("favor", seg.start, seg._end, key, "〔快捷指令〕")
			cand.quality = 999
			yield(cand)
		end
	end

	if of_items and input:match("^ofkc") then
		for _, val in pairs(of_items) do
			local cand = Candidate("favor", seg.start, seg._end, val, "")
			cand.quality = 999
			yield(cand)
		end
	end
end

return launcher
