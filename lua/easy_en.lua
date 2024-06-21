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
    local schema = Schema("easy_en") -- schema_id
    local _easy_en_pat = config:get_string("recognizer/patterns/easy_en") or nil
    env.wildcard = '*'
    env.mem = Memory(env.engine, schema, "translator")
    env.expan_word_count = config:get_int("expan_word_count") or 150
    env.easy_en_prefix = _easy_en_pat and _easy_en_pat:match("%^([a-z/]+).*") or "/oe"
    env.en_comment_overwrited = config:get_bool("ecdict_reverse_lookup/overwrite_comment") or false
end

function easy_en.translator(input, seg, env)
    if string.match(input, env.wildcard) then
        local tailer = string.match(input, '[^' .. env.wildcard .. ']+$') or ''
        local header = string.match(input, '^[^' .. env.wildcard .. ']+')
        env.mem:dict_lookup(header, true, env.expan_word_count) -- expand_search
        for dictentry in env.mem:iter_dict() do
            local codetail = string.match(dictentry.comment:lower(), tailer .. '$') or ''
            if tailer and (codetail == tailer) then
                local code = env.mem:decode(dictentry.code)
                local codeComment = table.concat(code, ",")
                local ph = Phrase(env.mem, "expand_en_word", seg.start, seg._end, dictentry)
                ph.comment = codeComment
                yield(ph:toCandidate())
            end
        end
    end
end

function easy_en.fini(env)
    if env.mem then
        env.mem:disconnect()
        env.mem = nil
    end
end

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
    translator = { init = easy_en.init, func = easy_en.translator, fini = easy_en.fini },
    filter = { init = easy_en.init, func = easy_en.filter, fini = easy_en.fini }
}
