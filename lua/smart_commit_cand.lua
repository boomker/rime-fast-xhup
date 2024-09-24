local rime_api_helper = require("tools/rime_api_helper")
-- local logger = require('tools/logger')

local P = {}
-- local kReject = 0
local kAccepted = 1
local kNoop = 2

function P.init(env)
	env.prev_input_code = nil
	env.prev_menu_cand_count = 0
end

function P.func(key_event, env)
	local whether_process = false
	if key_event:repr() == "apostrophe" then
		whether_process = true
	end
	if (key_event:repr() == "period") or (key_event:repr() == "Next") then
		whether_process = true
	end
	if not whether_process then
		return kNoop
	end

	local context = env.engine.context
	local composition = context.composition
	if composition:empty() then
		return kNoop
	end

	local segment = composition:back()
	local menu = segment.menu
	local page_size = env.engine.schema.page_size or 7
	local input_code = env.engine.context.input
	if env.prev_input_code ~= input_code then
		env.prev_menu_cand_count = 0
		env.prev_input_code = input_code
	end

	if key_event:repr() == "apostrophe" then
		if menu:candidate_count() < 3 then
			env.engine:process_key(KeyEvent("'"))
			return kAccepted
		end

		local selected_index = segment.selected_index
		if selected_index >= page_size then
			env.engine:process_key(KeyEvent("3"))
			return kAccepted
		end

		env.engine:process_key(KeyEvent("3"))
		return kAccepted
	elseif key_event:repr() == "Next" then
		local menu_cand_count = menu:candidate_count()
		-- FIX: 单页刚好只有 page_size 个候选，会进入下一页
		-- FIX: 来回上下翻页, 触发 Bug

		-- logger.writeLog("cur: " .. menu_cand_count ..", prev: " .. env.prev_menu_cand_count)
		if
			(menu_cand_count < page_size)
			or (menu_cand_count % page_size ~= 0)
			or (env.prev_menu_cand_count == menu_cand_count)
		then
			local selected_index = segment.selected_index
			local selected_cand = segment:get_candidate_at(selected_index)
			local _cand_text = selected_cand.text .. "。"
			local cand_text = rime_api_helper.insert_space_to_candText(env, _cand_text)
			rime_api_helper.reset_commited_cand_state(env)
			context:set_property("prev_commit_is_period", "1")
			env.engine:commit_text(cand_text)
			context:clear()
			return kAccepted
		end
		env.prev_menu_cand_count = menu_cand_count
	end
	return kNoop
end

return P
