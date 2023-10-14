-- local puts = require("tools/debugtool")
local launcher = {}
local app_items = require("launcher_config")
local of_items = nil

local function cmd(order)
	local osascript = order
	os.execute(osascript)
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

    local selected_candidate_keyval_tbl = {
        ["Escape"] = true,
        ["Enter"] = "x",
        ["Return"] = "x",
        ["space"] = "x",
        ["semicolon"] = 1,
        ["apostrophe"] = 2,
        ["1"] = 0,
        ["2"] = 1,
        ["3"] = 2,
        ["4"] = 3,
        ["5"] = 4,
        ["6"] = 5,
        ["7"] = 6,
        ["8"] = 7,
        ["9"] = 8,
    }

    if of_items and (input_code == "ofkc") and (selected_candidate_keyval_tbl[keyvalue]) then
        if keyvalue == "Escape" then
            of_items = nil
            return 1 -- kAccepted 收下此key
        end

		local selected_candidate_index = segment.selected_index
        local index = selected_candidate_keyval_tbl[keyvalue]
        local idx = index=="x" and selected_candidate_index or index
        local candidateText = segment:get_candidate_at(idx).text
        if candidateText:match('^http') then
            local command = "open " .. candidateText
            cmd(command)
            of_items = nil
            context:clear()
            return 1 -- kAccepted 收下此key
        end
        of_items = nil
        return 1 -- kAccepted 收下此key
    end

	if context:has_menu() or context:is_composing() then
		local idx = -1
		local selected_candidate_index = segment.selected_index
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

		local sys = detect_os()
		local items = app_items[sys][input_code]

		local cmd_prefix = string.sub(input_code, 1, 2)
		if (preedit_code_length >= 4) and (idx >= 0) and (cmd_prefix == "jj") then
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

			if items and candidateText and candidateComment:match("快捷命令") and sys:match("Darwin") then
				local command
				if
					candidateText:match("文件夹")
					or candidateText:match("链接")
					or candidateText:match("首页")
				then
					command = "open " .. tgtId
				else
					command = "open -b " .. tgtId
				end
				context:clear()
				cmd(command)
				return 1 -- kAccepted 收下此key
			elseif items and candidateText and candidateComment:match("快捷命令") and sys:match("Windows") then
				local command = "start " .. tgtId
				context:clear()
				cmd(command)
				return 1 -- kAccepted 收下此key
			else
				engine:commit_text(candidateText)
				context:clear()
				return 1 -- kAccepted 收下此key
			end
		end

        if (not of_items) and (preedit_code_length == 4) and (idx >= 0) and (cmd_prefix == "of") then
			local candidateText = segment:get_candidate_at(idx).text
			local candidateComment = segment:get_candidate_at(idx).comment
			if candidateText and candidateComment:match("快捷指令") then
                of_items = app_items["Favor"][candidateText]
                context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
	            return 1
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

    if (not of_items) and input:match('^ofkc') then
        for key, _ in pairs(app_items["Favor"]) do
			local cand = Candidate("favor", seg.start, seg._end, key, "〔快捷指令〕")
			cand.quality = 999
			yield(cand)
        end
    end

    if of_items and input:match('^ofkc') then
        for _, val in pairs(of_items) do
			local cand = Candidate("favor", seg.start, seg._end, val, "")
			cand.quality = 999
			yield(cand)
        end
    end
end

return launcher
