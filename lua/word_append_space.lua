-- 为交替输出中英情况加空格
-- 为中英混输词条（cn_en.dict.yaml）自动空格
-- 示例：`VIP中P` → `VIP 中 P`

local rime_api_helper = require('tools/rime_api_helper')
local space_leader_word = {}

function space_leader_word.init(env)
    env.symbol_keys = {
        ["comma"] = true,
        ["equal"] = true,
        ["grave"] = true,
        ["minus"] = true,
        ["slash"] = true,
        ["backslash"] = true,
        ["apostrophe"] = true,
        ["Shift+at"] = true,
        ["Shift+dollar"] = true,
        ["Shift+exclam"] = true,
        ["Shift+quotedbl"] = true,
        ["Shift+asterisk"] = true,
        ["Shift+parenleft"] = true,
        ["Shift+parenright"] = true,
        ["Shift+asciitilde"] = true,
        ["Shift+underscore"] = true,
        ["Shift+numbersign"] = true,
    }

    env.return_keys = {
        ["Return"] = true,
        ["Alt+Return"] = true,
        ["Control+Return"] = true,
    }
    rime_api_helper.reset_commited_cand_state(env)

    -- env.client_app_notifier = env.engine.context.property_update_notifier:connect(function(ctx, name)
    --     if name == "client_app" then
    --         env.current_focus_app_id = ctx:get_property("client_app")
    --     end
    -- end)
end

