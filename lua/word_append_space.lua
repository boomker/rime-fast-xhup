-- local puts = require("tools/debugtool")
local function reset_cand_property(env)
    local context = env.engine.context
    context:set_property('prev_cand_is_null', "0")
    context:set_property('prev_cand_is_aword', "0")
    context:set_property('prev_cand_is_hanzi', "0")
    context:set_property('prev_cand_is_preedit', "0")
end

local function auto_append_space_processor(key, env)
    local engine = env.engine
    local context = engine.context
    local input_code = context.input
    local pos = context.caret_pos

    local cand_select_kyes = {
        ["space"] = 0,
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
        ["10"] = 9
    }

    local spec_keys ={
        -- ['equal'] = true,
        ['apostrophe'] = true,
        ['grave'] = true,
        ['minus'] = true,
        ['slash'] = true,
        ['Shift+at'] = true,
        ['Shift+plus'] = true,
        ['Shift+dollar'] = true,
        ['Shift+quotedbl'] = true,
        ['Shift+asterisk'] = true,
        ['Shift+underscore'] = true,
        ['Shift+parenleft'] = true,
        ['Shift+parenright'] = true,
        ['Return'] = true,
        ['Control+Return'] = true,
        ['Alt+Return'] = true,
    }

    local prev_cand_is_nullv    = context:get_property('prev_cand_is_null')
    local prev_cand_is_hanziv   = context:get_property('prev_cand_is_hanzi')
    local prev_cand_is_awordv   = context:get_property('prev_cand_is_aword')
    local prev_cand_is_preeditv = context:get_property('prev_cand_is_preedit')

    if (#input_code == 0) and (spec_keys[key:repr()]) then
        reset_cand_property(env)
        context:set_property('prev_cand_is_null', '1')
    end

    if (#input_code >= 1) and (key:repr() == "Return") then
        local cand_text = input_code
        if (prev_cand_is_nullv ~= '1') and ((prev_cand_is_hanziv == '1') or (prev_cand_is_awordv == '1')) then
            cand_text = " " .. input_code
            engine:commit_text(cand_text)
        else
            engine:commit_text(cand_text)
        end
        context:set_property('prev_cand_is_preedit', "1")
        context:clear()
        return 1 -- kAccepted
    end

    if (cand_select_kyes[key:repr()]) and (#input_code >= 1) then
        local cand_text = context:get_commit_text()

        local composition = context.composition
        if (not composition:empty()) then
            local segment = composition:back()
            local candObj = segment:get_candidate_at(cand_select_kyes[key:repr()])
            if not candObj then return 2 end
            cand_text = candObj.text
        end

        if (prev_cand_is_nullv ~= '1') and ((prev_cand_is_preeditv == "1") or (prev_cand_is_awordv == '1')) then
            if (tonumber(utf8.codepoint(cand_text, 1)) >= 19968) and (#input_code == pos) then
                local ccand_text = " " .. cand_text
                engine:commit_text(ccand_text)
                reset_cand_property(env)
                context:set_property('prev_cand_is_hanzi', "1")
                context:clear()
                return 1 -- kAccepted
            elseif (string.match(cand_text, '^[%l%u]+')) then
                local ccand_text = " " .. cand_text
                engine:commit_text(ccand_text)
                reset_cand_property(env)
                context:set_property('prev_cand_is_aword', "1")
                context:clear()
                return 1 -- kAccepted
            else
                context:confirm_previous_selection()
            end
            return 2 -- kAccepted
        end

        if tonumber(utf8.codepoint(cand_text, 1)) >= 19968 then
            reset_cand_property(env)
            context:set_property('prev_cand_is_hanzi', "1")
            context:confirm_previous_selection()
        end

        if string.match(cand_text, '^[%l%u]+') then
            if (prev_cand_is_nullv ~= '1') and ((prev_cand_is_hanziv == '1') or (prev_cand_is_awordv == '1')) then
                local ccand_text = " " .. cand_text
                engine:commit_text(ccand_text)
                context:set_property('prev_cand_is_aword', "1")
                context:clear()
                return 1 -- kAccepted
            elseif (prev_cand_is_nullv == '1') or (prev_cand_is_hanziv ~= '1') then
                engine:commit_text(cand_text)
                context:set_property('prev_cand_is_aword', "1")
                context:clear()
                return 1 -- kAccepted
            else
                context:set_property('prev_cand_is_aword', "1")
            end
        end

    end
    return 2 -- kNoop
end

return {processor = auto_append_space_processor}
