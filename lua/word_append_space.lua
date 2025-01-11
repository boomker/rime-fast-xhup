-- 为交替输出中英情况加空格
-- 为中英混输词条（cn_en.dict.yaml）自动空格
-- 示例：`VIP中P` → `VIP 中 P`

require("lib/rime_helper")
local space_leader_word = {}

function space_leader_word.init(env)
    env.return_keys = {
        ["Return"] = true,
        ["Shift+Return"] = true,
    }

    env.symbol_keys = {
        -- ["35"] = true, -- numbersign, #
        ["123"] = true, -- braceleft, {
        ["95"] = true,  -- underscore, _
        ["40"] = true,  -- parenleft, (
        ["38"] = true,  -- ampersand, &
        ["64"] = true,  -- at, @
        ["minus"] = true,
        ["slash"] = true,
        ['grave'] = true,
        ["bracketleft"] = true,
    }
    reset_commited_cand_state(env)
end

function space_leader_word.func(key, env)
    local engine = env.engine
    local key_value = key:repr()
    local key_code = key.keycode
    local context = engine.context
    local input_code = context.input
    local composition = context.composition
    local page_size = engine.schema.page_size
    local segment = composition:back()

    if input_code:match("^/.*") then return 2 end

    local commit_history = context.commit_history
    local current_focus_app = context:get_property("client_app")
    local prev_cand_is_null = context:get_property("prev_cand_is_null")
    local prev_cand_is_word = context:get_property("prev_cand_is_word")
    local prev_cand_is_symbol = context:get_property("prev_cand_is_symbol")
    local prev_cand_is_chinese = context:get_property("prev_cand_is_chinese")
    local prev_cand_is_preedit = context:get_property("prev_cand_is_preedit")

    if current_focus_app ~= context:get_property("prev_focus_app") then
        reset_commited_cand_state(env)
    end


    if (#input_code == 0) and env.return_keys[key_value] then
        reset_commited_cand_state(env)
        context:set_property("prev_cand_is_null", "1")
    end

    if input_code:match("^%p$") or env.symbol_keys[key_value] or env.symbol_keys[tostring(key_code)] then
        set_commited_cand_is_symbol(env)
        return 2
    end

    if (#input_code >= 2) and env.return_keys[key_value] then
        local cand_text = input_code
        local commit_text_is_symbol = false
        if (prev_cand_is_chinese == "1") or (prev_cand_is_word == "1") or (prev_cand_is_preedit == "1") then
            cand_text = " " .. input_code
            engine:commit_text(cand_text)
            commit_history:push("raw", cand_text)
        elseif (prev_cand_is_symbol == "1") and input_code:match("^%p+$") then
            engine:commit_text(cand_text)
            commit_history:push("raw", cand_text)
            commit_text_is_symbol = true
        else
            engine:commit_text(cand_text)
            commit_history:push("raw", cand_text)
        end
        reset_commited_cand_state(env)
        if commit_text_is_symbol then
            context:set_property("prev_cand_is_symbol", "1")
        else
            context:set_property("prev_cand_is_preedit", "1")
        end
        context:set_property("prev_focus_app", current_focus_app)
        context:clear()
        return 1 -- kAccepted
    end

    local index = segment.selected_index or 7
    local selected_cand_idx = get_selected_candidate_index(key_value, index, page_size)

    if (prev_cand_is_symbol == "1") or (prev_cand_is_null == "1") then
        local selected_cand = segment:get_candidate_at(selected_cand_idx)
        -- if not selected_cand then return 2 end
        local cand_text = selected_cand.text or nil
        if cand_text and cand_text:match("^%p?%a+$") then
            set_commited_cand_is_word(env)
        elseif input_code:match("^%p+$") then
            set_commited_cand_is_symbol(env)
        else
            set_commited_cand_is_chinese(env)
        end
        commit_history:push(key)
        context:set_property("prev_focus_app", current_focus_app)
        context:clear()
        return 1
    end

    if (#input_code >= 1) and (key_value == "comma") and (index < page_size) then
        local selected_cand = segment:get_candidate_at(index)
        local cand_text = selected_cand.text
        if (prev_cand_is_preedit == "1") or (prev_cand_is_word == "1") then
            cand_text = " " .. cand_text .. "，"
        elseif (prev_cand_is_chinese == "1") and cand_text:match("^%a+") then
            cand_text = " " .. cand_text .. "，"
        else
            local preedit_text = context:get_preedit().text
            local segmentation = composition:toSegmentation()
            local confirm_pos = segmentation:get_confirmed_position()
            if confirm_pos > 0 then
                local confirm_text = preedit_text:sub(1, (confirm_pos / 2 * 3))
                cand_text = confirm_text .. cand_text .. "，"
            else
                cand_text = cand_text .. "，"
            end
        end
        reset_commited_cand_state(env)
        context:set_property("prev_cand_is_null", "1")
        context:set_property("prev_focus_app", current_focus_app)
        engine:commit_text(cand_text)
        commit_history:push(selected_cand.type, cand_text)
        context:clear()
        return 1 -- kAccepted
    end

    if (#input_code >= 1) and (selected_cand_idx >= 0) then
        local selected_cand = segment:get_candidate_at(selected_cand_idx)
        if not selected_cand then return 2 end
        local cand_text = selected_cand.text

        if (prev_cand_is_preedit == "1") or (prev_cand_is_word == "1") then
            if not cand_text:match("^[%a%p]") then
                local ccand_text = " " .. cand_text
                reset_commited_cand_state(env)
                context:set_property("prev_cand_is_chinese", "1")
                context:set_property("prev_focus_app", current_focus_app)
                engine:commit_text(ccand_text:match("^ "))
                commit_history:push(key)
                context:clear()
                return 1 -- kAccepted
            elseif cand_text:match("^%p?%a+") then
                local ccand_text = " " .. cand_text
                reset_commited_cand_state(env)
                context:set_property("prev_cand_is_word", "1")
                context:set_property("prev_focus_app", current_focus_app)
                engine:commit_text(ccand_text:match("^ "))
                commit_history:push(key)
                context:clear()
                return 1 -- kAccepted
            end
            return 2
        end

        if (prev_cand_is_chinese == "1") and cand_text:match("^%p?%a+") then
            local ccand_text = " " .. cand_text
            reset_commited_cand_state(env)
            context:set_property("prev_cand_is_word", "1")
            context:set_property("prev_focus_app", current_focus_app)
            engine:commit_text(ccand_text:match("^ "))
            commit_history:push(key)
            context:clear()
            return 1 -- kAccepted
        end

        if not cand_text:match("[%a%p]") then
            reset_commited_cand_state(env)
            context:set_property("prev_cand_is_chinese", "1")
            context:set_property("prev_focus_app", current_focus_app)
        end
    end
    return 2 -- kNoop
end

---@diagnostic disable-next-line: unused-local
local function cn_en_spacer(input, env)
    for cand in input:iter() do
        if cand.text:find("([\228-\233][\128-\191]-)") and cand.text:find("[%a]") then
            local function add_spaces(s)
                -- 在中文字符后和英文字符前插入空格
                s = s:gsub("([\228-\233][\128-\191]-)([%w%p])", "%1 %2")
                -- 在英文字符后和中文字符前插入空格
                s = s:gsub("([%w%p])([\228-\233][\128-\191]-)", "%1 %2")
                return s
            end
            cand = cand:to_shadow_candidate(cand.type, add_spaces(cand.text), cand.comment)
        end
        yield(cand)
    end
end

return {
    processor = {
        init = space_leader_word.init,
        func = space_leader_word.func,
    },
    filter = cn_en_spacer,
}
