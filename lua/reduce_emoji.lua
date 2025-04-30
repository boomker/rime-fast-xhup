local F = {}

function F.init(env)
    local engine = env.engine
    local config = engine.schema.config
    env.emoji_pos = config:get_int("emoji_reduce/index") or 6
    env.pin_mark = config:get_string("pin_word/comment_mark") or " 🔝"
end

function F.func(input, env)
    local emoji_cands = {}
    local other_cands = {}
    local top_cand_count = 0
    local engine = env.engine
    local preedit_code = engine.context.input:gsub(" ", "")
    local emoji_toggle = engine.context:get_option("emoji")
    local wechat_flag = engine.context:get_option("wechat_flag")

    for cand in input:iter() do
        if top_cand_count <= env.emoji_pos then
            if cand.comment:match(env.pin_mark) then
                yield(cand)
            elseif preedit_code:match("^%u%a+") then
                yield(cand)
            elseif
                emoji_toggle
                and (cand:get_dynamic_type() == "Shadow")
                and (not preedit_code:match("^[%l%`]+[`/][%l`/]*$"))
            then
                table.insert(emoji_cands, cand)
            else
                yield(cand)
            end
            top_cand_count = top_cand_count + 1
        else
            table.insert(other_cands, cand)
        end
        if #other_cands >= 150 then break end
    end

    for _, emoji_cand in ipairs(emoji_cands) do
        local cand_text = emoji_cand.text
        if wechat_flag then
            yield(emoji_cand)
        elseif not cand_text:match("^%[.*%]$") then
            yield(emoji_cand)
        end
    end

    for _, cand in ipairs(other_cands) do
        local cand_text = cand.text
        if wechat_flag then
            yield(cand)
        elseif not cand_text:match("^%[.*%]$") then
            yield(cand)
        end
    end
end

return F
