--[[
ecdict: 把ECDICT.dict.yaml里的text作为comment，code作为text输出
--]]

local easy_en = {}

local function truncate_comment(comment)
    local MAX_LENGTH = 20
    local comment_res = comment:gsub(" |", "; "):gsub("[;,.=( ]+$", "")
    if #comment > MAX_LENGTH then
        comment_res = string.utf8_sub(comment_res, 1, MAX_LENGTH)
        return comment_res and comment_res:gsub("[;,.=( ]+$", "")
    end
    return comment_res
end

function easy_en.init(env)
    local config = env.engine.schema.config
    local _easy_en_pat = config:get_string("recognizer/patterns/easy_en") or nil
    env.easy_en_prefix = _easy_en_pat and _easy_en_pat:match("%^([a-z/]+).*") or "/oe"
    env.en_comment_overwrited = config:get_bool("ecdict_reverse_lookup/overwrite_comment") or false
end

--[[
function easy_en.translator(input, seg, env)
    if input:match("^%l+%*%l+$") then
        local input_code, fuzz_str = input:match("(.*)%*(.*)")
        local patter_str = string.format("^%s.*%s", input_code, fuzz_str)
        local easy_en_tran = env.easy_en_translator:query(input_code, seg)
        for cand in easy_en_tran:iter() do
            if cand.text:match(patter_str) then
                -- table.insert(easy_en_cands, cand)
                yield(cand)
            end
        end
    end
end
--]]

function easy_en.filter(input, env)
    local en_cands = {}
    local separator = " 🔎 "
    local engine = env.engine
    local schema = engine.schema
    local context = env.engine.context
    local input_code = context.input:gsub(" ", "")
    local en_comment_overwrited = env.en_comment_overwrited

    for cand in input:iter() do
        if (schema.schema_id == "easy_en") then
            local comment = truncate_comment(cand.comment)
            cand.comment = separator .. comment
            table.insert(en_cands, cand)
        elseif (input_code:match("^" .. env.easy_en_prefix)) then
            if (en_comment_overwrited) then
                local comment = truncate_comment(cand.comment)
                cand.comment = separator .. comment
                table.insert(en_cands, cand)
            else
                local preedit_code = input_code:lower():gsub(env.easy_en_prefix, "")
                if (preedit_code == cand.text:lower()) then cand.comment = "" end
                table.insert(en_cands, cand) -- 防止候选太多, 输入卡顿
            end
        else
            yield(cand)
        end

        if #en_cands >= 100 then break end -- 防止候选太多, 输入卡顿
    end

    for _, cand in ipairs(en_cands) do
        yield(cand)
    end
end

return {
    -- translator = { init = easy_en.init, func = easy_en.translator },
    filter = { init = easy_en.init, func = easy_en.filter }
}
