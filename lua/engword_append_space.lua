-- local puts = require("tools/debugtool")

local processor = {}

local function reset_cand_property(env)
    local context = env.engine.context
    context:set_property('prev_cand_is_spec', "0")
    context:set_property('prev_cand_is_aword', "0")
    context:set_property('prev_cand_is_punct', "0")
    context:set_property('prev_cand_is_preedit', "0")
end

function processor.init(env)
    reset_cand_property(env)
end

function processor.func(key, env)
    local engine = env.engine
    local context = engine.context
    local input_code = context.input

    local prev_cand_is_specv    = context:get_property('prev_cand_is_spec')
    local prev_cand_is_awordv   = context:get_property('prev_cand_is_aword')
    local prev_cand_is_punctv   = context:get_property('prev_cand_is_punct')
    local prev_cand_is_preeditv = context:get_property('prev_cand_is_preedit')
    local prev_cand_is_pfxspcsv = context:get_property('prev_cand_is_pfxspcs')

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
        ["Shift+question"] = true,
    }

    local prefix_space_symbols = {
        ['Shift+numbersign'] = '#',
        ['Shift+quotedbl'] = '"',
        ['Shift+dollar'] = '$',
        ['Shift+parenleft'] = '(',
        ['Shift+parenright'] = ')',
    }

    -- 以下这些符号后面不跟空格
    local symbol_keys = {
        -- ['equal'] = true,
        -- ['Shift+bar'] = true,
        ['apostrophe'] = true,
        ['grave'] = true,
        ['minus'] = true,
        ['slash'] = true,
        ['Shift+at'] = true,
        ['Shift+plus'] = true,
        ['Shift+dollar'] = true,
        ['Shift+quotedbl'] = true,
        ['Shift+asterisk'] = true,
        ['Shift+backslash'] = true,
        ['Shift+parenleft'] = true,
        ['Shift+underscore'] = true,
        ['Return'] = true,
        ['Control+Return'] = true,
        ['Alt+Return'] = true,
    }

    if (#input_code == 0) and (punctuator_keys[key:repr()]) then
        context:set_property('prev_cand_is_punct', "1")
    end

    if (#input_code == 0) and (symbol_keys[key:repr()]) then
        reset_cand_property(env)
        context:set_property('prev_cand_is_spec', '1')
    end

    if (#input_code >= 1) and (key:repr() == "Return") then
        local cand_text = input_code
        if (prev_cand_is_punctv == '1') or (prev_cand_is_awordv == '1') then
            cand_text = " " .. input_code
            engine:commit_text(cand_text)
        else
            engine:commit_text(cand_text)
        end
        context:set_property('prev_cand_is_preedit', "1")
        context:clear()
        return 1 -- kAccepted
    end

    if (prefix_space_symbols[key:repr()]) then
        local cand_text = prefix_space_symbols[key:repr()]
        if string.match(cand_text, '"') then
            if prev_cand_is_pfxspcsv ~= '1' then
                cand_text = " " .. prefix_space_symbols[key:repr()]
                context:set_property('prev_cand_is_pfxspcs', '1')
            else
                cand_text = prefix_space_symbols[key:repr()] .. " "
                context:set_property('prev_cand_is_pfxspcs', '0')
            end
            engine:commit_text(cand_text)
            context:clear()
            return 1 -- kAccepted
        end

        if string.find(cand_text, '[#$(]') then
            cand_text = " " .. prefix_space_symbols[key:repr()]
        elseif (string.match(cand_text, '[)]')) then
            cand_text = prefix_space_symbols[key:repr()] .. " "
        end
        engine:commit_text(cand_text)
        context:clear()
        return 1 -- kAccepted
    end

    if (cand_select_kyes[key:repr()]) and (#input_code >= 1) then
        local cand_text = context:get_commit_text()

        --[[ local composition = context.composition
        if (not composition:empty()) then
            local segment = composition:back()
            local candObj = segment:get_candidate_at(cand_select_kyes[key:repr()])
            if not candObj then return 2 end
            cand_text = candObj.text
        end ]]

        if (prev_cand_is_preeditv == '1') or (prev_cand_is_punctv == '1') or (prev_cand_is_awordv == '1') then
            local ccand_text = " " .. cand_text
            engine:commit_text(ccand_text)
            reset_cand_property(env)
            context:set_property('prev_cand_is_aword', "1")
            context:clear()
            return 1 -- kAccepted
        end

        if string.match(cand_text, '^[%u%l]+') then
            if (prev_cand_is_specv == '0') and (prev_cand_is_awordv == '0')
                and (prev_cand_is_preeditv == '0') and (prev_cand_is_punctv == '0') then
                engine:commit_text(cand_text)
                context:set_property('prev_cand_is_aword', "1")
                context:clear()
                return 1 -- kAccepted
            elseif (prev_cand_is_specv ~= '1') then
                local ccand_text = " " .. cand_text
                engine:commit_text(ccand_text)
                reset_cand_property(env)
                context:set_property('prev_cand_is_aword', "1")
                context:clear()
                return 1 -- kAccepted
            elseif (prev_cand_is_specv == '1') then
                engine:commit_text(cand_text)
                reset_cand_property(env)
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

return {
    processor = { init = processor.init, func = processor.func }
}
