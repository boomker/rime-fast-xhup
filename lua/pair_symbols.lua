-- 自动补全配对的符号, 并把光标左移到符号对内部
-- ref: https://github.com/hchunhui/librime-lua/issues/84
require("tools/rime_helper")

local function moveCursorToLeft(env)
    local move_cursor = ""
    if detect_os() == "MacOS" then
        move_cursor = env.user_data_dir .. "/lua/tools/move_cursor"
        -- else
        -- move_cursor = [[cmd /c start "" /B ]] .. env.user_data_dir .. [[\lua\tools\move_cursor.exe]]
        os.execute(move_cursor)
    end
end

local P = {}

function P.init(env)
    env.user_data_dir = rime_api:get_user_data_dir()
    env.system_name = detect_os()
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
        ["quotedbl"] = {"“”", '""'},
        ["apostrophe"] = {"‘’", "''"}
    }
end

function P.func(key, env)
    local engine = env.engine
    local context = engine.context
    local page_size = engine.schema.page_size
    local composition = context.composition
    local segment = composition:back()
    local symbol_unpair_flag = context:get_option("symbol_unpair_flag")

    if symbol_unpair_flag then return 2 end
    if (env.system_name == "iOS") then return 2 end
    -- local focus_app_id = context:get_property("client_app")
    -- elseif focus_app_id:match("alacritty") or focus_app_id:match("VSCode") then

    local key_name = key:repr()

    if (key.keycode == 34) then key_name = "quotedbl" end

    local prev_ascii_mode = context:get_option("ascii_mode")
    if env.pairTable[key_name] and composition:empty() then
        if prev_ascii_mode then
            engine:commit_text(env.pairTable[key_name][2])
        else
            engine:commit_text(env.pairTable[key_name][1])
        end

        if (env.system_name == "MacOS") and (key_name == "quotedbl") then
            os.execute("sleep 0.3") -- 等待按键被松开
            moveCursorToLeft(env)
        else
            moveCursorToLeft(env)
        end
        context:clear()
        set_commited_cand_is_symbol(env)
        return 1 -- kAccepted 收下此key
    end

    if context:has_menu() or context:is_composing() then
        local index = segment.selected_index
        local cand = context:get_selected_candidate()
        local selected_cand_idx = get_selected_candidate_index(key_name, index, page_size)
        if cand.text and (key_name == "Shift+Control+9") then
            engine:commit_text("【" .. cand.text .. "】")
            context:clear()
            return 1
        elseif cand.text and (key_name == "Shift+Control+0") then
            engine:commit_text("「" .. cand.text .. "」")
            context:clear()
            return 1
        elseif cand.text and (key_name == "Shift+Control+8") then
            engine:commit_text(" (" .. cand.text .. ") ")
            context:clear()
            return 1
        -- elseif cand.text and (key_name == "Shift+Control+7") then
        --     engine:commit_text(cand.text .. " 先生")
        --     context:clear()
        --     return 1
        end

        if (selected_cand_idx >= 0) then
            local candidate_text = segment:get_candidate_at(selected_cand_idx).text -- 获取指定项 从0起
            local paired_text = env.pairTable[candidate_text]
            if paired_text then
                engine:commit_text(candidate_text)
                engine:commit_text(paired_text)
                context:clear()

                moveCursorToLeft(env)
                set_commited_cand_is_symbol(env)

                return 1 -- kAccepted 收下此key
            end
        end
    end

    return 2 -- kNoop
end

return P
