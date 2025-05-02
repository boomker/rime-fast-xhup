require("lib/string")
local F = {}
local T = {}
local flypy_fixed = {}

function flypy_fixed.init(env)
    local config = env.engine.schema.config
    local schema_id = config:get_string("schema/schema_id")
    local schema = Schema(schema_id)
    env.reversedb = ReverseLookup(schema_id)
    env.easy_en_prefix = config:get_string("easy_en/prefix") or "eN"
    env.pin_mark = config:get_string("pin_word/comment_mark") or "🔝"
    env.custom_mark = config:get_string("custom_phrase/comment_mark") or " 📌"
    env.script_translator = Component.ScriptTranslator(env.engine, schema, "translator", "script_translator")
end

function flypy_fixed.fini(env)
    -- env.memory:disconnect()
    -- if env.memory then env.memory = nil end
    env.script_translator:disconnect()
    if env.script_translator then
        env.script_translator = nil
    end
end

function T.func(input, seg, env)
    local context = env.engine.context
    local composition = context.composition
    if composition:empty() then return end
    if (#input <= 2) or input:match("%d%p") then return end
    local word_cands = env.script_translator:query(input, seg)

    if word_cands then
        local count = 0
        for cand in word_cands:iter() do
            if count > 3 then break end
            local entry_text = cand.text
            local input_code_len = ((#input % 2) ~= 0) and (#input + 1) or #input
            if (utf8.len(entry_text) >= 2) and (not entry_text:match("%a%d%p")) then
                local first_char = string.utf8_sub(entry_text, 1, 1)
                local last_char = string.utf8_sub(entry_text, -1, -1)

                local first_syllable_code = input:sub(1, 2)
                local preedit_last_code = input:sub(-1, -1)
                local first_char_ycode = env.reversedb:lookup(first_char):gsub("%[%l%l", "")
                local last_char_ycode = env.reversedb:lookup(last_char):gsub("%l%[%l%l", "")
                if last_char_ycode and first_char_ycode
                    and last_char_ycode:match(preedit_last_code)
                    and first_char_ycode:match(first_syllable_code)
                then
                    cand.quality = 999
                    yield(cand)
                    count = count + 1
                elseif first_char_ycode
                    and first_char_ycode:match(first_syllable_code)
                    and ((input_code_len / 2 ) >= utf8.len(entry_text))
                then
                    cand.quality = 888
                    yield(cand)
                end
            end
        end
    end
end

function F.func(input, env)
    local drop_cand = false
    local context = env.engine.context
    local preedit_code = context.input
    local _, symbol_count = preedit_code:gsub("[`']", "")
    local _syllable_count = math.floor(#preedit_code / 2)
    local confirmed_syllable_len = _syllable_count - symbol_count
    for cand in input:iter() do
        local cand_text = cand.text:gsub(" ", "")

        if cand.comment:match("^" .. env.pin_mark .. "$") then
            -- 带有 pin_mark 标记的候选词条, 优先显示
            yield(cand)
        elseif cand_text:match("<br>") then
             -- 词条有<br>标签, 将其转为换行符
            local ccand_text = cand_text:gsub("<br>", "\n")
            yield(cand:to_shadow_candidate(cand.type, ccand_text, env.custom_mark))
        elseif  -- 丢弃一些候选结果
                -- 去掉候选注解包含`太极️`的候选项
            string.find(cand.comment, "☯")
            or (   -- 开头大写的输入编码, 去掉只有单字母的候选
                preedit_code:match("^[%u][%a]+")
                and cand_text:match("^[A-Z]$")
            ) or ( -- 辅码筛字时, 过滤掉 emoji
                preedit_code:match("^%l+[`/][%l`/]*$")
                and (cand:get_dynamic_type() == "Shadow")
            ) or ( -- 辅码模式下, 过滤掉长度超出预确认音节长度的候选
                preedit_code:match("^%l+`%l+") and
                (cand_text:utf8_len() > confirmed_syllable_len)
            ) or ( -- V模式下, 过滤掉中英混合词条
                preedit_code:match("^V%a+$") and
                cand_text:find("([\228-\233][\128-\191]-)")
            ) or ( -- 候选词长度超出预确认音节长度 2 个以上的候选
                (cand.type == "completion") and
                (not cand_text:match("[%a%p]")) and
                (utf8.len(cand_text) - confirmed_syllable_len > 2)
            )
        then
            drop_cand = true
        else
            yield(cand)
        end

    end

    if drop_cand then drop_cand = false end
end

return {
    translator = {
        init = flypy_fixed.init,
        func = T.func,
        fini = flypy_fixed.fini
    },
    filter = {
        init = flypy_fixed.init,
        func = F.func,
        fini = flypy_fixed.fini
    },
}