function space_leader_word.func(key, env)
    local engine = env.engine
    local key_value = key:repr()
    local context = engine.context
    local input_code = context.input
    local caret_pos = context.caret_pos
    local composition = context.composition

    if input_code:match("^/.*") then return 2 end

    local segment = composition:back()
    local page_size = engine.schema.page_size
	local selected_index = segment.selected_index or 7

    -- local current_focus_app  = env.current_focus_app
    local current_focus_app     = context:get_property("client_app")
    local prev_cand_is_null     = context:get_property("prev_cand_is_null")
    local prev_cand_is_word     = context:get_property("prev_cand_is_word")
    local prev_cand_is_chinese  = context:get_property("prev_cand_is_chinese")
    local prev_cand_is_preedit  = context:get_property("prev_cand_is_preedit")
    local prev_commit_is_comma  = context:get_property("prev_commit_is_comma")
    local prev_commit_is_period = context:get_property("prev_commit_is_period")
    local prev_commit_is_symbol = context:get_property("prev_commit_is_symbol")

    if current_focus_app ~= context:get_property("prev_focus_app") then
        rime_api_helper.reset_commited_cand_state(env)
    end

    if env.symbol_keys[key_value] and (
        (#input_code == 0) or ( (#input_code == 1) and input_code:match("^%p$") )
    )
    then
        rime_api_helper.reset_commited_cand_state(env)
        context:set_property("prev_commit_is_symbol", "1")
    end

    if (#input_code == 0) and env.return_keys[key_value] then
        rime_api_helper.reset_commited_cand_state(env)
        context:set_property("prev_cand_is_null", "1")
    end

    if (#input_code >= 1) and (key_value == "Return") then
        local cand_text = input_code
        if (prev_commit_is_comma == "1") or (prev_commit_is_period == "1") then
            engine:commit_text(cand_text)
        elseif (prev_cand_is_null ~= "1") and (#cand_text > 2)
            and (
                (prev_cand_is_chinese == "1")
                or (prev_cand_is_word == "1")
            )
        then
            cand_text = " " .. input_code
            engine:commit_text(cand_text)
        else
            engine:commit_text(cand_text)
        end
        context:set_property("prev_cand_is_preedit", "1")
        context:set_property("prev_focus_app", current_focus_app)
        context:clear()
        return 1 -- kAccepted
    end

    if (#input_code >= 1) and (key_value == "comma") and (selected_index < page_size) then
        local selected_cand = segment:get_candidate_at(selected_index)
        local cand_text = selected_cand.text
        if (prev_commit_is_comma == "1") or (prev_commit_is_period == "1") then
            cand_text =  cand_text .. "，"
        elseif (prev_cand_is_preedit == "1") or (prev_cand_is_word == "1") then
            cand_text = " " .. cand_text .. "，"
        elseif (prev_cand_is_chinese == "1") and cand_text:match("^%a+") then
            cand_text = " " .. cand_text .. "，"
        else
            local preedit_text = context:get_preedit().text
            local segmentation = composition:toSegmentation()
            local confirm_pos  = segmentation:get_confirmed_position()
            if confirm_pos > 0 then
                local confirm_text = preedit_text:sub(1, (confirm_pos / 2 * 3))
                cand_text = confirm_text .. cand_text .. "，"
            else
                cand_text = cand_text .. "，"
            end
        end
        rime_api_helper.reset_commited_cand_state(env)
        context:set_property("prev_commit_is_comma", "1")
        context:set_property("prev_focus_app", current_focus_app)
        engine:commit_text(cand_text)
        context:clear()
        return 1 -- kAccepted
    end

    if (#input_code >= 1) then
        local selected_cand_idx = rime_api_helper.get_selected_candidate_index(key_value, selected_index, page_size)
        if selected_cand_idx < 0 then return 2 end
        local selected_cand = segment:get_candidate_at(selected_cand_idx)
        if not selected_cand then return 2 end
        local cand_text = selected_cand.text

        if (prev_commit_is_comma == "1") or (prev_commit_is_period == "1") then
            rime_api_helper.reset_commited_cand_state(env)
            if cand_text:match("^%a+") then
                context:set_property("prev_cand_is_word", "1")
            else
                context:set_property("prev_cand_is_chinese", "1")
            end
            context:set_property("prev_focus_app", current_focus_app)
            return 2
        end

        if prev_commit_is_symbol == "1" then
            rime_api_helper.reset_commited_cand_state(env)
            if cand_text:match("^%a+") then
                context:set_property("prev_cand_is_word", "1")
            elseif input_code:match("^%p$") then
                context:set_property("prev_cand_is_symbol", "1")
            else
                context:set_property("prev_cand_is_chinese", "1")
            end
            context:set_property("prev_focus_app", current_focus_app)
            return 2
        end

        if (prev_cand_is_null ~= "1") and ((prev_cand_is_preedit == "1") or (prev_cand_is_word == "1")) then
            if (tonumber(utf8.codepoint(cand_text, 1)) >= 19968) and (#input_code == caret_pos) then
                local ccand_text = " " .. cand_text
                rime_api_helper.reset_commited_cand_state(env)
                context:set_property("prev_cand_is_chinese", "1")
                context:set_property("prev_focus_app", current_focus_app)
                engine:commit_text(ccand_text)
                context:clear()
                return 1 -- kAccepted
            elseif string.match(cand_text, "^[%l%u]+") then
                local ccand_text = " " .. cand_text
                rime_api_helper.reset_commited_cand_state(env)
                context:set_property("prev_cand_is_word", "1")
                context:set_property("prev_focus_app", current_focus_app)
                engine:commit_text(ccand_text)
                context:clear()
                return 1 -- kAccepted
            end
            return 2
        end

        if tonumber(utf8.codepoint(cand_text, 1)) >= 19968 then
            rime_api_helper.reset_commited_cand_state(env)
            context:set_property("prev_cand_is_chinese", "1")
            context:set_property("prev_focus_app", current_focus_app)
            return 2
        end

        if string.match(cand_text, "^%a+") then
            if (prev_cand_is_null ~= "1") and
                ((prev_cand_is_chinese == "1") or (prev_cand_is_word == "1"))
            then
                local ccand_text = " " .. cand_text
                rime_api_helper.reset_commited_cand_state(env)
                context:set_property("prev_cand_is_word", "1")
                context:set_property("prev_focus_app", current_focus_app)
                engine:commit_text(ccand_text)
                context:clear()
                return 1 -- kAccepted
            elseif (prev_cand_is_null == "1") or (prev_cand_is_chinese ~= "1") then
                rime_api_helper.reset_commited_cand_state(env)
                context:set_property("prev_cand_is_word", "1")
                context:set_property("prev_focus_app", current_focus_app)
                return 2
            else
                rime_api_helper.reset_commited_cand_state(env)
                context:set_property("prev_cand_is_word", "1")
                context:set_property("prev_focus_app", current_focus_app)
            end
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

-- function space_leader_word.fini(env)
--     env.client_app_notifier:disconnect()
-- end

return {
    processor = {
        init = space_leader_word.init,
        func = space_leader_word.func,
        -- fini = space_leader_word.fini,
    },
    filter = cn_en_spacer,
}
