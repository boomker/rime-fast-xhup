-- 输入的内容大写前2个字符，自动转小写词条为全词大写；大写第一个字符，自动转写小写词条为首字母大写
-- local puts = require("tools/debugtool")

local function autocap_filter(input, env)
    for cand in input:iter() do
        local text = cand.text
        local commit = env.engine.context:get_commit_text()
        if string.find(text, "^%l%l.*") and string.find(commit, "^%u%u.*") then
            if string.len(text) == 2 then
                local cand_2 = Candidate("cap", 0, 2, commit, "+")
                yield(cand_2)
            else
                local cand_u = Candidate("cap", 0, string.len(commit), string.upper(text), "+AU")
                yield(cand_u)
            end
        --[[ 修改候选的注释 `cand.comment`
            因复杂类型候选项的注释不能被直接修改，
            因此使用 `get_genuine()` 得到其对应真实的候选项
            cand:get_genuine().comment = cand.comment .. " " .. s
        --]]
        elseif string.find(text, "^%l+$") and string.find(commit, "^%u+") then
            local suffix = string.sub(text, string.len(commit) + 1)
            local cand_ua = Candidate("cap", 0, string.len(commit), commit .. suffix, "+" .. suffix)
            yield(cand_ua)
        --[[ elseif string.find(text, "^%l+$") and (not string.find(text, "[:/.@]+")) then
            local cand_as = Candidate("as", 0, string.len(text)+2, text .. " " , "~AS")
            yield(cand_as) ]]
        else
            yield(cand)
        end
    end
end

local function autocap_processor(key, env)
    local engine              = env.engine
    local context             = engine.context
    local input_code          = context.input

    local cand_kyes = {
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
    }

    local punctuator_keys = {
        ["semicolon"] = true,
        ["comma"] = true,
        ["period"] = true,
        ["Shift+question"] = true,
        ['Shift+colon'] = true,
    }

    local symbol_keys = {
        ['minus'] = true,
        ['equal'] = true,
        ['slash'] = true,
        ['Shift+at'] = true,
        ['Shift+plus'] = true,
        ['Shift+dollar'] = true,
        ['Shift+asterisk'] = true,
        ['Shift+underscore'] = true
    }

    if (#input_code == 0) and (punctuator_keys[key:repr()]) then
        context:set_property('prev_cand_is_punct', "1")
    end

    if (#input_code == 0) and (symbol_keys[key:repr()]) then
        context:set_property('prev_cand_is_title', "0")
        context:set_property('prev_cand_is_aword', "0")
        context:set_property('prev_cand_is_punct', "0")
        context:set_property('prev_cand_is_preedit', "0")
        context:set_property('prev_cand_is_ascii', "1")
    end

    if (#input_code == 0) and (key:repr() == "Return") then
        context:set_property('prev_cand_is_ascii', "1")
        context:set_property('prev_cand_is_aword', "0")
        context:set_property('prev_cand_is_punct', "0")
        context:set_property('prev_cand_is_title', "0")
        context:set_property('prev_cand_is_preedit', "0")
    end

    if (#input_code > 1) and (key:repr() == "Return") then
        local cand_text = input_code
        if (context:get_property('prev_cand_is_ascii') == '0')
            or (context:get_property('prev_cand_is_preedit') == '1')
            or (context:get_property('prev_cand_is_aword') == '1') then
            cand_text = " " .. input_code
            engine:commit_text(cand_text)
            -- context:set_property('prev_cand_is_ascii', "1")
            context:set_property('prev_cand_is_preedit', "1")
        else
            engine:commit_text(cand_text)
            context:set_property('prev_cand_is_preedit', "1")
        end
        context:clear()
        return 1 -- kAccepted
    end

    if (cand_kyes[key:repr()]) and (#input_code > 1) then
        local cand_text         = context:get_commit_text()

        local composition = context.composition
        if (not composition:empty()) then
            local segment = composition:back()
            local candObj = segment:get_candidate_at(cand_kyes[key:repr()])
            if not candObj then return 2 end
            cand_text = candObj.text
        end

        if (context:get_property('prev_cand_is_punct') == "1")
            or (context:get_property('prev_cand_is_title') == "1")
            or (context:get_property('prev_cand_is_preedit') == "1" )
            or (context:get_property('prev_cand_is_aword') == '1') then
            local ccand_text = " " .. cand_text
            engine:commit_text(ccand_text)
            context:set_property('prev_cand_is_aword', "0")
            context:set_property('prev_cand_is_ascii', "0")
            context:set_property('prev_cand_is_punct', "0")
            context:set_property('prev_cand_is_title', "0")
            context:set_property('prev_cand_is_preedit', "0")
            context:clear()
            return 1 -- kAccepted
        end

        if tonumber(utf8.codepoint(cand_text, 1)) >= 19968 then
            context:set_property('prev_cand_is_ascii', "0")
            --[[ engine:commit_text(cand_text)
            context:clear()
            return 1 -- kAccepted ]]
        end

        if string.match(cand_text, '^%l+$') then
            if (context:get_property('prev_cand_is_ascii') == '0') then
                local ccand_text = " " .. cand_text .. " "
                engine:commit_text(ccand_text)
                context:set_property('prev_cand_is_ascii', "1")
                context:clear()
                return 1 -- kAccepted
            else
                engine:commit_text(cand_text)
                context:set_property('prev_cand_is_aword', "1")
                context:clear()
                return 1 -- kAccepted
            end
        end

        if string.match(cand_text, '^%u+%l+') then
            if context:get_property('prev_cand_is_ascii') == '0' then
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

---@diagnostic disable-next-line: unused-local
local function autocap_translator(input, seg, env)
    if string.match(input, '%u%u%l+') then
        local cand = Candidate("word_caps", seg.start, seg._end, string.upper(input), '~AU')
        yield(cand)
    end
end
return {filter = autocap_filter, translator = autocap_translator, processor = autocap_processor}
