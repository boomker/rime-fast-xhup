--[[
ecdict: 把ECDICT.dict.yaml里的text作为comment，code作为text输出
--]]
local easy_en = {}

local function truncate_comment(comment)
    local MAX_LENGTH = 20
    local comment_res = comment:gsub(" | ", "; "):gsub("[;,.( ]+$", "")
    if #comment > MAX_LENGTH then
        comment_res = string.utf8_sub(comment_res, 1, MAX_LENGTH)
        return comment_res and comment_res:gsub("[%a;,.( ]+$", "")
    end
    return comment_res
end

function easy_en.init(env)
    local config = env.engine.schema.config
    env.easy_en_prefix = config:get_string("recognizer/patterns/easy_en"):match("%^([a-z/]+).*") or "/oe"
    env.en_comment_overwrited = config:get_bool("ecdict_reverse_lookup/overwrite_comment") or false
end

function easy_en.filter(input, env)
    local separator = " 🔎 "
    local en_cands = {}
    local context = env.engine.context
    local preedit_code =context.input:gsub(" ", "")

    for cand in input:iter() do
        if (preedit_code:match("^" .. env.easy_en_prefix)) then
            if (env.en_comment_overwrited) then
                local comment = truncate_comment(cand.comment)
                cand.comment = separator .. comment
                table.insert(en_cands, cand)
            else
                cand.comment = ""
                table.insert(en_cands, cand)
            end
        else
            yield(cand)
        end
        if #en_cands >= 80 then
            break
        end
    end
    for _, cand in ipairs(en_cands) do
        yield(cand)
    end
end

return {
    -- processor = easy_en.processor,
    -- translator = easy_en.translator
    filter = { init = easy_en.init, func = easy_en.filter }
}
