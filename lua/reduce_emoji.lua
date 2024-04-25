local reduce_emoji = {}

function reduce_emoji.func(input, env)
    local engine = env.engine
    local config = engine.schema.config
    local normal_cands = {}
    local emoji_cands = {}
    local other_cands = {}
    local prev_cand_text = ""
    local top_cand_cnt = 0
    local top_emoji_cnt = 0
    local emoji_pos = config:get_int("emoji_reduce_config/idx") or 6
    local opencc_emoji = Opencc("emoji.json")
    local preedit_code = env.engine.context:get_commit_text():gsub(" ", "")

    for cand in input:iter() do
        local cand_text = cand.text:gsub(" ", "")

        if
            (top_cand_cnt <= emoji_pos)
            and (cand.type ~= "user_table")
            and (cand:get_dynamic_type() == "Shadow")
            and not
            (
                preedit_code:match("^/")
                or (
                    cand_text:match("^[%a]")
                    and (cand_text:match("[%a]+"):len() > 3)
                    and cand_text:find("([\228-\233][\128-\191]-)")
                )
            )
        then
            local wechatFlg = env.engine.context:get_option("wechat_flag")
            if wechatFlg then
                table.insert(emoji_cands, { prev_cand_text, cand })
            else
                if not cand_text:match("%]$") then
                    table.insert(emoji_cands, { prev_cand_text, cand })
                end
            end
            if top_cand_cnt == (emoji_pos - 1) then
                top_emoji_cnt = #emoji_cands
            end
        elseif (top_cand_cnt <= emoji_pos) then
            table.insert(normal_cands, cand)
            top_cand_cnt = top_cand_cnt + 1
            if top_cand_cnt == (emoji_pos - 1) then
                top_emoji_cnt = #emoji_cands
            end
            local emoji_tab = opencc_emoji:convert_word(cand_text) or { cand_text }
            if (#emoji_tab > 1) and (emoji_tab[1] == cand_text) then
                prev_cand_text = cand_text
            end
        else
            table.insert(other_cands, cand)
        end
    end

    local emoij_yield_done = false
    for _, normal_cand in ipairs(normal_cands) do
        if (emoji_pos == 1) and (#emoji_cands > 0) and (top_emoji_cnt > 0) then
            local i = 0
            for _, emoji_cand_item in ipairs(emoji_cands) do
                yield(
                    ShadowCandidate(
                        emoji_cand_item[2],
                        emoji_cand_item[2].type,
                        emoji_cand_item[2].text,
                        emoji_cand_item[1]
                    )
                )
                i = i + 1
                if i == #emoji_cands then
                    emoij_yield_done = true
                end
                if i == top_emoji_cnt then
                    break
                end
            end
        end
        emoji_pos = emoji_pos - 1
        yield(normal_cand)
        if (#emoji_cands == 1) and (emoji_pos < 1) then
            yield(
                ShadowCandidate(
                    emoji_cands[1][2],
                    emoji_cands[1][2].type,
                    emoji_cands[1][2].text,
                    emoji_cands[1][1]
                )
            )
            emoij_yield_done = true
        end
    end

    if (#emoji_cands > 0) and (not emoij_yield_done) then
        for _, emoji_cand_item in ipairs(emoji_cands) do
            yield(
                ShadowCandidate(
                    emoji_cand_item[2],
                    emoji_cand_item[2].type,
                    emoji_cand_item[2].text,
                    emoji_cand_item[1]
                )
            )
        end
    end

    for _, cand in ipairs(other_cands) do
        yield(cand)
    end
end

return {
    filter = reduce_emoji.func,
}
