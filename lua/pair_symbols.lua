-- 自动补全配对的符号, 并把光标左移到符号对内部
-- ref: https://github.com/hchunhui/librime-lua/issues/84

local function moveCursorToLeft()
    local osascript = [[osascript -e '
      tell application "System Events" to tell front process
         key code 123
      end tell
   ']]
    os.execute(osascript)
end

local pairTable = {
    ['"'] = '"',
    ["“"] = "”",
    ["'"] = "'",
    ["‘"] = "’",
    ["`"] = "`",
    ["("] = ")",
    ["（"] = "）",
    ["「"] = "」",
    ["["] = "]",
    ["【"] = "】",
    ["〔"] = "〕",
    ["［"] = "］",
    ["〚"] = "〛",
    ["〘"] = "〙",
    ["{"] = "}",
    ["｛"] = "｝",
    ["『"] = "』",
    ["〖"] = "〗",
    ["<"] = ">",
    ["《"] = "》",
    ["quotedbl"] = { "“”", '""' },
    ["apostrophe"] = { "‘’", "''" },
    -- ["apostrophe"] = { "“”", '""' },
    -- ["quotedbl"] = { "‘’", "''" },
}

local function detect_os()
    local user_distribute_name = rime_api:get_distribution_code_name()
    if user_distribute_name:lower():match("weasel") then
        return "Windows"
    elseif user_distribute_name:lower():match("squirrel") then
        return "MacOS"
    elseif user_distribute_name:lower():match("fcitx%-rime") then -- fcitx-rime
        return "MacOS"
    elseif user_distribute_name:lower():match("^fcitx$") then
        return "Linux"
    elseif user_distribute_name:lower():match("ibus") then
        return "Linux"
    else
        return "iOS"
    end
end

local function pair_symbols(key, env)
    local engine = env.engine
    local context = engine.context
    local composition = context.composition
    local segment = composition:back()

    local key_name

    if (key:repr():match("quotedbl")) and (key.keycode == 34) then
        key_name = "quotedbl"
    else
        key_name = key:repr()
    end

    if ((key_name == "quotedbl") or (key_name == "apostrophe"))
        and (detect_os() == "iOS")
    then
        return 2
    end

    local prev_ascii_mode = context:get_option("ascii_mode")
    if pairTable[key_name] and (not context:is_composing()) then
        if prev_ascii_mode then
            engine:commit_text(pairTable[key_name][2])
        else
            engine:commit_text(pairTable[key_name][1])
        end

        if (detect_os() == "MacOS") or (detect_os() == "iOS") then
            moveCursorToLeft()
        end
        context:clear()
        return 1 -- kAccepted 收下此key
    end

    if context:has_menu() and context:is_composing() then
        local keyvalue = key:repr()
        local index = -1
        -- 获得选中的候选词下标
        if (keyvalue == "space") then
            index = segment.selected_index
        elseif string.find(keyvalue, "^[1-9]$") then
            index = tonumber(keyvalue) - 1
        elseif keyvalue == "0" then
            index = 9
        end

        if (index >= 0) and (index < segment.menu:candidate_count()) then
            local candidateText = segment:get_candidate_at(index).text -- 获取指定项 从0起
            local pairedText = pairTable[candidateText]
            if pairedText then
                engine:commit_text(candidateText)
                engine:commit_text(pairedText)
                context:clear()

                if (detect_os() == "MacOS") or (detect_os() == "iOS") then
                    moveCursorToLeft()
                end

                return 1 -- kAccepted 收下此key
            end
        end
    end

    return 2 -- kNoop 此processor 不處理
end

return { processor = pair_symbols }
