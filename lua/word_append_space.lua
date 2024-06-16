-- 为交替输出中英情况加空格
-- 为中英混输词条（cn_en.dict.yaml）自动空格
-- 示例：`VIP中P` → `VIP 中 P`
-- local logger = require('tools/logger')
local rime_api_helper = require('tools/rime_api_helper')
local space_leader_word = {}

local function reset_cand_property(env)
    local context = env.engine.context
    context:set_property("prev_cand_is_null", "0")
    context:set_property("prev_cand_is_word", "0")
    context:set_property("prev_cand_is_hanzi", "0")
    context:set_property("prev_cand_is_preedit", "0")
    context:set_property("prev_commit_is_comma", "0")
end

function space_leader_word.init(env)
    env.page_turn_count = 0
    env.spec_keys = {
        ["apostrophe"] = true,
        ["grave"] = true,
        ["equal"] = true,
        ["minus"] = true,
        ["slash"] = true,
        ["Shift+at"] = true,
        ["Shift+plus"] = true,
        ["Shift+dollar"] = true,
        ["Shift+quotedbl"] = true,
        ["Shift+asterisk"] = true,
        ["Shift+parenleft"] = true,
        ["Shift+asciitilde"] = true,
        ["Shift+underscore"] = true,
        ["Shift+parenright"] = true,
    }

    env.return_keys = {
        ["Return"] = true,
        ["Alt+Return"] = true,
        ["Control+Return"] = true,
    }
    reset_cand_property(env)

    -- env.client_app_notifier = env.engine.context.property_update_notifier:connect(function(ctx, name)
    --     if name == "client_app" then
    --         env.current_focus_app_id = ctx:get_property("client_app")
    --     end
    -- end)
end

