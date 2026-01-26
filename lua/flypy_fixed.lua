local F = {}

function F.init(env)
    local config = env.engine.schema.config
    env.top_mark = config:get_string("pin_word/comment_mark") or " ᵀᴼᴾ"
    env.custom_mark = config:get_string("custom_phrase/comment_mark") or " 📌"
end

function F.func(input, env)
    local seglen = 0
    local drop_cand = false
    local context = env.engine.context
    local composition = context.composition

    if composition:empty() then return end
    local segment = composition:back()
    seglen = segment and segment.length
    local preedit_code = context.input
    local _, symbol_count = preedit_code:gsub("[`']", "")
    local syllable_len = (seglen > 1) and math.ceil(seglen / 2) or (#preedit_code - symbol_count)

    for cand in input:iter() do
        local cand_type = cand.type
        local cand_text = cand.text:gsub(" ", "")
        local cand_text_len = utf8.len(cand_text)
        local cand_dtype = cand:get_dynamic_type()

        if cand.comment:match(env.top_mark) then
            yield(cand)                                  -- 带有 top_mark 标记的候选词条, 优先显示
        elseif cand_text:match("<br>") then
            local br_text = cand_text:gsub("<br>", "\n") -- 词条有<br>标签, 将其转为换行符
            yield(cand:to_shadow_candidate(cand_type, br_text, env.custom_mark))
        elseif                                           -- 丢弃一些候选结果
            (                                            -- 多个大小写的输入编码, 去掉只有单字母的候选
                cand_text:match("^[a-zA-Z]$") and preedit_code:match("^%a%a+")
            ) or ( -- 'github' --> 'xx18'
                cand_text:match("[%d%p]") and preedit_code:match("^%l+$")
                and (cand_type ~= "fuzzy_word") and (cand_dtype == "Sentence")
            ) or ( -- 'qphr' --> '000'
                cand_text:match("^[%d%p]+$") and preedit_code:match("^%l+$")
            ) or ( -- 'nL' --> '你L'
                cand_text:match("[A-Z]$") and preedit_code:match("^%l%u$") and
                cand_text:find("([\228-\233][\128-\191]-)")
            ) or ( -- 辅码筛字时, 过滤掉 emoji
                (cand_dtype == "Shadow") and preedit_code:match("%l+[`/][%l`/]+$")
            ) or ( -- 辅码模式下, 过滤掉长度超出音节长度的候选
                (cand_text_len > syllable_len) and preedit_code:match("%l+[`/][%l`/]+$")
            ) or ( -- 单个英文候选词长度少于 3 个字母的候选
                (cand_text_len < 3) and cand_text:match("^%l+$") and preedit_code:match("^%l+$")
            ) or ( -- 单个英文候选词长度超出编码长度 3 个以上的候选
                preedit_code:match("^[%u%l]%l*$") and cand_text:match("^[%a%p]+$") and
                (cand_text_len - #preedit_code > 3)
            ) or ( -- 单个中文候选词长度超出音节长度 1 个以上的候选
                (cand_type == "completion") and (cand_text_len - syllable_len > 1) and
                cand_text:find("([\228-\233][\128-\191]-)")
            )
        then
            drop_cand = true
        else
            yield(cand)
        end
    end

    if drop_cand then drop_cand = false end
end

return F
