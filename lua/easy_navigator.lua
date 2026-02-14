require("lib/string")
local P = {}

--- 计算 index 之前，所有 /字母序列 的总字符长度（补码）
--- @param str string  原始字符串
--- @param index number  截止位置（不含）
--- @return number  补码总长度
local function count_slash_complement(str, index)
    -- 截取 index 之前的子串
    local sub = str:sub(1, index - 1)

    local total = 0
    -- 匹配 / 后跟一个或多个字母的模式
    for match in sub:gmatch("/[%a]+") do
        total = total + #match
    end

    return total
end

function P.func(key, env)
    local engine = env.engine
    local key_value = key:repr()
    local context = engine.context
    local composition = context.composition
    if composition:empty() then return 2 end

    local input_syllable_code = "-"
    local raw_input = context.input
    local preedit_text = context:get_preedit().text

    if (preedit_text and rime_api.regex_match(raw_input, "^[a-z/]{4, 66}'$")) then
        local editing_preedit = preedit_text:match("[a-z/' ]+")

        local parts = {}
        for encode_segment in editing_preedit:gmatch("[^ ]+") do
            -- 每段：取开头两字符 + 斜杠后的字母（含斜杠），末尾分号除外
            local core = encode_segment:match("^[^']+") or "" -- 先去掉末尾可能的 '

            local head = core:sub(1, 2)                       -- 开头两个字符
            local slash_part = core:match("/[%a]+") or ""     -- 斜杠+字母部分

            table.insert(parts, head .. slash_part)
        end

        input_syllable_code = table.concat(parts, " ")

        -- 末尾分号拼接
        local tail = editing_preedit:match("'$") or ""
        input_syllable_code = input_syllable_code .. tail
    end

    local segment = composition:toSegmentation()
    local current_start_pos = segment:get_current_start_position()
    if rime_api.regex_match(input_syllable_code, "^[a-z/ ]{5, 66}'$") then
        if key_value:match("^[a-z]$") then
            local idx_s, idx_e = (" " .. input_syllable_code):find(" " .. key_value .. "[a-z]")
            if (not idx_s) or (not idx_e) then return 2 end
            local slash_code_len = count_slash_complement(input_syllable_code, idx_s) or 0
            local new_pos = idx_s - ((idx_e - slash_code_len) / 3)
            if current_start_pos < 1 then
                context.caret_pos = math.floor(new_pos)
            else
                context.caret_pos = current_start_pos + math.floor(new_pos)
            end
        elseif key_value:match("^Shift%+[A-Z]$") == key_value then
            local lookup_char = key_value:sub(-1):lower()
            local idx_s, idx_e = string.rfind(input_syllable_code, " " .. lookup_char)
            if (not idx_s) then return 2 end
            local slash_code_len = count_slash_complement(input_syllable_code, idx_s) or 0
            local new_pos = idx_s - ((idx_s - slash_code_len) / 3)
            if current_start_pos < 1 then
                context.caret_pos = math.floor(new_pos)
            else
                context.caret_pos = current_start_pos + math.floor(new_pos)
            end
        else
            return 2 -- kNoop
        end
        -- env.engine:process_key(KeyEvent("space"))
        return 1 -- kAccept
    end

    return 2 -- kNoop
end

return P
