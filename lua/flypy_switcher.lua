require("lib/metatable")
require("lib/rime_helper")
local Env = require("lib/env_api")
local M = {}
local P = {}
local T = {}
local F = {}

function M.init(env)
    Env(env)
    local engine = env.engine
    local config = engine.schema.config
    local schema_id = config:get_string("schema/schema_id")
    env.normal_labels = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
    env.alter_labels = { "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨" }
    env.rime_dist_name = rime_api:get_distribution_code_name()
    env.reversedb = ReverseLookup(schema_id)
    env.reversedb_flyhe = ReverseLookup("flyhe_fast")
    env.page_size = config:get_int("menu/page_size") or 7
    env.font_point = config:get_int("style/font_point") or 18
    env.line_spacing = config:get_int("style/line_spacing") or 5
    env.comment_hints = config:get_int("translator/spelling_hints") or 1
    env.easy_en_prompt = config:get_string("easy_en/tips") or "英文"
    env.preedit_fmt_rules = config:get_list("preedit_convert_rules")
    env.preedit_format = config:get_list("translator/preedit_format") or nil
    env.text_orientation = config:get_string("style/text_orientation") or "horizontal"
    env.candidate_layout = config:get_string("style/candidate_list_layout") or "stacked"
    env.switch_comment_key = config:get_string("key_binder/switch_comment") or "Control+n"
    env.commit_comment_key = config:get_string("key_binder/commit_comment") or "Control+p"
    env.switch_english_key = config:get_string("key_binder/switch_english") or "Control+g"
    env.select_keys = config:get_string("menu/alternative_select_keys") or "1234567890"
    env.cand_horizontal = config:get_bool("style/horizontal") or true
    env.preedit_style = config:get_bool("style/inline_preedit") or false
    env.word_auto_commit = config:get_bool("speller/auto_select_phrase") or false
    env.enable_fuzz_func = config:get_bool("speller/enable_fuzz_algebra") or false
    env.en_comment_overwrite = config:get_bool("easy_en-ecdict/overwrite_comment") or false
    env.cn_comment_overwrite = config:get_bool("radical_lookup/overwrite_comment") or false
    env.switch_option_menu = {
        "切换纵横布局样式",
        "切换预编码区样式",
        "切换预编码区格式",
        "切换候选序号样式",
        "切换Emoji😂显隐",
        "切换中英标点输出",
        "切换半角全角符号",
        "切换简体繁体转换",
        "切换候选文字方向",
        "切换大小字集启用",
        "开关候选注解提示",
        "开关字集码区提示",
        "开关单字优先功能",
        "开关超级简拼功能",
        "开关词组自动上屏",
        "开关分号自动上屏",
        "开关中英词条空格",
        "禁用中英前置空格",
        "恢复常规候选按键",
        "增加单页候选项数",
        "减少单页候选项数",
        "增加候选字号大小",
        "减少候选字号大小",
        "增加行间距的大小",
        "减少行间距的大小",
    }
end

