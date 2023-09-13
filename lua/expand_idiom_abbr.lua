-- local puts = require("tools/debugtool")
require("tools/metatable")
local expand_idiom_abbr = {}
local idiom_cands = {}

function expand_idiom_abbr.processor(key, env)
    local engine = env.engine
    local context = engine.context
    local pos = context.caret_pos
    local input_code = context.input
    local preedit_code_length = #input_code

    if ((table.find({3, 4}, preedit_code_length)) and (table.find({3, 4}, pos))
        and (key:repr() == "slash")) then
        idiom_cands = {}
        local composition = context.composition
        if (not composition:empty()) then
            local segment = composition:back()
            for i = 1, 30, 1 do
                local fchar_cand = segment:get_candidate_at(i)
                if not fchar_cand then return 2 end
                local fchar_cand_text = fchar_cand.text
                local cand_length = utf8.len(fchar_cand_text)
                if (table.find({3, 4}, cand_length)) then
                    table.insert(idiom_cands, fchar_cand_text)
                end
            end
        end
    end

    return 2 -- kNoop
end


function expand_idiom_abbr.translator(input, seg, env)
    local context = env.engine.context
    local pos = context.caret_pos
    if #idiom_cands < 1 then return end
    -- 四码四字词, 按下'/'时, 长词优先
    if string.match(input, '^%l+%/$') and (table.find({4, 5}, #input))
        and (table.find({4, 5}, pos)) then
        for _, val in ipairs(idiom_cands) do
            local cand = Candidate("idiom", seg.start, seg._end, val, "")
            yield(cand)
        end
    end
end
return expand_idiom_abbr
