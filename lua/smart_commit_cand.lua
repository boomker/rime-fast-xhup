-- require("lib/rime_helper")

local P = {}
local kNoop = 2
local kReject = 0
local kAccepted = 1

local function reset_state(env)
    env.prev_input_code = nil
    env.prev_menu_cand_count = 0
    env.max_page_count = 0
end

function P.init(env) reset_state(env) end

function P.func(key_event, env)
    local key_cond = false
    local input_code = env.engine.context.input
    if env.prev_input_code ~= input_code then
        env.max_page_count = 0
        env.prev_page_turn_count = 0
        env.prev_menu_cand_count = 0
        env.prev_input_code = input_code
    end
    if key_event:repr() == "apostrophe" then
        key_cond = true
    elseif key_event:repr() == "comma" then
        key_cond = true
    elseif key_event:repr() == "period" then
        key_cond = true
    end
    if not key_cond then return kNoop end

    local context = env.engine.context
    local composition = context.composition
    if composition:empty() then return kNoop end

    local segment = composition:back()
    if segment:has_tag("url") then return kNoop end
    if segment:has_tag("calculator") then return kNoop end
    if segment:has_tag("chinese_number") then return kNoop end

    local menu = segment.menu
    local commit_history = context.commit_history
    local page_size = env.engine.schema.page_size or 7
    env.max_page_count = (env.prev_page_turn_count >= env.max_page_count)
        and env.prev_page_turn_count or env.max_page_count


    if key_event:repr() == "apostrophe" then
        if (input_code:match("^[^~]")) and segment:has_tag("radical_lookup") then
            env.engine:process_key(KeyEvent("'"))
            return kAccepted
        end

        env.engine:process_key(KeyEvent("3"))
        return kAccepted
    elseif key_event:repr() == "period" then
        -- FIX: 单页刚好只有 page_size 个候选, 没响应
        local menu_cand_count = menu:candidate_count() or 0
        env.prev_page_turn_count = env.prev_page_turn_count + 1
        if
            (
                (
                    (menu_cand_count % page_size ~= 0)
                    or (env.prev_menu_cand_count == menu_cand_count)
                ) and (env.prev_page_turn_count == env.max_page_count)
            ) or (menu_cand_count < page_size)
        then
            local selected_index = segment.selected_index
            local selected_cand = segment:get_candidate_at(selected_index)
            local cand_text = selected_cand.text .. "。"
            env.engine:commit_text(cand_text)
            commit_history:push(selected_cand.type, cand_text)
            -- local cand_text = insert_space_to_candText(env, _cand_text)
            -- reset_commited_cand_state(env)
            reset_state(env)
            context:clear()
            return kAccepted
        end
        env.prev_menu_cand_count = menu_cand_count
        env.max_page_count = env.prev_page_turn_count + 1
    elseif (key_event:repr() == "comma") then
        if (env.prev_page_turn_count <= 0) then
            local selected_index = segment.selected_index
            local selected_cand = segment:get_candidate_at(selected_index)
            local cand_text = selected_cand.text .. "，"
            env.engine:commit_text(cand_text)
            commit_history:push(selected_cand.type, cand_text)
            -- local cand_text = insert_space_to_candText(env, _cand_text)
            -- reset_commited_cand_state(env)
            reset_state(env)
            context:clear()
            return kAccepted
        end
        env.prev_page_turn_count = env.prev_page_turn_count - 1
    end
    return kNoop
end

return P
