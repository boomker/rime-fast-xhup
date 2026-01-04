--[[
ecdict: 把ECDICT.dict.yaml里的text作为comment，code作为text输出
--]]

require("lib/string")
local easy_en = {}

local function truncate_comment(comment)
    local MAX_LENGTH = 20
    if utf8.len(comment) > MAX_LENGTH then
        local comment_text = string.utf8_sub(comment, 1, MAX_LENGTH)
        comment_text = comment_text and comment_text:gsub("[;,.=(%a ]+$", "")
        return comment_text
    end
    return comment:gsub("[;,.=(%a ]+$", "")
end

function easy_en.init(env)
    local config = env.engine.schema.config
    local easy_en_schema = Schema("easy_en") -- schema_id
    env.prompt = config:get_string("easy_en/tips") or "英文"
    env.wildcard = config:get_string("easy_en/wildcard") or "*"
    env.mem = Memory(env.engine, easy_en_schema, "translator")
    env.expand_word_count = config:get_int("easy_en/expand_word_count") or 666
    env.easydict_translate_key = config:get_string("key_binder/easydict_translate") or "Control+y"
    env.en_comment_overwrite = config:get_bool("ecdict_reverse_lookup/overwrite_comment") or false
end

function easy_en.fini(env)
    if env.mem then
        env.mem:disconnect()
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
    return 2
end

function easy_en.translator(input, seg, env)
    local engine = env.engine
    local schema = engine.schema
    local composition = engine.context.composition
    if (composition:empty()) then return end
    local segment = composition:back()
    if segment:has_tag("easy_en") or (schema.schema_id == "easy_en") or input:match("^%l+%*%l+$") then
        if not (schema.schema_id == "easy_en") then
            segment.prompt = "〔" .. env.prompt .. "〕"
        end
        local tailer = string.match(input, "[^" .. env.wildcard .. "]+$") or ""
        local header = string.match(input, "^[^" .. env.wildcard .. "]+")
        env.mem:dict_lookup(header, true, env.expand_word_count) -- expand_search
        for dictentry in env.mem:iter_dict() do
            local codetail = string.match(dictentry.comment:lower(), tailer .. "$") or ""
            if tailer and (codetail == tailer) then
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

    for cand in input:iter() do
        if schema.schema_id == "easy_en" then
            local comment = truncate_comment(cand.comment)
            cand.comment = separator .. comment
            table.insert(en_cands, cand)
        else
            yield(cand)
        end

        if #en_cands >= 200 then break end -- 防止候选太多, 输入卡顿
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
