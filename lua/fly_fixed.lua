require("tools/string")
local F = {}

local function last_character(s)
    return string.utf8_sub(s, -1, -1)
end

function F.init(env)
    local config = env.engine.schema.config
    local schema_id = config:get_string("translator/dictionary")
    env.reversedb = ReverseLookup(schema_id)
    env.pin_mark = config:get_string("pin_word/comment_mark") or "🔝"
end

function F.func(input, env)
    local cand_drop = false
    local cmp_cand_count = 0
    local rdb = env.reversedb
    local low_priority_texts = {}
    local low_priority_cands = {}
    local context = env.engine.context
    local preedit_code = context.input:gsub(" ", "")
    local confirmed_syllable_len = math.floor(#preedit_code / 2)
    for cand in input:iter() do
        local cand_type = cand:get_dynamic_type()
        local cand_text = cand.text:gsub(" ", "")
        local cand_comment = cand.comment:gsub("[〔〕]", "")
        if                          -- 丢弃一些候选结果
            cand_text:match("<br>") -- 去除'<br>'重复候选
            -- 开头大写的预编辑编码, 去掉只有单字母的候选
            or (
                preedit_code:match("^[%u][%a]+")
                and cand_text:match("^[A-Z]$")
            ) or (
            -- 辅码筛字时, 过滤掉 emoji
                preedit_code:match("^%l+[%[`]%l?%l?$")
                and (cand:get_dynamic_type() == "Shadow")
            ) or (
            -- V模式下, 过滤掉中英混合词条
                preedit_code:match("^[%u][%a]+$") and
                cand_text:find("([\228-\233][\128-\191]-)")
            ) or (
            -- 候选词长度超出预确认音节长度 2 个以上的候选
                (cand.type == "completion") and
                (not preedit_code:match("%p")) and
                (not cand_text:match("[%a%p]")) and
                (utf8.len(cand_text) - confirmed_syllable_len > 2)
            -- 候选词是 不匹配的 Emoji 时则丢弃
            ) or (table.find_index(low_priority_texts, cand_comment))
        then
            cand_drop = true
        elseif -- 候选词长度超出预确认音节长度 1 个以上的候选
            (cand.type == "completion") and
            (not preedit_code:match("%p")) and
            (not cand_text:match("[%a%p]")) and
            (utf8.len(cand_text) - confirmed_syllable_len > 1)
        then
            cmp_cand_count = cmp_cand_count + 1
            if cmp_cand_count >= 3 then
                cand_drop = true
            else
                yield(cand)
            end
        elseif -- 将非原始小鹤双拼编码规则产生的候选词条结果降频, 置于最后输出
            (cand.type ~= "user_table")
            and (cand_type ~= "Shadow")
            and (not preedit_code:match("%p"))
            and (not cand_text:match("[%a%p]"))
            and (utf8.len(cand_text) <= #preedit_code)
            and (utf8.len(cand_text) >= confirmed_syllable_len)
            and ((#preedit_code % 2 ~= 0) and (#preedit_code <= 7))
            and (not cand.comment:match("^" .. env.pin_mark .. "$"))
        then
            local last_char = last_character(cand_text)
            local preedit_last_code = preedit_code:sub(-1, -1)
            local yin_code = rdb:lookup(last_char):gsub("%l%[%l%l", "")
            if yin_code and (yin_code:match(preedit_last_code)) then
                yield(cand)
            else
                table.insert(low_priority_cands, cand)
                table.insert(low_priority_texts, cand.text)
            end
        else
            yield(cand)
        end

        if #low_priority_cands >= 100 then break end
    end

    if cand_drop then cand_drop = false end
    for _, cand in ipairs(low_priority_cands) do yield(cand) end
    -- GC
    -- collectgarbage()
end

return F
