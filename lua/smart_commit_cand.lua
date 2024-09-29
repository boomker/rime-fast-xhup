local rime_api_helper = require("tools/rime_api_helper")
-- local logger = require('tools/logger')

local P = {}
-- local kReject = 0
local kAccepted = 1
local kNoop = 2

local function reset_state(env)
	env.prev_input_code = nil
	env.prev_menu_cand_count = 0
	env.max_page_turn_count = 0
	env.act_page_turn_count = 0
end

function P.init(env)
	reset_state(env)
end

function P.func(key_event, env)
	local whether_process = false
	local input_code = env.engine.context.input
	if env.prev_input_code ~= input_code then
		env.max_page_turn_count = 0
		env.act_page_turn_count = 0
		env.prev_page_turn_count = 0
		env.prev_menu_cand_count = 0
		env.prev_input_code = input_code
	end
	if key_event:repr() == "apostrophe" then
		whether_process = true
	elseif key_event:repr() == "comma" then
		env.act_page_turn_count = env.act_page_turn_count - 1
	elseif key_event:repr() == "period" then
		whether_process = true
	end
	env.max_page_turn_count = (env.prev_page_turn_count >= env.max_page_turn_count)
		and env.prev_page_turn_count or env.max_page_turn_count

	if not whether_process then return kNoop end

	local context = env.engine.context
	local composition = context.composition
	if composition:empty() then return kNoop end

	local segment = composition:back()
	local menu = segment.menu
	local page_size = env.engine.schema.page_size or 7

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
	elseif key_event:repr() == "period" then
		local menu_cand_count = menu:candidate_count() or 0
		-- FIX: 单页刚好只有 page_size 个候选, 不响应

		if
			(
				(menu_cand_count < page_size)
				or (menu_cand_count % page_size ~= 0)
				or (env.prev_menu_cand_count == menu_cand_count)
			) and (env.act_page_turn_count == env.max_page_turn_count)
		then
			local selected_index = segment.selected_index
			local selected_cand = segment:get_candidate_at(selected_index)
			local _cand_text = selected_cand.text .. "。"
			local cand_text = rime_api_helper.insert_space_to_candText(env, _cand_text)
			rime_api_helper.reset_commited_cand_state(env)
			env.engine:commit_text(cand_text)
			reset_state(env)
			context:clear()
			return kAccepted
		end
		env.prev_menu_cand_count = menu_cand_count
		env.act_page_turn_count = env.act_page_turn_count + 1
		env.prev_page_turn_count = env.act_page_turn_count
	end
	return kNoop
end

return P
