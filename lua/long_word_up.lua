local reload_env = require("tools/env_api")
local long_word_up = {}

function long_word_up.init(env)
    reload_env(env)
    local config = env.engine.schema.config
    env.excluded_codes = env:Config_get("long_word_up/excluded_codes")
    env.pin_mark = config:get_string("pin_word/comment_mark") or "🔝"
end

function long_word_up.func(input, env)
    local engine = env.engine
    local context = engine.context
    local config = engine.schema.config

    local cands = {}
    local other_cands = {}
    -- 记录第一个候选词的长度，提前的候选词至少要比第一个候选词长
    local prev_word_length = 0
    -- 记录筛选了多少个汉语词条(只提升1个词的权重)
    local pickup_count = 1
    local idx = config:get_int("long_word_up/idx") or 3

    local preedit_code = context.input:gsub(" ", "")
    local preedit_length = preedit_code:len()
    local preedit_script_length = ((preedit_length % 2) == 0)
        and preedit_length or (preedit_length - 1)
    local preedit_expand_flag = preedit_code:match("%l'%l'%l'$")

    for cand in input:iter() do
        local cand_text = cand.text:gsub(" ", "")
        local cand_text_length = utf8.len(cand_text)
        local cand_predict_max_length = cand_text:match("%a")
            and (preedit_length + 4) or ((preedit_script_length // 2) + 2)

        if (idx > 1) and ((cand.type == "user_table")
                or preedit_expand_flag
                or preedit_code:match("^/")
                or cand.comment:match(env.pin_mark)
                or (
                    (cand_text_length <= cand_predict_max_length)
                    and (preedit_length / cand_text_length <= 2)
                )
                or (table.find_index(env.excluded_codes, preedit_code))
            )
        then
            yield(cand)
            idx = idx - 1
            prev_word_length = cand_text_length or 0
        elseif
            (pickup_count >= 1)
            and (preedit_length > 3)
            and (cand_text_length >= 3)
            and (cand.comment:len() < 3)
            and (not cand_text:match("%a"))
            and (not preedit_code:match("^/"))
            and (cand:get_dynamic_type() ~= "Shadow")
            and (cand_text_length > prev_word_length)
            and (cand_text_length <= cand_predict_max_length)
        then
            yield(cand)
            pickup_count = pickup_count - 1
        else
            if preedit_expand_flag or (cand.quality > 9) then
                table.insert(cands, cand)
            else
                table.insert(other_cands, cand)
            end
        end

        if #cands >= 80 then break end
    end

    for _, cand in ipairs(cands) do yield(cand) end

    for _, long_cand in ipairs(other_cands) do
        yield(long_cand)
    end
end

return { filter = { init = long_word_up.init, func = long_word_up.func } }
