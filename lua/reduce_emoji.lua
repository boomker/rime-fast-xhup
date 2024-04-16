local reduce_emoji = {}

function reduce_emoji.func(input, env)
    local engine = env.engine
    local config = engine.schema.config
    local normal_cands = {}
    local emoji_cands = {}
    local other_cands = {}
    local prev_cand_text = ""
    local emoji_pos = config:get_int("emoji_reduce_config/idx") or 6
    local top_emoji_cnt = 0
    local top_cand_cnt = 0
    local opencc_emoji = Opencc("emoji.json")
    local preedit_code = env.engine.context:get_commit_text():gsub(" ", "")

    for cand in input:iter() do
        local cand_text = cand.text:gsub(" ", "")

        if
            (top_cand_cnt <= (emoji_pos + 1))
            and (cand:get_dynamic_type() == "Shadow")
            and not
            (
                preedit_code:match("^ok$") or preedit_code:match("^/")
                or cand_text:find("([\228-\233][\128-\191]-)")
                or cand.comment:match("history")
            )
        then
            table.insert(emoji_cands, { prev_cand_text, cand })
            if top_cand_cnt == (emoji_pos - 1) then
                top_emoji_cnt = #emoji_cands
            end
        elseif (top_cand_cnt <= (emoji_pos + 1)) then
            local emoji_tab = opencc_emoji:convert_word(cand_text) or { cand_text }
            for _, emoji_txt in ipairs(emoji_tab) do
                if #emoji_tab > 1 and emoji_txt == cand_text then
                    prev_cand_text = cand_text
                end
            end
            table.insert(normal_cands, cand)
            top_cand_cnt = top_cand_cnt + 1
            if top_cand_cnt == (emoji_pos - 1) then
                top_emoji_cnt = #emoji_cands
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
