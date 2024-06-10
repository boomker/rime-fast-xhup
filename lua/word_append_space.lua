-- 为交替输出中英情况加空格
-- 为中英混输词条（cn_en.dict.yaml）自动空格
-- 示例：`VIP中P` → `VIP 中 P`
-- local logger = require('tools/logger')

local function reset_cand_property(env)
    local context = env.engine.context
    context:set_property("prev_cand_is_null", "0")
    context:set_property("prev_cand_is_word", "0")
    context:set_property("prev_cand_is_hanzi", "0")
    context:set_property("prev_cand_is_preedit", "0")
end

local function space_leader_word(key, env)
    local engine = env.engine
    local context = engine.context
    local input_code = context.input
    local pos = context.caret_pos
    local composition = context.composition
    local segment = composition:back()
    local key_value = key:repr()

    if composition:empty() then return 2 end
    if input_code:match("^/.*") then return 2 end

    local cand_select_kyes = {
        ["space"] = -1,
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
        -- ["minus"] = true,
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

    local prev_cand_is_null = context:get_property("prev_cand_is_null")
    local prev_cand_is_word = context:get_property("prev_cand_is_word")
    local prev_cand_is_hanzi = context:get_property("prev_cand_is_hanzi")
    local prev_cand_is_preedit = context:get_property("prev_cand_is_preedit")

    if (#input_code == 0) and spec_keys[key_value] then
        reset_cand_property(env)
        context:set_property("prev_cand_is_null", "1")
    end

    if (#input_code >= 1) and (key_value == "Return") and (segment.prompt == "")
    then
        local cand_text = input_code
        if (prev_cand_is_null ~= "1") and ((prev_cand_is_hanzi == "1") or (prev_cand_is_word == "1")) then
            cand_text = " " .. input_code
            engine:commit_text(cand_text)
        else
            engine:commit_text(cand_text)
        end
        context:set_property("prev_cand_is_preedit", "1")
        context:clear()
        return 1 -- kAccepted
    end

    if cand_select_kyes[key_value] and (#input_code >= 1) and (segment.prompt == "") then
        local index = cand_select_kyes[key_value]
        local selected_cand_idx = (index == -1) and segment.selected_index or index
        local selected_cand = segment:get_candidate_at(selected_cand_idx)
        if not selected_cand then return 2 end
        local cand_text = selected_cand.text

        if (prev_cand_is_null ~= "1") and ((prev_cand_is_preedit == "1") or (prev_cand_is_word == "1")) then
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
                context:set_property("prev_cand_is_word", "1")
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
            if (prev_cand_is_null ~= "1") and ((prev_cand_is_hanzi == "1") or (prev_cand_is_word == "1")) then
                local ccand_text = " " .. cand_text
                engine:commit_text(ccand_text)
                context:set_property("prev_cand_is_word", "1")
                context:clear()
                return 1 -- kAccepted
            elseif (prev_cand_is_null == "1") or (prev_cand_is_hanzi ~= "1") then
                engine:commit_text(cand_text)
                context:set_property("prev_cand_is_word", "1")
                context:set_property("prev_cand_is_null", "0")
                context:clear()
                return 1 -- kAccepted
            else
                context:set_property("prev_cand_is_word", "1")
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

return { processor = space_leader_word, filter = cn_en_spacer }