function P.func(key, env)
    local engine = env.engine
    local schema = engine.schema
    local config = schema.config
    local context = engine.context
    local page_size = schema.page_size
    local composition = context.composition
    if composition:empty() then return 2 end

    local segment = composition:back()
    local preedit_code = context.input
    if key:release() or key:alt() or key:caps() then return 2 end

    if context:has_menu() and (key:repr() == env.switch_comment_key) then
        if segment.prompt:match(env.easy_en_prompt) and env.en_comment_overwrite then
            config:set_bool("easy_en-ecdict/overwrite_comment", false) -- 重写英文注释为空
        elseif segment.prompt:match(env.easy_en_prompt) and not env.en_comment_overwrite then
            config:set_bool("easy_en-ecdict/overwrite_comment", true) -- 重写英文注释为中文
        elseif (env:Config_get("switches/@last/reset") ~= 0) and (env.comment_hints > 0) then
            context:set_option("mask_hint", true) -- 重写注释为辅码
            env:Config_set("switches/@last/reset", 0)
            env:Config_set("radical_lookup/overwrite_comment", false)
        elseif (env:Config_get("switches/@last/reset") ~= 1) and (env.comment_hints > 0) then
            context:set_option("tone_hint", true)
            env:Config_set("switches/@last/reset", 1)
            env:Config_set("radical_lookup/overwrite_comment", true) -- 重写注释为注音
        end
        config:save_to_file(rime_api.get_user_data_dir() .. "/build/" .. schema.schema_id .. ".schema.yaml")
        engine:apply_schema(Schema(schema.schema_id))
        context:push_input(preedit_code)
        return 1 -- kAccept
    end

    if context:has_menu() and (key:repr() == env.commit_comment_key) then
        local cand = context:get_selected_candidate()
        local cand_comment = cand.comment:gsub("[~〔〕]", "")
        engine:commit_text(cand_comment)
        context:clear()
        return 1
    end

    if key:repr() == env.switch_english_key then
        if schema.schema_id ~= "easy_en" then
            env.engine:apply_schema(Schema("easy_en"))
        elseif schema.schema_id == "easy_en" then
            env.engine:apply_schema(Schema("flypy_xhfast"))
        end
        context:clear()
        context:push_input(preedit_code)
        return 1 -- kAccept
    end

    if segment.prompt:match("切换配置选项") then
        local key_value = key:repr()
        local idx = segment.selected_index
        local select_keys = env.select_keys
        local index = get_selected_candidate_index(key_value, idx, select_keys, page_size)
        if index < 0 then return 2 end
        local selected_cand = segment:get_candidate_at(index)
        local cand_text = selected_cand.text:gsub(" ", "")

        if cand_text == "切换纵横布局样式" then
            local switch_to_val = nil
            if env.rime_dist_name:lower():match("weasel") then
                if env.cand_horizontal then
                    switch_to_val = false
                else
                    switch_to_val = true
                end
                config:set_bool("style/horizontal", switch_to_val) -- 重写 horizontal
            else
                if env.candidate_layout == "stacked" then
                    switch_to_val = "linear"
                else
                    switch_to_val = "stacked"
                end
                config:set_string("style/candidate_list_layout", switch_to_val) -- 重写 horizontal
            end
        elseif cand_text == "切换候选文字方向" then
            local switch_to_val = ""
            if env.text_orientation == "horizontal" then
                switch_to_val = "vertical"
            else
                switch_to_val = "horizontal"
            end
            config:set_string("style/text_orientation", switch_to_val) -- 重写 horizontal
        elseif cand_text == "切换预编码区样式" then
            local switch_to_val = not env.preedit_style
            config:set_bool("style/inline_preedit", switch_to_val) -- 重写 inline_preedit
        elseif cand_text == "切换预编码区格式" then
            if (not env.preedit_format) or (env.preedit_format and env.preedit_format.size <= 1) then
                env:Config_set("translator/preedit_format", config:get_list("preedit_convert_rules"))
            else
                env:Config_set("translator/preedit_format", "")
            end
        elseif cand_text == "切换候选序号样式" then
            if env:Config_get("menu/alternative_select_labels")[1] == 1 then
                env:Config_set("menu/alternative_select_labels", env.alter_labels)
            else
                env:Config_set("menu/alternative_select_labels", env.normal_labels)
            end
        elseif cand_text == "切换Emoji😂显隐" then
            local emoji_visible = env:Config_get("switches/@4/reset")
            local switch_to_val = (emoji_visible > 0) and 0 or 1
            env:Config_set("switches/@4/reset", switch_to_val)
        elseif cand_text == "切换中英标点输出" then
            local ascii_punct_state = context:get_option("ascii_punct")
            local switch_to_val = not ascii_punct_state
            local ascii_punct_val = env:Config_get("switches/@1/reset")
            if ascii_punct_val then
                local ascii_punct_setval = (ascii_punct_val > 0) and 0 or 1
                env:Config_set("switches/@1/reset", ascii_punct_setval)
            end
            context:set_option("ascii_punct", switch_to_val)
        elseif cand_text == "切换半角全角符号" then
            local full_shape_state = context:get_option("full_shape")
            local switch_to_val = not full_shape_state
            local full_shape_val = env:Config_get("switches/@2/reset")
            if full_shape_val then
                local full_shape_setval = (full_shape_val > 0) and 0 or 1
                env:Config_set("switches/@2/reset", full_shape_setval)
            end
            context:set_option("full_shape", switch_to_val)
        elseif cand_text == "切换简体繁体转换" then
            local simp_tran_state = context:get_option("traditionalize")
            local switch_to_val = not simp_tran_state
            local simp_tran_val = env:Config_get("switches/@3/reset")
            if simp_tran_val then
                local simp_tran_setval = (simp_tran_val > 0) and 0 or 1
                env:Config_set("switches/@3/reset", simp_tran_setval)
            end
            context:set_option("traditionalize", switch_to_val)
        elseif cand_text == "增加候选字体大小" then
            config:set_int("style/font_point", (env.font_point + 1))
        elseif cand_text == "减少候选字体大小" then
            config:set_int("style/font_point", (env.font_point - 1))
        elseif cand_text == "增加行间距的大小" then
            config:set_int("style/line_spacing", (env.line_spacing + 1))
        elseif cand_text == "减少行间距的大小" then
            config:set_int("style/line_spacing", (env.line_spacing - 1))
        elseif cand_text == "增加单页候选项数" then
            config:set_int("menu/page_size", (env.page_size + 1))
        elseif cand_text == "减少单页候选项数" then
            config:set_int("menu/page_size", (env.page_size - 1))
        elseif cand_text == "开关分号自动上屏" then
            if env:Config_get("punctuator/half_shape/;") ~= "；" then
                env:Config_set("punctuator/half_shape/;", "；")
            else
                env:Config_set("punctuator/half_shape/;", { ";", "；" })
            end
        elseif cand_text == "恢复常规候选按键" then
            config:set_int("menu/alternative_select_keys", 123456789)
        elseif cand_text == "开关候选注解提示" then
            if env.comment_hints > 0 then
                config:set_int("translator/spelling_hints", 0)
                config:set_bool("radical_lookup/overwrite_comment", false) -- 重写注释为空
                env:Config_set("radical_lookup/comment_format/@last", "xform/^.+$//")
            else
                config:set_int("translator/spelling_hints", 1)
                config:set_bool("radical_lookup/overwrite_comment", false)
                env:Config_set("radical_lookup/comment_format/@last", "xform/^/~/")
            end
        elseif cand_text == "开关词组自动上屏" then
            local switch_to_val = not env.word_auto_commit
            config:set_bool("speller/auto_select_phrase", switch_to_val)
        elseif cand_text == "开关超级简拼功能" then
            local switch_to_val = not env.enable_fuzz_func
            config:set_bool("speller/enable_fuzz_algebra", switch_to_val)
        elseif cand_text == "开关单字优先功能" then
            local char_mode_state = context:get_option("char_mode")
            local switch_to_val = not char_mode_state
            local char_mode_val = env:Config_get("switches/@6/reset")
            if char_mode_val then
                local char_mode_setval = (char_mode_val > 0) and 0 or 1
                env:Config_set("switches/@6/reset", char_mode_setval)
            end
            context:set_option("char_mode", switch_to_val)
        elseif cand_text == "切换大小字集启用" then
            local charset_state = context:get_option("charset")
            local switch_to_val = not charset_state
            local charset_val = env:Config_get("switches/@7/reset")
            local charset_setval = (charset_val > 0) and 0 or 1
            context:set_option("charset", switch_to_val)
            env:Config_set("switches/@7/reset", charset_setval)
        elseif cand_text == "开关字集码区提示" then
            local charset_hint_state = context:get_option("charset_hint")
            local switch_to_val = not charset_hint_state
            local charset_hint_val = env:Config_get("switches/@8/reset")
            if charset_hint_val then
                local charset_hint_setval = (charset_hint_val > 0) and 0 or 1
                env:Config_set("switches/@8/reset", charset_hint_setval)
            end
            context:set_option("charset_hint", switch_to_val)
        elseif cand_text == "开关中英词条空格" then
            local filters = env:Config_get("engine/filters")
            local target_filter = "lua_filter@*word_append_space*filter"
            local filter_idx = table.find_index(filters, target_filter)
            if filter_idx then
                table.remove(filters, filter_idx)
            else
                table.insert(filters, #filters, target_filter)
            end
            env:Config_set("engine/filters", filters)
        elseif cand_text == "禁用中英前置空格" then
            local processors = env:Config_get("engine/processors")
            local target_processor = "lua_processor@*word_append_space*processor"
            local processor_idx = table.find_index(processors, target_processor)
            if processor_idx then
                table.remove(processors, processor_idx)
            end
            env:Config_set("engine/processors", processors)
        end
        config:save_to_file(rime_api.get_user_data_dir() .. "/build/" .. schema.schema_id .. ".schema.yaml")
        engine:apply_schema(Schema(schema.schema_id))
        return 1 -- kAccept
    end

    return 2 -- kNoop, 不做任何操作, 交给下个组件处理
end

function T.func(input, seg, env)
    local context = env.engine.context
    local composition = context.composition
    if composition:empty() then return end
    local segment = composition:back()

    if seg:has_tag("flypy_switcher") then
        segment.tags = segment.tags - Set({"abc"})
        segment.prompt = "〔" .. "切换配置选项" .. "〕"
        for _, text in ipairs(env.switch_option_menu) do
            yield(Candidate("switch_option", seg.start, seg._end, text, ""))
        end
    end
end

function F.func(input, env)
    local context = env.engine.context
    local composition = context.composition
    if composition:empty() then return end

    local input_code = context.input
    local preedit_proj = Projection()
    local use_mask = context:get_option("mask_hint")
    local use_tone = context:get_option("tone_hint")
    local comment_off = context:get_option("comment_off")
    local yinma_code = input_code:gsub("%p", ""):sub(1, 2)
    local zero_shengmu_pattern = "([aoe]|(a[aoin])|(aang)|(o[ou])|(oian)|(e[erin])|(eeng))"
    local full_pinyin_code = preedit_proj:load(env.preedit_fmt_rules) and preedit_proj:apply(yinma_code, true) or nil

    for cand in input:iter() do
        local cand_text = cand.text
        if use_mask and (env.comment_hints > 0) and (utf8.len(cand_text) == 1) then
            local comment = env.reversedb:lookup(cand_text):sub(-2, -1)
            cand.comment = " " .. comment
        elseif use_tone and (env.comment_hints > 0) and (utf8.len(cand_text) == 1) then
            local comment_tbl = {}
            local comments = env.reversedb_flyhe:lookup(cand_text)
            if (utf8.len(comments) < 1) or (comments:match("%u")) then
                goto continue
            end
            for comment in comments:gsub("[%d%p]+", ""):gmatch("%S+") do
                if (comment:match("^" .. full_pinyin_code:sub(1, 1))) and (#yinma_code == 1) then
                    table.insert(comment_tbl, comment)
                elseif (comment:match("^" .. full_pinyin_code:sub(1, 1))) and (utf8.len(comment) == 1) then
                    table.insert(comment_tbl, comment)
                elseif
                    (comment:match("^" .. full_pinyin_code:sub(1, 1)))
                    and (utf8.len(comment) == #full_pinyin_code)
                then
                    table.insert(comment_tbl, comment)
                elseif
                    (not comment:match("^[a-z]"))
                    and rime_api.regex_match(full_pinyin_code, "^" .. zero_shengmu_pattern .. "$")
                then
                    table.insert(comment_tbl, comment)
                end
            end
            local final_comment = (#comment_tbl > 0) and table.concat(comment_tbl, " ") or ""
            cand.comment = (#final_comment > 0) and " " .. final_comment:gsub(" $", "") or ""
        elseif comment_off and (utf8.len(cand_text) == 1) then
            cand.comment = ""
        end
        ::continue::
        yield(cand)
    end
end

function F.tags_match(seg, env)
    if seg.tags["abc"] then return true end
    return false
end

return {
    processor = {
        init = M.init,
        func = P.func,
        -- fini = M.fini,
    },
    translator = {
        init = M.init,
        func = T.func,
        -- fini = M.fini,
    },
    filter = {
        init = M.init,
        func = F.func,
        -- fini = M.fini,
        tags_match = F.tags_match,
    },
}
