local reduce_emoji = {}

function reduce_emoji.init(env)
    local config = env.engine.schema.config
    env.emoji_pos = config:get_int("emoji_reduce/idx") or 6
end

function reduce_emoji.func(input, env)
    local engine = env.engine
    local config = engine.schema.config
    local emoji_cands = {}
    local other_cands = {}
    local top_cand_cnt = 0
    local emoji_toggle = engine.context:get_option("emoji")
    local preedit_code = engine.context.input:gsub(" ", "")
    local pin_mark = config:get_string("pin_word/comment_mark") or "🔝"

    for cand in input:iter() do
        if (top_cand_cnt <= env.emoji_pos) then
            if
                emoji_toggle
                and (cand:get_dynamic_type() == "Shadow")
                and (not preedit_code:match("[%[`]%l?%l?$"))
                and (not cand.comment:match(pin_mark))
                and (not (
                    cand.text:find("([\228-\233][\128-\191]-)")
                    and (cand.text:lower():match("^" .. preedit_code))
                ))
            then
                table.insert(emoji_cands, cand)
            elseif (cand:get_dynamic_type() == "Shadow")
                and (
                    cand.comment:match(pin_mark) or (
                        cand.text:find("([\228-\233][\128-\191]-)")
                        and (cand.text:lower():match("^" .. preedit_code))
                    )
                )
            then
                yield(cand)
            elseif (cand:get_dynamic_type() ~= "Shadow") then
                yield(cand)
            end
            top_cand_cnt = top_cand_cnt + 1
        else
            table.insert(other_cands, cand)
        end
    end

    for _, emoji_cand in ipairs(emoji_cands) do
        local wechatFlg = env.engine.context:get_option("wechat_flag")
        local cand_text = emoji_cand.text
        if wechatFlg then
            yield(emoji_cand)
        elseif not cand_text:match("^%[.*%]$") then
            yield(emoji_cand)
        end
    end

    for _, cand in ipairs(other_cands) do
        yield(cand)
    end
end

return {
    filter = { init = reduce_emoji.init, func = reduce_emoji.func },
}
