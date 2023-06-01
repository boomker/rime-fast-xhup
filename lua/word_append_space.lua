-- local puts = require("tools/debugtool")
local function reset_curCand_property(env)
    local context = env.engine.context
    context:set_property('prev_cand_is_aword', "0")
    context:set_property('prev_cand_is_ascii', "0")
    context:set_property('prev_cand_is_punct', "0")
    context:set_property('prev_cand_is_title', "0")
    context:set_property('prev_cand_is_preedit', "0")
end

local function auto_append_space_processor(key, env)
    local engine = env.engine
    local context = engine.context
    local input_code = context.input

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

    -- 以下这些符号后面跟空格
    local punctuator_keys = {
        ["comma"] = true,
        ["period"] = true,
        ["semicolon"] = true,
        ['Shift+colon'] = true,
        ["Shift+exclam"] = true,
        ["Shift+question"] = true
    }

    -- 以下这些符号后面不跟空格
    local symbol_keys = {
        -- ['equal'] = true,
        ['apostrophe'] = true,
        ['minus'] = true,
        ['slash'] = true,
        ['Shift+at'] = true,
        ['Shift+plus'] = true,
        ['Shift+dollar'] = true,
        ['Shift+quotedbl'] = true,
        ['Shift+asterisk'] = true,
        ['Shift+underscore'] = true,
        ['Control+a'] = true,
        ['Control+u'] = true
    }

    local prev_cand_is_specv = context:get_property('prev_cand_is_spec')
    local prev_cand_is_titlev = context:get_property('prev_cand_is_title')
    local prev_cand_is_asciiv = context:get_property('prev_cand_is_ascii')
    local prev_cand_is_awordv = context:get_property('prev_cand_is_aword')
    local prev_cand_is_punctv = context:get_property('prev_cand_is_punct')
    local prev_cand_is_preeditv = context:get_property('prev_cand_is_preedit')

    if (#input_code == 0) and (punctuator_keys[key:repr()]) then
        --[[ if (prev_cand_is_awordv == '1') or (prev_cand_is_asciiv == '1') then
            local res = env.engine:process_key(KeyEvent("BackSpace"))
        end ]]
        context:set_property('prev_cand_is_punct', "1")
    end

    -- puts(INFO, '----------', prev_cand_is_specv, prev_cand_is_asciiv)
    if (#input_code == 0) and (symbol_keys[key:repr()]) then
        reset_curCand_property(env)
        context:set_property('prev_cand_is_spec', '1')
        context:set_property('prev_cand_is_ascii', '1')
    end

    if (#input_code == 0) and
        ((key:repr() == "Return") or (key:repr() == "Shift+Return")) then
        reset_curCand_property(env)
        context:set_property('prev_cand_is_spec', '1')
    end

    if (#input_code >= 1) and (key:repr() == "Return") then
        local cand_text = input_code
        if (prev_cand_is_specv == '1') and (prev_cand_is_asciiv ~= '0') and
            (prev_cand_is_titlev ~= '1') and (prev_cand_is_awordv ~= '1') then
            engine:commit_text(cand_text)
            context:set_property('prev_cand_is_preedit', "1")
            context:clear()
            return 1 -- kAccepted
        elseif ((prev_cand_is_punctv ~= '1') and (prev_cand_is_asciiv == '0') or
            (prev_cand_is_titlev == '1') or (prev_cand_is_awordv == '1')) then
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
            local candObj = segment:get_candidate_at(
                                cand_select_kyes[key:repr()])
            if not candObj then return 2 end
            cand_text = candObj.text
        end

        if (prev_cand_is_punctv == "1") or (prev_cand_is_titlev == "1") or
            (prev_cand_is_preeditv == "1") or (prev_cand_is_awordv == '1') then
            local ccand_text = " " .. cand_text
            engine:commit_text(ccand_text)
            if tonumber(utf8.codepoint(cand_text, 1)) >= 19968 then
                reset_curCand_property(env)
            end
            context:clear()
            return 1 -- kAccepted
        end

        if tonumber(utf8.codepoint(cand_text, 1)) >= 19968 then
            reset_curCand_property(env)
            context:set_property('prev_cand_is_specv', "0")
            context:confirm_previous_selection()
        end

        if string.match(cand_text, '^%l+$') then
            -- puts(INFO, '========', input_code, key:repr(), prev_cand_is_asciiv, prev_cand_is_specv)
            if (prev_cand_is_asciiv == '0') and (prev_cand_is_specv ~= '1') then
                local ccand_text = " " .. cand_text
                engine:commit_text(ccand_text)
                context:set_property('prev_cand_is_aword', "1")
                context:clear()
                return 1 -- kAccepted
            elseif (prev_cand_is_specv == '1') then
                engine:commit_text(cand_text)
                context:set_property('prev_cand_is_aword', "1")
                context:clear()
                return 1 -- kAccepted
            else
                context:set_property('prev_cand_is_aword', "1")
            end
        end

        if string.match(cand_text, '^%u%l+') then
            if (prev_cand_is_specv == '1') and (prev_cand_is_asciiv ~= '0') then
                engine:commit_text(cand_text)
                context:set_property('prev_cand_is_title', "1")
                context:clear()
                return 1 -- kAccepted
            elseif prev_cand_is_asciiv == '0' then
                local ccand_text = " " .. cand_text
                engine:commit_text(ccand_text)
                context:set_property('prev_cand_is_title', "1")
                context:clear()
                return 1 -- kAccepted
            else
                engine:commit_text(cand_text)
                context:set_property('prev_cand_is_title', "1")
                context:clear()
                return 1 -- kAccepted
            end
        end

    end
    return 2 -- kNoop
end

return {processor = auto_append_space_processor}
