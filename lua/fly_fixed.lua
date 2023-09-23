-- local puts = require("tools/debugtool")
require("tools.string")

local function last_character(s) return string.utf8_sub(s, -1, -1) end

local function fly_fixed(input, env)
    local cands        = {}
    local config       = env.engine.schema.config
    local schema_id    = config:get_string("translator/dictionary") -- 多方案共用字典取主方案名称
    local reversedb    = ReverseLookup(schema_id)
    local preedit_code = env.engine.context:get_commit_text()
    for cand in input:iter() do
        local cand_text_code = tonumber(utf8.codepoint(cand.text, 1))
        local yin_code, preedit_last_code = nil, nil
        if (19968 <= cand_text_code) then
            local last_char = last_character(cand.text)
            yin_code = reversedb:lookup(last_char):sub(1, 1)
            preedit_last_code = preedit_code:sub(-1, -1)
        end
        if (string.match(preedit_code, '^.+[andefwosr]$') or string.match(preedit_code, '^[andefwsr]$')) and
            (#preedit_code % 2 ~= 0) and (yin_code ~= preedit_last_code) then
            table.insert(cands, cand)
        else
            yield(cand)
        end

        if #cands > 50 then break end
    end

    for _, cand in ipairs(cands) do yield(cand) end
end

return { filter = fly_fixed }
