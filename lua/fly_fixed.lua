local F = {}
-- local T = {}
-- require("lib/string")

function F.init(env)
    local config = env.engine.schema.config
    env.schema_id = config:get_string("schema/schema_id")
    local schema = Schema(env.schema_id)
    env.reversedb = ReverseLookup(env.schema_id)
    -- env.reversedb = ReverseLookup(reverse_dict)
    -- local reverse_dict = config:get_string("translator/dictionary")
    env.easy_en_prefix = config:get_string("easy_en/prefix") or "eN"
    env.top_mark = config:get_string("pin_word/comment_mark") or "🔝"
    env.custom_mark = config:get_string("custom_phrase/comment_mark") or " 📌"
    env.script_translator = Component.ScriptTranslator(env.engine, schema, "translator", "script_translator")
end

function F.fini(env)
    if env.script_translator then
        env.script_translator:disconnect()
        env.script_translator = nil
    end
end

--[[
function T.func(input, seg, env)
    local context = env.engine.context
    local composition = context.composition
    if composition:empty() then return end
    if (#input <= 2) or input:match("%d%p") then return end
    local preedit_code = context:get_script_text()
    local word_cands = env.script_translator:query(input, seg)

    if word_cands then
        local count = 0
        for cand in word_cands:iter() do
            if count > 3 then break end
            local entry_text = cand.text
            if (utf8.len(entry_text) >= 2) and (not entry_text:match("%a%d%p")) then
                local first_char = string.utf8_sub(entry_text, 1, 1)
                local last_char = string.utf8_sub(entry_text, -1, -1)

                local first_syllable_code = input:sub(1, 2)
                local preedit_last_code = input:sub(-1, -1)
                local first_char_yin_code = env.reversedb:lookup(first_char)
                local last_char_yin_code = env.reversedb:lookup(last_char):sub(0, 1)
                if last_char_yin_code and first_char_yin_code
                    and last_char_yin_code:match(preedit_last_code)
                    and first_char_yin_code:match(first_syllable_code)
                then
                    cand.quality = 999
                    yield(cand)
                    count = count + 1
                elseif first_char_yin_code
                    and first_char_yin_code:match(first_syllable_code)
                    and ((#preedit_code / 2) >= utf8.len(entry_text))
                then
                    cand.quality = 888
                    yield(cand)
                end
            end
        end
    end
end
]]

function F.func(input, env)
    local seglen = 0
    local fuzz_cands = {}
    local drop_cand = false
    local context = env.engine.context
    local composition = context.composition

    if composition:empty() then return end
    local segment = composition:back()
    seglen = segment.length
    local preedit_code = context.input
    local _, symbol_count = preedit_code:gsub("[`']", "")
    local syllable_len = (seglen > 1) and (seglen / 2) or (#preedit_code - symbol_count)

    for cand in input:iter() do
        local cand_text = cand.text:gsub(" ", "")
        local cand_text_len = utf8.len(cand_text)
        local cand_dtype = cand:get_dynamic_type()

        if cand.comment:match("^" .. env.top_mark .. "$") then
            yield(cand)                                     -- 带有 top_mark 标记的候选词条, 优先显示
        elseif cand_text:match("<br>") then
            local ccand_text = cand_text:gsub("<br>", "\n") -- 词条有<br>标签, 将其转为换行符
            yield(cand:to_shadow_candidate(cand.type, ccand_text, env.custom_mark))
        elseif (env.schema_id == "flyhe_fast") and (cand_text_len == 1) and (syllable_len == 1) then
            local char_code = env.reversedb:lookup(cand_text)
            local input_code = preedit_code:gsub("([jy])v", "%1u")
            if (char_code:sub(0, 2):match("^" .. input_code)) then yield(cand) end
        elseif (cand_text_len >= 2) and (syllable_len == 1) and (env.schema_id == "flyhe_fast") then
            table.insert(fuzz_cands, cand)
        elseif (cand_text_len == syllable_len) and (cand_dtype == "Shadow") and (env.schema_id == "flyhe_fast") then
            table.insert(fuzz_cands, cand)
        elseif   -- 丢弃一些候选结果 去掉候选注解包含`太极️☯ ` 的候选项
            string.find(cand.comment, "☯")
            or ( -- 开头大写的输入编码, 去掉只有单字母的候选
                preedit_code:match("^[%u][%a]+")
                and cand_text:match("^[A-Z]$")
            ) or ( -- 辅码筛字时, 过滤掉 emoji
                preedit_code:match("^%l+[`/][%l`/]+$")
                and (cand_dtype == "Shadow")
            ) or ( -- 辅码模式下, 过滤掉长度超出预确认音节长度的候选
                preedit_code:match("^%l+[`/][%l`/]+$")
                and (cand_text_len > syllable_len)
            ) or ( -- V模式下, 过滤掉中英混合词条
                preedit_code:match("^V%a+$") and
                cand_text:find("([\228-\233][\128-\191]-)")
            ) or ( -- 候选词长度超出预确认音节长度 2 个以上的候选
                (cand.type == "completion") and
                (cand_text_len - syllable_len > 2) and
                cand_text:find("([\228-\233][\128-\191]-)")
            )
        then
            drop_cand = true
        else
            yield(cand)
        end
    end

    if #fuzz_cands > 0 then
        for _, fcand in ipairs(fuzz_cands) do
            yield(fcand)
        end
    end
    if drop_cand then drop_cand = false end
end

return {
    -- translator = {
    --     init = M.init,
    --     func = T.func,
    --     fini = M.fini
    -- },
    filter = {
        init = F.init,
        func = F.func,
        fini = F.fini
    },
}
