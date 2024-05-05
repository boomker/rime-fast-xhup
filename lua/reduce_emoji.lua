local reduce_emoji = {}

function reduce_emoji.init(env)
    local config = env.engine.schema.config
    env.emoji_pos = config:get_int("emoji_reduce/idx") or 6
end

function reduce_emoji.func(input, env)
    local engine = env.engine
    local emoji_cands = {}
    local other_cands = {}
    local top_cand_cnt = 0
    local emoji_toggle = engine.context:get_option("emoji")

    for cand in input:iter() do
        if (top_cand_cnt <= env.emoji_pos) then
            if ((cand:get_dynamic_type() == "Shadow") and emoji_toggle)
            then
                table.insert(emoji_cands, cand)
            else
                yield(cand)
            end
            top_cand_cnt = top_cand_cnt + 1
            --[[
                -- env.opencc_emoji = Opencc("emoji.json")
                -- emoji_tab = env.opencc_emoji:convert_word(cand_text) or { cand_text }

                -- if (#emoji_tab > 1) and (emoji_tab[1] == cand_text) then
                --     for _i, value in pairs(emoji_tab) do
                --         table.insert(emoji_cands, { value, cand })
                --     end
                -- end
            --]]
        else
            table.insert(other_cands, cand)
        end
    end

    for _, emoji_cand in ipairs(emoji_cands) do
        local wechatFlg = env.engine.context:get_option("wechat_flag")
        if wechatFlg then
            yield(emoji_cand)
            --[[
            -- yield(
            --     ShadowCandidate(
            --         emoji_cand_item[2],
            --         emoji_cand_item[2].type,
            --         emoji_cand_item[1],     -- text
            --         emoji_cand_item[2].text -- comment
            --     )
            -- )
            --]]
        else
            local cand_text = emoji_cand.text
            if (not cand_text:match("^%[.*%]$")) then
                yield(emoji_cand)
                --[[
                -- yield(
                --     ShadowCandidate(
                --         emoji_cand_item[2],
                --         emoji_cand_item[2].type,
                --         emoji_cand_item[1],
                --         emoji_cand_item[2].text
                --     )
                -- )
                --]]
            end
        end
    end

    for _, cand in ipairs(other_cands) do
        yield(cand)
    end
end

return {
    filter = { init = reduce_emoji.init, func = reduce_emoji.func },
}
