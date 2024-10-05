-- 自动补全配对的符号, 并把光标左移到符号对内部
-- ref: https://github.com/hchunhui/librime-lua/issues/84

-- local logger = require("tools/logger")
local rime_api_helper = require("tools/rime_api_helper")

local function moveCursorToLeft(env)
    --     local osascript = [[osascript -e '
    --       tell application "System Events" to tell front process
    --          key code 123
    --       end tell
    --    ']]
    local move_cursor = env.user_data_dir .. "/lua/tools/move_cursor"
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
    }
end

function P.func(key, env)
    local engine = env.engine
    local context = engine.context
    local composition = context.composition
    local segment = composition:back()
    -- local focus_app_id = context:get_property("client_app")
    local symbol_unpair_flag = context:get_option("symbol_unpair_flag")
    if symbol_unpair_flag then return 2 end
    -- elseif focus_app_id:match("alacritty") or focus_app_id:match("VSCode") then

    local key_name

    if (key:repr():match("quotedbl")) and (key.keycode == 34) then
        key_name = "quotedbl"
    else
        key_name = key:repr()
    end

    if ((key_name == "quotedbl") or (key_name == "apostrophe"))
        and (env.system_name == "iOS")
    then
        return 2
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
        elseif (env.system_name == "MacOS") then
            moveCursorToLeft(env)
        end
        context:clear()
        return 1 -- kAccepted 收下此key
    end

    if context:has_menu() or context:is_composing() then
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

        -- logger.writeLog("kv: " .. keyvalue .. ", index: " .. index)
        if (index >= 0) and (index < segment.menu:candidate_count()) then
            local candidateText = segment:get_candidate_at(index).text -- 获取指定项 从0起
            local pairedText = env.pairTable[candidateText]
            if pairedText then
                engine:commit_text(candidateText)
                engine:commit_text(pairedText)
                context:clear()

                if (env.system_name == "MacOS") then
                    moveCursorToLeft(env)
                end

                return 1 -- kAccepted 收下此key
            end
        end
    end

    return 2 -- kNoop
end

return P
