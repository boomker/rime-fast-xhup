-- 为交替输出中英情况加空格
-- 为中英混输词条（cn_en.dict.yaml）自动空格
-- 示例：`VIP中P` → `VIP 中 P`

-- local puts = require("tools/debugtool")
local function reset_cand_property(env)
	local context = env.engine.context
	context:set_property("prev_cand_is_null", "0")
	context:set_property("prev_cand_is_aword", "0")
	context:set_property("prev_cand_is_hanzi", "0")
	context:set_property("prev_cand_is_preedit", "0")
end

local function auto_append_space_processor(key, env)
	local engine = env.engine
	local context = engine.context
	local input_code = context.input
	local pos = context.caret_pos
	local composition = context.composition
	-- local cand_text   = context:get_commit_text()

	local cand_select_kyes = {
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
		["10"] = 9,
	}

	local spec_keys = {
		-- ['equal'] = true,
		["apostrophe"] = true,
		["grave"] = true,
		["minus"] = true,
		["slash"] = true,
		["Shift+at"] = true,
		["Shift+plus"] = true,
		["Shift+dollar"] = true,
		["Shift+quotedbl"] = true,
		["Shift+asterisk"] = true,
		["Shift+underscore"] = true,
		["Shift+parenleft"] = true,
		["Shift+parenright"] = true,
		["Return"] = true,
		["Control+Return"] = true,
		["Alt+Return"] = true,
	}

	local prev_cand_is_nullv = context:get_property("prev_cand_is_null")
	local prev_cand_is_hanziv = context:get_property("prev_cand_is_hanzi")
	local prev_cand_is_awordv = context:get_property("prev_cand_is_aword")
	local prev_cand_is_preeditv = context:get_property("prev_cand_is_preedit")

	if (#input_code == 0) and spec_keys[key:repr()] then
		reset_cand_property(env)
		context:set_property("prev_cand_is_null", "1")
	end

	if (#input_code >= 1) and (key:repr() == "Return") then
		local cand_text = input_code
		if (prev_cand_is_nullv ~= "1") and ((prev_cand_is_hanziv == "1") or (prev_cand_is_awordv == "1")) then
			cand_text = " " .. input_code
			engine:commit_text(cand_text)
		else
			engine:commit_text(cand_text)
		end
		context:set_property("prev_cand_is_preedit", "1")
		context:clear()
		return 1 -- kAccepted
	end

	if cand_select_kyes[key:repr()] and (#input_code >= 1) then
		local cand_text = context:get_commit_text()

		local _idx = cand_select_kyes[key:repr()]
		if not composition:empty() then
			local segment = composition:back()
			local selected_cand_idx = _idx == "x" and segment.selected_index or _idx
			local candObj = segment:get_candidate_at(selected_cand_idx)
			if not candObj then
				return 2
			end
			cand_text = candObj.text
		end

		if (prev_cand_is_nullv ~= "1") and ((prev_cand_is_preeditv == "1") or (prev_cand_is_awordv == "1")) then
			if (tonumber(utf8.codepoint(cand_text, 1)) >= 19968) and (#input_code == pos) then
				local ccand_text = " " .. cand_text
				engine:commit_text(ccand_text)
				reset_cand_property(env)
				context:set_property("prev_cand_is_hanzi", "1")
				context:clear()
				return 1 -- kAccepted
			elseif string.match(cand_text, "^[%l%u]+") then
				local ccand_text = " " .. cand_text
				engine:commit_text(ccand_text)
				reset_cand_property(env)
				context:set_property("prev_cand_is_aword", "1")
				context:clear()
				return 1 -- kAccepted
			else
				context:confirm_previous_selection()
			end
			return 2 -- kAccepted
		end

		if tonumber(utf8.codepoint(cand_text, 1)) >= 19968 then
			reset_cand_property(env)
			context:set_property("prev_cand_is_hanzi", "1")
			context:confirm_previous_selection()
		end

		if string.match(cand_text, "^[%l%u]+") then
			if (prev_cand_is_nullv ~= "1") and ((prev_cand_is_hanziv == "1") or (prev_cand_is_awordv == "1")) then
				local ccand_text = " " .. cand_text
				engine:commit_text(ccand_text)
				context:set_property("prev_cand_is_aword", "1")
				context:clear()
				return 1 -- kAccepted
			elseif (prev_cand_is_nullv == "1") or (prev_cand_is_hanziv ~= "1") then
				engine:commit_text(cand_text)
				context:set_property("prev_cand_is_aword", "1")
				context:set_property("prev_cand_is_null", "0")
				context:clear()
				return 1 -- kAccepted
			else
				context:set_property("prev_cand_is_aword", "1")
			end
		end
	end
	return 2 -- kNoop
end

local function add_spaces(s)
	-- 在中文字符后和英文字符前插入空格
	s = s:gsub("([\228-\233][\128-\191]-)([%w%p])", "%1 %2")
	-- 在英文字符后和中文字符前插入空格
	s = s:gsub("([%w%p])([\228-\233][\128-\191]-)", "%1 %2")
	return s
end

-- 是否同时包含中文和英文数字
local function is_mixed_cn_en_num(s)
	return s:find("([\228-\233][\128-\191]-)") and s:find("[%a]")
end

---@diagnostic disable-next-line: unused-local
local function cn_en_spacer(input, env)
	for cand in input:iter() do
		if is_mixed_cn_en_num(cand.text) then
			cand = cand:to_shadow_candidate(cand.type, add_spaces(cand.text), cand.comment)
		end
		yield(cand)
	end
end

return { processor = auto_append_space_processor, filter = cn_en_spacer }
