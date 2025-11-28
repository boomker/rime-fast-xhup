-- 自动补全配对的符号, 并把光标左移到符号对内部
-- ref: https://github.com/hchunhui/librime-lua/issues/84
require("lib/rime_helper")

local function moveCursorToLeft(env)
    local move_cursor = ""
    if detect_os() == "MacOS" then
        move_cursor = env.user_data_dir .. "/lua/lib/move_cursor"
        os.execute(move_cursor)
    end
end

local P = {}

function P.init(env)
    env.system_name = detect_os()
    local config = env.engine.schema.config
    env.user_data_dir = rime_api:get_user_data_dir()
    env.pair_toggle = config:get_string("pair_symbol/toggle") or "off"
    env.calc_tip = config:get_string("calculator/tips") or "计算器"
    env.number_tip = config:get_string("chinese_number/tips") or "中文数字"
    env.enclosed_a = config:get_string("key_binder/enclosed_cand_chars_a") or nil
    env.enclosed_b = config:get_string("key_binder/enclosed_cand_chars_b") or nil
    env.enclosed_c = config:get_string("key_binder/enclosed_cand_chars_c") or nil
    env.enclosed_d = config:get_string("key_binder/enclosed_cand_chars_d") or nil
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
    local page_size = engine.schema.page_size
    local composition = context.composition
    local segment = composition:back()

    if env.system_name ~= "MacOS" then return 2 end
    if context:get_option("symbol_unpair_flag") then return 2 end
    if segment and segment.prompt:match("农历") then return 2 end
    if segment and segment.prompt:match("应用闪切") then return 2 end
    if segment and segment.prompt:match("配置选项") then return 2 end
    if segment and segment.prompt:match(env.calc_tip) then return 2 end
    if segment and segment.prompt:match(env.number_tip) then return 2 end

    local key_name = key:repr()
    if key.keycode == 34 then key_name = "quotedbl" end
    local prev_ascii_mode = context:get_option("ascii_mode")

    if context:has_menu() or context:is_composing() then
        local index = segment.selected_index
        local cand = context:get_selected_candidate()
        local commit_history = context.commit_history
        local selected_cand_idx = get_selected_candidate_index(key_name, index, page_size)
        if not selected_cand_idx then return 2 end

        if env.enclosed_a or env.enclosed_b or env.enclosed_c or env.enclosed_d then
            local matched = false
            if key_name == env.enclosed_a then
                matched = true
                engine:commit_text("「" .. cand.text .. "」")
                commit_history:push("raw", "「" .. cand.text .. "」")
            elseif key_name == env.enclosed_b then
                matched = true
                engine:commit_text("【" .. cand.text .. "】")
                commit_history:push("raw", "【" .. cand.text .. "】")
            elseif key_name == env.enclosed_c then
                matched = true
                engine:commit_text("（" .. cand.text .. "）")
                commit_history:push("raw", "（" .. cand.text .. "）")
            elseif key_name == env.enclosed_d then
                matched = true
                engine:commit_text("〔" .. cand.text .. "〕")
                commit_history:push("raw", "〔" .. cand.text .. "〕")
            end
            if matched then
                context:clear()
                return 1
            end
        end

        if (selected_cand_idx >= 0) and (env.pair_toggle == "on") then
            local candidate_text = segment:get_candidate_at(selected_cand_idx).text -- 获取指定项 从0起
            local paired_text = env.pairTable[candidate_text]
            if paired_text then
                engine:commit_text(candidate_text)
                engine:commit_text(paired_text)
                context:clear()

                moveCursorToLeft(env)
                set_committed_cand_is_symbol(env)

                return 1 -- kAccepted 收下此key
            end
        end
    end

    if env.pair_toggle == "off" then return 2 end
    if env.pairTable[key_name] and composition:empty() then
        if prev_ascii_mode then
            engine:commit_text(env.pairTable[key_name][2])
        else
            engine:commit_text(env.pairTable[key_name][1])
        end

        if key.shift and (key_name == "quotedbl") then
            os.execute("sleep 0.1") -- 等待按键被松开
            if KeyEvent(key:repr()):release() then
                moveCursorToLeft(env)
            else
                moveCursorToLeft(env)
            end
        else
            moveCursorToLeft(env)
        end
        context:clear()
        set_committed_cand_is_symbol(env)
        return 1 -- kAccepted 收下此key
    end

    return 2 -- kNoop
end

return P
