local processor = {}
local translator = {}
local flypy_switcher = {}
require("lib/metatable")
require("lib/rime_helper")
local Env = require("lib/env_api")

function flypy_switcher.init(env)
    Env(env)
    local config = env.engine.schema.config
    local schema_id = config:get_string("schema/schema_id")
    local schema = Schema(schema_id)
    env.reversedb = ReverseLookup(schema_id)
    env.mem = Memory(env.engine, schema, "translator")
    env.page_size = config:get_int("menu/page_size") or 7
    env.font_point = config:get_int("style/font_point") or 20
    env.line_spacing = config:get_int("style/line_spacing") or 5
    env.comment_hints = config:get_int("translator/spelling_hints") or 1
    env.easy_en_prompt = config:get_string("easy_en/tips") or "英文"
    env.char_mode_state = config:get_string("char_mode/toggle") or "off"
    env.text_orientation = config:get_string("style/text_orientation") or "horizontal"
    env.candidate_layout = config:get_string("style/candidate_list_layout") or "stacked"
    env.char_mode_switch_key = config:get_string("key_binder/char_mode") or "Control+s"
    env.switch_comment_key = config:get_string("key_binder/switch_comment") or "Control+n"
    env.commit_comment_key = config:get_string("key_binder/commit_comment") or "Control+p"
    env.switch_english_key = config:get_string("key_binder/switch_english") or "Control+g"
    local switchOpt_pat = config:get_string("recognizer/patterns/switch_options") or "/so|sO"
    env.switch_options_trigger = switchOpt_pat:match("%^.?([a-zA-Z/|]+).*") or "/so|sO"
    env.normal_labels = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
    env.alter_labels = { "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨" }
    env.word_auto_commit = config:get_bool("speller/auto_commit") or false
    env.inline_preedit_style = config:get_bool("style/inline_preedit") or false
    env.en_comment_overwrite = config:get_bool("ecdict_reverse_lookup/overwrite_comment") or false
    env.cn_comment_overwrite = config:get_bool("radical_reverse_lookup/overwrite_comment") or false
    env.switch_options_menu = {
        "切换纵横布局样式",
        "切换预编码区样式",
        "切换候选序号样式",
        "切换Emoji😂显隐",
        "切换中英标点输出",
        "切换半角全角符号",
        "切换简体繁体转换",
        "切换候选文字方向",
        "增加单页候选项数",
        "减少单页候选项数",
        "增加候选字号大小",
        "减少候选字号大小",
        "增加行间距的大小",
        "减少行间距的大小",
        "开关候选注解提示",
        "开关字集码区提示",
        "开关词组自动上屏",
        "开关分号自动上屏",
        "开关中英词条空格",
        "禁用中英前置空格",
        "恢复常规候选按键",
    }
end

function flypy_switcher.fini(env)
    env.mem:disconnect()
    if env.mem then env.mem = nil end
end

