-- 自动补全配对的符号, 并把光标左移到符号对内部
-- ref: https://github.com/hchunhui/librime-lua/issues/84

local rime_api_helper = require("tools/rime_api_helper")

local function moveCursorToLeft(env)
    local move_cursor = ""
    if rime_api_helper.detect_os() == "MacOS" then
        move_cursor = env.user_data_dir .. "/lua/tools/move_cursor"
    else
        move_cursor = [[cmd /c  start "" /B ]] .. env.user_data_dir .. [[\lua\tools\move_cursor.exe]]
    end
    os.execute(move_cursor)
end

local P = {}

function P.init(env)
    env.user_data_dir = rime_api:get_user_data_dir()
    env.system_name = rime_api_helper.detect_os()
    env.pairTable = {
        ['"'] = '"',
        ["“"] = "”",
        ["'"] = "'",
        ["‘"] = "’",
        ["`"] = "`",
        ["("] = ")",
        ["["] = "]",
        ["{"] = "}",
        ["<"] = ">",
        ["（"] = "）",
        ["【"] = "】",
        ["〔"] = "〕",
        ["〚"] = "〛",
        ["〘"] = "〙",
        ["「"] = "」",
        ["［"] = "］",
        ["｛"] = "｝",
        ["『"] = "』",
        ["〖"] = "〗",
        ["《"] = "》",
        ["quotedbl"] = { "“”", '""' },
        ["apostrophe"] = { "‘’", "''" },
    }
end

function P.func(key, env)
    local engine = env.engine
    local context = engine.context
    local composition = context.composition
    local segment = composition:back()
    local symbol_unpair_flag = context:get_option("symbol_unpair_flag")

    if symbol_unpair_flag then return 2 end
    if (env.system_name == "iOS") then return 2 end
    -- local focus_app_id = context:get_property("client_app")
    -- elseif focus_app_id:match("alacritty") or focus_app_id:match("VSCode") then

    local key_name

    if (key:repr():match("quotedbl")) and (key.keycode == 34) then
        key_name = "quotedbl"
    else
        key_name = key:repr()
    end

    local prev_ascii_mode = context:get_option("ascii_mode")
    if env.pairTable[key_name] and composition:empty() then
        if prev_ascii_mode then
            engine:commit_text(env.pairTable[key_name][2])
        else
            engine:commit_text(env.pairTable[key_name][1])
        end

        if (env.system_name == "MacOS") and (key_name == "quotedbl") then
            os.execute("sleep 0.2")
            moveCursorToLeft(env)
        else
            moveCursorToLeft(env)
        end
        context:clear()
        rime_api_helper.set_commited_cand_is_pairSymbol(env)
        return 1 -- kAccepted 收下此key
    end

    if context:has_menu() or context:is_composing() then
        local keyvalue = key:repr()
        local index = segment.selected_index
        local selected_cand_idx = rime_api_helper.get_selected_candidate_index(keyvalue, index)

        if (selected_cand_idx >= 0) then
            local candidateText = segment:get_candidate_at(selected_cand_idx).text -- 获取指定项 从0起
            local pairedText = env.pairTable[candidateText]
            if pairedText then
                engine:commit_text(candidateText)
                engine:commit_text(pairedText)
                context:clear()

                moveCursorToLeft(env)
                rime_api_helper.set_commited_cand_is_pairSymbol(env)

                return 1 -- kAccepted 收下此key
            end
        end
    end

    return 2 -- kNoop
end

return P
