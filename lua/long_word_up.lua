---@diagnostic disable: undefined-global
-- local puts = require("tools/debugtool")
local function long_word_up(input, env)
    local cands = {}
    local longWord_cands = {}
    -- 记录第一个候选词的长度，提前的候选词至少要比第一个候选词长
    local prev_word_length = 0
    -- 记录筛选了多少个汉语词条(只提升1个词的权重)
    local count = 1
    local pickup_count = 0
    local idx = 0
    -- local second_cand_quality = 0
    local preedit_code = env.engine.context:get_commit_text()
    for cand in input:iter() do
        local cand_length = utf8.len(cand.text)
        -- local cand_per_quality = cand.quality
        local cand_text_code = tonumber(utf8.codepoint(cand.text, 1))
        if (cand.quality > 9) or (idx <= 1) then
            prev_word_length = cand_length or 0
            idx = idx + 1
            yield(cand)
        elseif (cand_length > prev_word_length) and (cand_length >= 3) and
            (pickup_count < count) and (string.len(preedit_code) > 2) and
            ((19968 <= cand_text_code) and (cand_text_code <= 117777)) then
            yield(cand)
            pickup_count = pickup_count + 1
        else
            if ((utf8.len(cand.text) / #preedit_code) <= 1.5) or (cand.quality > 9) then
                table.insert(cands, cand)
            else
                table.insert(longWord_cands, cand)
            end
        end

        if #cands > 50 then break end
    end

    for _, cand in ipairs(cands) do yield(cand) end
    for _, long_cand in ipairs(longWord_cands) do yield(long_cand) end
end

return {filter = long_word_up}
