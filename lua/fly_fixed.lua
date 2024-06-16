require("tools/string")
local F = {}

local function last_character(s)
    return string.utf8_sub(s, -1, -1)
end

function F.init(env)
    local config = env.engine.schema.config
    env.pin_mark = config:get_string("pin_word/comment_mark") or "🔝"
    local schema_id = config:get_string("translator/dictionary") -- 多方案共用字典取主方案名称
    env.reversedb = ReverseLookup(schema_id)
end

function F.func(input, env)
    local cands = {}
    local cand_drop = false
    local context = env.engine.context
    local preedit_code = context.input:gsub(" ", "")
    for cand in input:iter() do
        local cand_text = cand.text:gsub(" ", "")
        if -- 将非原始小鹤双拼编码规则产生的候选词条结果降频, 置于最后输出
            (cand.type ~= "user_table")
            and (not cand_text:match("[a-zA-Z]"))
            and (not preedit_code:match("[%u%p]"))
            and (not cand:get_dynamic_type() == "Shadow")
            and (string.utf8_len(cand_text) <= #preedit_code)
            and ((#preedit_code % 2 ~= 0) and (#preedit_code <= 7))
            and (not cand.comment:match("^" .. env.pin_mark .. "$"))
        then
            local last_char = last_character(cand_text)
            local yin_code = env.reversedb:lookup(last_char):gsub("%l%[%l%l", "")
            local preedit_last_code = preedit_code:sub(-1, -1)
            if yin_code and (yin_code:match(preedit_last_code)) then
                yield(cand)
            else
                table.insert(cands, cand)
            end
        elseif cand_text:match("<br>") then -- 词条有<br>标签, 将其转为换行符
            local candTxt = cand_text:gsub("<br>", "\r\t")
            yield(Candidate("word", cand.start, cand._end, candTxt, ""))
        elseif -- 丢弃一些候选结果
            -- 开头大写的预编辑编码, 去掉只有单字母的候选
            (preedit_code:match("^[%u][%a]+") and cand_text:match("^[A-Z]$"))
            or (
            -- V模式下, 过滤掉中英混合词条
                preedit_code:match("^[%u][%a]+$")
                and cand_text:find("([\228-\233][\128-\191]-)")
            ) or (
            -- 辅码筛字时, 过滤掉 emoji
                preedit_code:match("^%l+[%[`]%l?%l?$")
                and (cand:get_dynamic_type() == "Shadow")
            ) or (
            -- 候选词长度大于预编辑长度
                (cand.type == "completion") and
                (not cand_text:match("[%a%p]")) and
                (string.utf8_len(cand_text) - #preedit_code > 1)
            )
        then
            cand_drop = true
        else
            yield(cand)
        end

        if #cands >= 100 then break end
    end

    for _, cand in ipairs(cands) do yield(cand) end
    -- GC
    if cand_drop then
        collectgarbage()
        cand_drop = false
    end
end

return F
