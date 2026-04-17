local F = {}

function F.init(env)
    local config = env.engine.schema.config
    env.top_mark = config:get_string("pin_word/comment_mark") or " ᵀᴼᴾ"
    env.custom_mark = config:get_string("custom_phrase/comment_mark") or " 📌"
end

function F.func(input, env)
    local drop_cand = false
    local context = env.engine.context
    local composition = context.composition
    if composition:empty() then return end

    local too_long_cand_list = {}
    local segment = composition:back()
    local raw_input_code = context.input
    local segment_len = segment and segment.length or 0
    local _, symbol_count = raw_input_code:gsub("[`']", "")
    local cand_limit_length = (#raw_input_code > 3) and #raw_input_code or 3
    local syllable_len = (segment_len > 1) and math.ceil(segment_len / 2) or (#raw_input_code - symbol_count)

    for cand in input:iter() do
        local cand_type = cand.type
        local cand_text = cand.text
        local cand_text_len = utf8.len(cand_text)
        local cand_dtype = cand:get_dynamic_type()

        if cand.comment:match(env.top_mark) then
            yield(cand)                                  -- 带有 top_mark 标记的候选词条, 优先显示
        elseif cand_text:match("<br>") then
            local br_text = cand_text:gsub("<br>", "\n") -- 词条有<br>标签, 将其转为换行符
            yield(cand:to_shadow_candidate(cand_type, br_text, env.custom_mark))
        elseif                                           -- 丢弃一些候选结果
            (                                            -- 多个大小写的输入编码, 去掉只有单字母的候选
                cand_text:match("^[a-zA-Z]$") and raw_input_code:match("^%a%a+")
            ) or (                                       -- 'github' --> 'xx18'
                (cand_type ~= "fuzzy_word") and (cand_dtype == "Sentence") and
                cand_text:find("[%d%p]") and raw_input_code:match("^[%l%p]+$")
            ) or ( -- 'qphr' --> '000', 'uw' --> '15'
                cand_text:match("^[0-9]+") and raw_input_code:match("^%a[a-z`]+$")
            ) or ( -- 间接辅码筛字时, 过滤掉 emoji
                (cand_dtype == "Shadow") and raw_input_code:match("%l+[`/][%l`/]+$")
            ) or ( -- 单个英文候选词长度少于 4 个字母的候选
                cand_text:match("^%l?%l?%l?$") and raw_input_code:match("^%l+$")
            ) or ( -- 单个中文候选词长度超出音节长度 1 个以上的候选
                (cand_type == "completion") and (cand_text_len - syllable_len > 1) and
                (not cand_text:find("[a-zA-Z]")) and cand_text:find("([\228-\233][\128-\191]-)")
            )
        then
            drop_cand = true
        elseif -- 单个英文候选词长度超出编码长度一倍以上的候选
            (cand_text_len - #raw_input_code >= cand_limit_length) and
            cand_text:match("^[%a%p%s]+$") and raw_input_code:match("^%a%a%l*$")
        then
            table.insert(too_long_cand_list, cand)
        else
            yield(cand)
        end
    end
    for _, cand in ipairs(too_long_cand_list) do yield(cand) end

    if drop_cand then drop_cand = false end
end

function F.tags_match(seg, env)
    if seg.tags["abc"] or seg.tags["make_sentence"] then return true end
    return false
end

return F