function processor.func(key, env)
    local engine = env.engine
    local schema = engine.schema
    local config = schema.config
    local context = engine.context
    local page_size = schema.page_size
    local composition = context.composition
    if composition:empty() then return 2 end
    local segment = composition:back()
    local preedit_code = context:get_script_text():gsub(" ", "")

    if context:has_menu() and (key:repr() == env.switch_comment_key) then
        if segment.prompt:match(env.easy_en_prompt) and env.en_comment_overwrite then
            config:set_bool("ecdict_reverse_lookup/overwrite_comment", false) -- 重写英文注释为空
        elseif segment.prompt:match(env.easy_en_prompt) and not env.en_comment_overwrite then
            config:set_bool("ecdict_reverse_lookup/overwrite_comment", true) -- 重写英文注释为中文
        elseif (not env.cn_comment_overwrite) and (env.comment_hints > 0) then
            config:set_bool("radical_reverse_lookup/overwrite_comment", true) -- 重写注释为注音
        elseif env.cn_comment_overwrite and (env.comment_hints > 0) then
            config:set_int("translator/spelling_hints", 0)
            config:set_bool("radical_reverse_lookup/overwrite_comment", false) -- 重写注释为空
            env:Config_set("radical_reverse_lookup/comment_format/@last", "xform/^.+$//")
        else
            config:set_int("translator/spelling_hints", 1) -- 重写注释为小鹤形码
            config:set_bool("radical_reverse_lookup/overwrite_comment", false)
            env:Config_set("radical_reverse_lookup/comment_format/@last", "xform/^/~/")
        end
        engine:apply_schema(Schema(schema.schema_id))
        context:push_input(preedit_code)
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1 -- kAccept
    end

    if context:has_menu() and (key:repr() == env.commit_comment_key) then
        local cand = context:get_selected_candidate()
        local cand_comment = cand.comment:gsub("[~〔〕]", "")
        engine:commit_text(cand_comment)
        context:clear()
        return 1
    end

    if (key:repr() == env.switch_english_key) and (schema.schema_id ~= "easy_en") then
        context:clear()
        env.engine:apply_schema(Schema("easy_en"))
        context:push_input(preedit_code)
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1 -- kAccept
    elseif (key:repr() == env.switch_english_key) and (schema.schema_id == "easy_en") then
        context:clear()
        env.engine:apply_schema(Schema("flypy_xhfast"))
        context:push_input(preedit_code)
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1 -- kAccept
    end

    if segment.prompt:match("切换配置选项") then
        local key_value = key:repr()
        local idx = segment.selected_index
        local index = get_selected_candidate_index(key_value, idx, page_size)
        if index < 0 then return 2 end
        local selected_cand = segment:get_candidate_at(index)
        local cand_text = selected_cand.text:gsub(" ", "")

        if cand_text == "切换纵横布局样式" then
            local switch_to_val = ""
            if env.candidate_layout == "stacked" then
                switch_to_val = "linear"
            else
                switch_to_val = "stacked"
            end
            config:set_string("style/candidate_list_layout", switch_to_val) -- 重写 horizontal
        elseif cand_text == "切换候选文字方向" then
            local switch_to_val = ""
            if env.text_orientation == "horizontal" then
                switch_to_val = "vertical"
            else
                switch_to_val = "horizontal"
            end
            config:set_string("style/text_orientation", switch_to_val) -- 重写 horizontal
        elseif cand_text == "切换预编码区样式" then
            local switch_to_val = not env.inline_preedit_style
            config:set_bool("style/inline_preedit", switch_to_val) -- 重写 inline_preedit
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
            context:set_option("ascii_punct", switch_to_val)
        elseif cand_text == "切换半角全角符号" then
            local full_shape_state = context:get_option("full_shape")
            local switch_to_val = not full_shape_state
            context:set_option("full_shape", switch_to_val)
        elseif cand_text == "切换简体繁体转换" then
            local simp_tran_state = context:get_option("traditionalize")
            local switch_to_val = not simp_tran_state
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
                env:Config_set("punctuator/half_shape/;", {";", "；"})
            end
        elseif cand_text == "恢复常规候选按键" then
            config:set_int("menu/alternative_select_keys", 123456789)
        elseif cand_text == "开关候选注解提示" then
            if (env.comment_hints > 0) then
                config:set_int("translator/spelling_hints", 0)
                config:set_bool("radical_reverse_lookup/overwrite_comment", false) -- 重写注释为空
                env:Config_set("radical_reverse_lookup/comment_format/@last", "xform/^.+$//")
            else
                config:set_int("translator/spelling_hints", 1)
                config:set_bool("radical_reverse_lookup/overwrite_comment", false)
                env:Config_set("radical_reverse_lookup/comment_format/@last", "xform/^/~/")
            end
        elseif cand_text == "开关词组自动上屏" then
            local switch_to_val = not env.word_auto_commit
            config:set_bool("speller/auto_select_phrase", switch_to_val)
        elseif cand_text == "开关字集码区提示" then
            local charset_hint_state = context:get_option("charset_hint")
            local switch_to_val = not charset_hint_state
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
        config:save_to_file(rime_api.get_user_data_dir() .. "/build/flypy_xhfast.schema.yaml")
        -- config:load_from_file(rime_api.get_user_data_dir() .. "/build/flypy_xhfast.schema.yaml")
        engine:apply_schema(Schema(schema.schema_id))
        return 1 -- kAccept
    end

    if (key:repr() == env.char_mode_switch_key) and (schema.schema_id ~= "easy_en") then
        local char_mode_option = flypy_switcher.char_mode or (env.char_mode_state == "off") or 0 and 1
        flypy_switcher.char_mode = (char_mode_option == 1) and 0 or 1
        local switch_to_val = (flypy_switcher.char_mode == 1) and true or false
        context:set_option("char_mode", switch_to_val)
        context:refresh_non_confirmed_composition()
        return 1 -- kAccept
    end
    return 2 -- kNoop, 不做任何操作, 交给下个组件处理
end

function translator.func(input, seg, env)
    local context = env.engine.context
    local composition = context.composition
    if composition:empty() then return end
    local segment = composition:back()
    local char_mode_option = (env.char_mode_state == "off") or 0 and 1
    local char_mode_state = flypy_switcher.char_mode or char_mode_option

    local trigger_pattern = env.switch_options_trigger
    local trigger_prefix_tbl = trigger_pattern:match("|") and string.split(trigger_pattern, "|") or {"/so", "sO"}

    if seg:has_tag("switch_options") or table.find(trigger_prefix_tbl, input) then
        segment.prompt = "〔" .. "切换配置选项" .. "〕"
        for _, text in ipairs(env.switch_options_menu) do
            yield(Candidate("switch_options", seg.start, seg._end, text, ""))
        end
    end

    -- 四码时, 按下`Control+s`, 单字优先
    if (input:match("^%l%l%l%l$") and (char_mode_state == 1)) then
        local entry_matched_tbl = {}
        local yin_code = input:sub(1, 2)
        local ok = env.mem:dict_lookup(yin_code, true, 300) -- expand_search
        if not ok then return end
        for dictentry in env.mem:iter_dict() do
            local entry_text = dictentry.text

            if (utf8.len(entry_text) == 1) and (not entry_text:match("[a-zA-Z]")) then
                local reverse_char_code = env.reversedb:lookup(entry_text):gsub("%[", "")
                if reverse_char_code:match(input) then
                    table.insert(entry_matched_tbl, dictentry)
                end
            end
        end

        for _, de in ipairs(entry_matched_tbl) do
            local ph = Phrase(env.mem, "single_char", seg.start, seg._end, de)
            local cand = ph:toCandidate()
            cand.quality = 9999
            yield(cand)
        end
    end
end

return {
    processor = {
        init = flypy_switcher.init,
        func = processor.func,
        fini = flypy_switcher.fini,
    },
    translator = {
        init = flypy_switcher.init,
        func = translator.func,
        fini = flypy_switcher.fini,
    },
}