function space_leader_word.func(key, env)
    local engine = env.engine
    local context = engine.context
    local input_code = context.input
    local pos = context.caret_pos
    local page_size = engine.schema.page_size
    local composition = context.composition
    local segment = composition:back()
    local key_value = key:repr()

    -- if composition:empty() then return 2 end
    if input_code:match("^/.*") then return 2 end

    -- local current_focus_app_id = env.current_focus_app_id
    local current_focus_app_id = context:get_property("client_app")
    local prev_cand_is_null = context:get_property("prev_cand_is_null")
    local prev_cand_is_word = context:get_property("prev_cand_is_word")
    local prev_cand_is_hanzi = context:get_property("prev_cand_is_hanzi")
    local prev_cand_is_preedit = context:get_property("prev_cand_is_preedit")
    local prev_commit_is_comma = context:get_property("prev_commit_is_comma")

    if current_focus_app_id ~= context:get_property("prev_focus_app_id") then
        reset_cand_property(env)
    end

    if (#input_code == 0) and env.return_keys[key_value] then
        reset_cand_property(env)
        context:set_property("prev_cand_is_null", "1")
    end

    if (#input_code == 0) and env.spec_keys[key_value] then
        reset_cand_property(env)
    end

    if (#input_code >= 1) and (key_value == "Return") then
        local cand_text = input_code
        if (prev_commit_is_comma == "1") then
            engine:commit_text(cand_text)
        elseif (prev_cand_is_null ~= "1") and (#cand_text > 2)
            and (
                (prev_cand_is_hanzi == "1")
                or (prev_cand_is_word == "1")
            )
        then
            cand_text = " " .. input_code
            engine:commit_text(cand_text)
        else
            engine:commit_text(cand_text)
        end
        context:set_property("prev_cand_is_preedit", "1")
        context:set_property("prev_focus_app_id", current_focus_app_id)
        context:clear()
        return 1 -- kAccepted
    end

    if (key_value == "Next") then
        env.page_turn_count = env.page_turn_count + 1
    elseif (key_value == "Page_Up") then
        env.page_turn_count = env.page_turn_count - 1
    end

    if (#input_code >= 1) and (key_value == "comma") and (env.page_turn_count == 0) then
        local index = segment.selected_index
        local selected_cand = segment:get_candidate_at(index)
        if (prev_cand_is_preedit == "1") or (prev_cand_is_word == "1") then
            local cand_text = " " .. selected_cand.text .. "，"
            engine:commit_text(cand_text)
            context:set_property("prev_commit_is_comma", "1")
        elseif (prev_cand_is_hanzi == "1") and selected_cand.text:match("^%a+") then
            local cand_text = " " .. selected_cand.text .. "，"
            engine:commit_text(cand_text)
            reset_cand_property(env)
            context:set_property("prev_commit_is_comma", "1")
        else
            local cand_text = selected_cand.text .. "，"
            engine:commit_text(cand_text)
            reset_cand_property(env)
            context:set_property("prev_commit_is_comma", "1")
        end
        context:set_property("prev_focus_app_id", current_focus_app_id)
        context:clear()
        return 1 -- kAccepted
    end

    if (#input_code >= 1) then
        local index = segment.selected_index
        local selected_cand_idx = rime_api_helper.get_selected_candidate_index(key_value, index, page_size)
        if selected_cand_idx < 0 then return 2 end
        local selected_cand = segment:get_candidate_at(selected_cand_idx)
        if not selected_cand then return 2 end
        local cand_text = selected_cand.text

        if (prev_commit_is_comma == "1") then
            engine:commit_text(cand_text)
            reset_cand_property(env)
            if cand_text:match("^%a+") then
                context:set_property("prev_cand_is_word", "1")
            else
                context:set_property("prev_cand_is_hanzi", "1")
            end
            context:set_property("prev_focus_app_id", current_focus_app_id)
            context:clear()
            return 1
        end

        if (prev_cand_is_null ~= "1") and ((prev_cand_is_preedit == "1") or (prev_cand_is_word == "1")) then
            if (tonumber(utf8.codepoint(cand_text, 1)) >= 19968) and (#input_code == pos) then
                local ccand_text = " " .. cand_text
                engine:commit_text(ccand_text)
                reset_cand_property(env)
                context:set_property("prev_cand_is_hanzi", "1")
                context:set_property("prev_focus_app_id", current_focus_app_id)
                context:clear()
                return 1 -- kAccepted
            elseif string.match(cand_text, "^[%l%u]+") then
                local ccand_text = " " .. cand_text
                engine:commit_text(ccand_text)
                reset_cand_property(env)
                context:set_property("prev_cand_is_word", "1")
                context:set_property("prev_focus_app_id", current_focus_app_id)
                context:clear()
                return 1 -- kAccepted
                -- else
                --     context:confirm_previous_selection()
            end
            return 2
        end

        if tonumber(utf8.codepoint(cand_text, 1)) >= 19968 then
            reset_cand_property(env)
            context:set_property("prev_cand_is_hanzi", "1")
            context:set_property("prev_focus_app_id", current_focus_app_id)
            -- context:confirm_previous_selection()
            return 2
        end

        if string.match(cand_text, "^[%l%u]+") then
            if (prev_cand_is_null ~= "1") and ((prev_cand_is_hanzi == "1") or (prev_cand_is_word == "1")) then
                local ccand_text = " " .. cand_text
                engine:commit_text(ccand_text)
                reset_cand_property(env)
                context:set_property("prev_cand_is_word", "1")
                context:set_property("prev_focus_app_id", current_focus_app_id)
                context:clear()
                return 1 -- kAccepted
            elseif (prev_cand_is_null == "1") or (prev_cand_is_hanzi ~= "1") then
                engine:commit_text(cand_text)
                reset_cand_property(env)
                context:set_property("prev_cand_is_word", "1")
                context:set_property("prev_cand_is_null", "0")
                context:set_property("prev_focus_app_id", current_focus_app_id)
                context:clear()
                return 1 -- kAccepted
            else
                reset_cand_property(env)
                context:set_property("prev_cand_is_word", "1")
                context:set_property("prev_focus_app_id", current_focus_app_id)
            end
        end
    end
    return 2 -- kNoop
end

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
