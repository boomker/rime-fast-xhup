--[[
ecdict: 把ECDICT.dict.yaml里的text作为comment，code作为text输出
--]]

local easy_en = {}

local function truncate_comment(comment)
    local MAX_LENGTH = 20
    if string.utf8_len(comment) > MAX_LENGTH then
        local comment_text = string.utf8_sub(comment, 1, MAX_LENGTH)
        comment_text = comment_text and comment_text:gsub("[;,.=(%a ]+$", "")
        return comment_text
    end
    return comment:gsub("[;,.=(%a ]+$", "")
end

function easy_en.init(env)
    local config = env.engine.schema.config
    local easy_en_schema = Schema("easy_en") -- schema_id
    local _easy_en_pat = config:get_string("recognizer/patterns/easy_en") or nil
    env.wildcard = config:get_string("easy_en/wildcard") or "*"
    env.trigger_prefix = config:get_string("easy_en/prefix") or "eN"
    env.expan_word_count = config:get_int("easy_en/expan_word_count") or 666
    env.mem = Memory(env.engine, easy_en_schema, "translator")
    env.easy_en_prefix = env.trigger_prefix or _easy_en_pat and _easy_en_pat:match("%^([a-z/]+).*")
    env.easydict_translate_key = config:get_string("key_binder/easydict_translate") or "Control+y"
    env.en_comment_overwrited = config:get_bool("ecdict_reverse_lookup/overwrite_comment") or false
end

function easy_en.fini(env)
    env.mem:disconnect()
    if env.mem then
        env.mem = nil
    end
end

function easy_en.processor(key, env)
    local engine = env.engine
    local context = engine.context
    local composition = context.composition
    if composition:empty() then return 2 end

    if context:has_menu() and (key:repr() == env.easydict_translate_key) then
        local cand = context:get_selected_candidate()
        local cand_text = cand.text:gsub("%p ", "")
        local osascript = "open " .. "easydict://query?text=" .. cand_text
        os.execute(osascript)

        context:clear()
        return 1
    end
end

function easy_en.translator(input, seg, env)
    if string.match(input, env.wildcard) then
        local tailer = string.match(input, "[^" .. env.wildcard .. "]+$") or ""
        local header = string.match(input, "^[^" .. env.wildcard .. "]+")
        env.mem:dict_lookup(header, true, env.expan_word_count) -- expand_search
        for dictentry in env.mem:iter_dict() do
            local codetail = string.match(dictentry.comment:lower(), tailer .. "$") or ""
            if tailer and (codetail == tailer) then
                -- local code = env.mem:decode(dictentry.code)
                -- local codeComment = table.concat(code, ",")
                local ph = Phrase(env.mem, "expand_en_word", seg.start, seg._end, dictentry)
                ph.comment = dictentry.comment:lower()
                yield(ph:toCandidate())
            end
        end
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
        if schema.schema_id == "easy_en" then
            local comment = truncate_comment(cand.comment)
            cand.comment = separator .. comment
            table.insert(en_cands, cand)
        elseif input_code:match("^" .. env.easy_en_prefix) then
            if en_comment_overwrited then
                local comment = truncate_comment(cand.comment)
                cand.comment = separator .. comment
                table.insert(en_cands, cand)
            else
                local preedit_code = input_code:lower():gsub(env.easy_en_prefix, "")
                if cand.text:lower():match(preedit_code) then
                    cand.comment = ""
                end
                table.insert(en_cands, cand) -- 防止候选太多, 输入卡顿
            end
        else
            yield(cand)
        end

        if #en_cands >= 150 then
            break
        end -- 防止候选太多, 输入卡顿
    end

    for _, cand in ipairs(en_cands) do
        yield(cand)
    end
end

return {
    processor = { init = easy_en.init, func = easy_en.processor, fini = easy_en.fini },
    translator = { init = easy_en.init, func = easy_en.translator, fini = easy_en.fini },
    filter = { init = easy_en.init, func = easy_en.filter, fini = easy_en.fini },
}
