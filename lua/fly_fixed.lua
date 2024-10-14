require("tools/string")
local F = {}

function F.init(env)
    local config = env.engine.schema.config
    local schema_id = config:get_string("translator/dictionary")
    env.reversedb = ReverseLookup(schema_id)
    env.pin_mark = config:get_string("pin_word/comment_mark") or "🔝"
    env.custom_mark = config:get_string("custom_phrase/comment_mark") or " 📌"
end

function F.func(input, env)
    local drop_cand = false
    local cmp_cand_count = 0
    local low_priority_cands = {}
    local reversedb = env.reversedb
    local context = env.engine.context
    local preedit_code = context.input
    local _, symbol_count = preedit_code:gsub("[`']", "")
    local _syllable_count = math.floor(#preedit_code / 2)
    local confirmed_syllable_len = _syllable_count - symbol_count
    for cand in input:iter() do
        local cand_text = cand.text:gsub(" ", "")
        local cand_type = cand:get_dynamic_type()
        local _, sp_count = cand.preedit:gsub(" ", "")

        if cand.comment:match("^" .. env.pin_mark .. "$") then
            -- 带有 pin_mark 标记的候选词条, 优先显示
            yield(cand)
        elseif cand_text:match("<br>") then
             -- 词条有<br>标签, 将其转为换行符
            local ccand_text = cand_text:gsub("<br>", "\n")
            yield(Candidate(cand.type, cand.start, cand._end, ccand_text, env.custom_mark))
        elseif  -- 丢弃一些候选结果
                -- 去掉候选注解包含`太极️`的候选项
            string.find(cand.comment, "☯")
            or (   -- 开头大写的输入编码, 去掉只有单字母的候选
                preedit_code:match("^[%u][%a]+")
                and cand_text:match("^[A-Z]$")
            ) or ( -- 辅码筛字时, 过滤掉 emoji
                preedit_code:match("^%l+[`/][%l`/]*$")
                and (cand:get_dynamic_type() == "Shadow")
            ) or ( -- 辅码模式下, 过滤掉长度超出预确认音节长度的候选
                preedit_code:match("^%l+`%l+") and
                (cand_text:utf8_len() > confirmed_syllable_len)
            ) or ( -- V模式下, 过滤掉中英混合词条
                preedit_code:match("^%u%a+$") and
                cand_text:find("([\228-\233][\128-\191]-)")
            ) or ( -- 候选词长度超出预确认音节长度 2 个以上的候选
                (cand.type == "completion") and
                (not cand_text:match("[%a%p]")) and
                (utf8.len(cand_text) - confirmed_syllable_len > 2)
            )
        then
            drop_cand = true
        elseif preedit_code:match("^%l+`%l+") and cand.comment:match("^~[ %l]+") then
            -- 辅码模式下, 覆写注解(太长了)为空
            yield(Candidate(cand.type, cand.start, cand._end, cand_text, ""))
        elseif -- 候选词长度超出预确认音节长度 1 个以上的候选, 保留2个
            (cand.type == "completion") and
            (not cand_text:match("[%a%p]")) and
            (utf8.len(cand_text) - confirmed_syllable_len > 1)
        then
            cmp_cand_count = cmp_cand_count + 1
            if cmp_cand_count >= 3 then
                drop_cand = true
            else
                yield(cand)
            end
        -- [[ 如果你没有用超级简拼, 下面这些都可以注释掉
        elseif
            -- 将超级简拼产生的候选结果降频, 置于最后输出
            (cand_type ~= "Shadow")
            and (not preedit_code:match("%p"))
            and (not cand_text:match("[%a%p]"))
            and (not cand.type:match("user_table"))
            and (utf8.len(cand_text) < #preedit_code)
            and (sp_count >= 1) and (#preedit_code % 2 ~= 0)
        then
            local first_char = cand_text:utf8_sub(1, 1)
            local last_char = cand_text:utf8_sub(-1, -1)
            local first_syllable_code = preedit_code:sub(1, 2)
            local preedit_last_code = preedit_code:sub(-1, -1)
            local first_char_ycode = reversedb:lookup(first_char):gsub("%[%l%l", "")
            local last_char_ycode = reversedb:lookup(last_char):gsub("%l%[%l%l", "")
            if last_char_ycode and first_char_ycode
                and last_char_ycode:match(preedit_last_code)
                and first_char_ycode:match(first_syllable_code)
            then
                yield(cand)
            elseif last_char_ycode
                and (cand.preedit:find(" ") % 2 ~= 0 )
                and last_char_ycode:match(preedit_last_code)
            then
                yield(cand)
            else
                table.insert(low_priority_cands, cand)
            end
            -- 如果你没有启用超级简拼, 上面这些都可以注释掉 ]]
        else
            yield(cand)
        end

        if #low_priority_cands >= 150 then break end
    end

    if drop_cand then drop_cand = false end
    for _, cand in ipairs(low_priority_cands) do yield(cand) end
end

return F
