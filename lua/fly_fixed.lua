require("tools/string")
local fly_fixed = {}

local function last_character(s)
    return string.utf8_sub(s, -1, -1)
end

function fly_fixed.init(env)
    local config = env.engine.schema.config
    env.pin_mark = config:get_string("pin_word/comment_mark") or "🔝"
    local schema_id = config:get_string("translator/dictionary") -- 多方案共用字典取主方案名称
    env.reversedb = ReverseLookup(schema_id)
end

function fly_fixed.func(input, env)
    local cands = {}
    local prev_cand_ok = true
    local preedit_code = env.engine.context:get_commit_text():gsub(" ", "")
    for cand in input:iter() do
        local cand_text = cand.text:gsub(" ", "")
        if
            (cand.type ~= "user_table")
            and (cand:get_dynamic_type() ~= "Shadow")
            and (not cand_text:match("[a-zA-Z]"))
            and (not preedit_code:match("[%u%p]"))
            and (not cand.comment:match("^" .. env.pin_mark .. "$"))
            and ((#preedit_code % 2 ~= 0) and (#preedit_code <= 7))
        then
            local last_char = last_character(cand_text)
            local yin_code = env.reversedb:lookup(last_char):gsub("%l%[%l%l", "")
            local preedit_last_code = preedit_code:sub(-1, -1)
            if yin_code and (yin_code:match(preedit_last_code)) then
                yield(cand)
                prev_cand_ok = true
            else
                table.insert(cands, cand)
                prev_cand_ok = false
            end
        elseif
            (preedit_code:match("^[%u][%a]+") and cand_text:match("^[A-Z]$"))
            or (
                preedit_code:match("^[%u][%a]+$")
                and cand_text:find("([\228-\233][\128-\191]-)")
            )
        then
            prev_cand_ok = false
        elseif not prev_cand_ok then
            table.insert(cands, cand)
            prev_cand_ok = false
        else
            yield(cand)
            prev_cand_ok = true
        end

        if #cands > 80 then
            break
        end
    end

    for _, cand in ipairs(cands) do
        yield(cand)
    end
end

return { filter = { init = fly_fixed.init, func = fly_fixed.func } }
