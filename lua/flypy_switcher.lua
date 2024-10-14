local processor = {}
local translator = {}
local flypy_switcher = {}
local reload_env = require("tools/env_api")
local rime_api_helper = require("tools/rime_api_helper")

function flypy_switcher.init(env)
    reload_env(env)
    local config = env.engine.schema.config
    env.page_size = config:get_int("menu/page_size") or 7
    env.font_point = config:get_int("style/font_point") or 20
    env.line_spacing = config:get_int("style/line_spacing") or 5
    env.comment_hints = config:get_int("translator/spelling_hints") or 1
    env.text_orientation = config:get_string("style/text_orientation") or "horizontal"
    env.candidate_list_layout = config:get_string("style/candidate_list_layout") or "stacked"
    env.inline_preedit_style = config:get_bool("style/inline_preedit") or false
    env.word_auto_commit_enabled = config:get_bool("flypy_phrase/auto_commit") or false
    env.cn_comment_overwrited = config:get_bool("radical_reverse_lookup/overwrite_comment") or false
    env.en_comment_overwrited = config:get_bool("ecdict_reverse_lookup/overwrite_comment") or false
    env.switch_comment_key = config:get_string("key_binder/switch_comment") or "Control+n"
    env.commit_comment_key = config:get_string("key_binder/commit_comment") or "Control+p"
    env.switch_english_key = config:get_string("key_binder/switch_english") or "Control+g"
    local _easy_en_pat = config:get_string("recognizer/patterns/easy_en") or nil
    local _so_pat = config:get_string("recognizer/patterns/switch_options") or nil
    env.easy_en_prefix = _easy_en_pat and _easy_en_pat:match("%^([a-z/]+).*") or "/oe"
    env.switch_options = _so_pat and _so_pat:match("[a-z/]+") or "/so"
    env.alter_labels = { '①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⓪' }
    env.normal_labels = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 }
    env.switch_options_menu = {
        "切换纵横布局样式",
        "切换候选文字方向",
        "切换编码区位样式",
        "切换候选序号样式",
        "切换Emoji😂显隐",
        "切换中英标点输出",
        "切换半角全角符号",
        "切换简体繁体显示",
        "增加候选字体大小",
        "减少候选字体大小",
        "增加行间距的大小",
        "减少行间距的大小",
        "增加单页候选项数",
        "减少单页候选项数",
        "恢复分号自动上屏",
        "恢复常规候选按键",
        "开关短语自动上屏",
        "开关字符码区提示",
        "关闭候选注解提示",
        "开关中英词条空格",
        "禁用中英前置空格",
    }
end

function processor.func(key, env)
    local engine = env.engine
    local schema = engine.schema
    local page_size = schema.page_size
    local context = engine.context
    local config = schema.config
    local composition = context.composition
    if composition:empty() then return 2 end
    local segment = composition:back()
    local preedit_code = context:get_script_text():gsub(" ", "")

    if context:has_menu() and (key:repr() == env.switch_comment_key) then
        if preedit_code:match("^" .. env.easy_en_prefix) and env.en_comment_overwrited then
            config:set_bool("ecdict_reverse_lookup/overwrite_comment", false) -- 重写英文注释为空
        elseif preedit_code:match("^" .. env.easy_en_prefix) and (not env.en_comment_overwrited) then
            config:set_bool("ecdict_reverse_lookup/overwrite_comment", true)  -- 重写英文注释为中文
        elseif (not env.cn_comment_overwrited) and (env.comment_hints > 0) then
            config:set_bool("radical_reverse_lookup/overwrite_comment", true) -- 重写注释为注音
        elseif env.cn_comment_overwrited and (env.comment_hints > 0) then
            config:set_int("translator/spelling_hints", 0)
            config:set_bool("radical_reverse_lookup/overwrite_comment", false) -- 重写注释为空
            env:Config_set('radical_reverse_lookup/comment_format/@last', "xform/^.+$//")
        else
            config:set_int("translator/spelling_hints", 1) -- 重写注释为小鹤形码
            config:set_bool("radical_reverse_lookup/overwrite_comment", false)
            env:Config_set('radical_reverse_lookup/comment_format/@last', "xform/^/~/")
        end
        engine:apply_schema(Schema(schema.schema_id))
        context:push_input(preedit_code)
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1                                    -- kAccept
    end

    if context:has_menu() and (key:repr() == env.commit_comment_key) then
        local cand = context:get_selected_candidate()
        local cand_comment = cand.comment:gsub("%p", "")
        engine:commit_text(cand_comment)
        context:clear()
        return 1
    end

    if (key:repr() == env.switch_english_key) and (schema.schema_id ~= "easy_en") then
        context:clear()
        env.engine:apply_schema(Schema("easy_en"))
        context:push_input(preedit_code)
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1                                    -- kAccept
    elseif (key:repr() == env.switch_english_key) and (schema.schema_id == "easy_en") then
        context:clear()
        env.engine:apply_schema(Schema("flypy_xhfast"))
        context:push_input(preedit_code)
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1                                    -- kAccept
    end

    if segment.prompt:match("切换配置选项") then
        local key_value = key:repr()
        local idx = segment.selected_index
        local index = rime_api_helper.get_selected_candidate_index(key_value, idx, page_size)
        if index < 0 then return 2 end
        local selected_cand = segment:get_candidate_at(index)
        local cand_text = selected_cand.text:gsub(" ", "")

        if (cand_text == "切换纵横布局样式") then
            local switch_to_val = ""
            if env.candidate_list_layout == "stacked" then
                switch_to_val = "linear"
            else
                switch_to_val = "stacked"
            end
            config:set_string("style/candidate_list_layout", switch_to_val) -- 重写 horizontal
        elseif (cand_text == "切换候选文字方向") then
            local switch_to_val = ""
            if env.text_orientation == "horizontal" then
                switch_to_val = "vertical"
            else
                switch_to_val = "horizontal"
            end
            config:set_string("style/text_orientation", switch_to_val) -- 重写 horizontal
        elseif (cand_text == "切换编码区位样式") then
            local switch_to_val = not env.inline_preedit_style
            config:set_bool("style/inline_preedit", switch_to_val) -- 重写 inline_preedit
        elseif (cand_text == "切换候选序号样式") then
            if env:Config_get("menu/alternative_select_labels")[1] == 1 then
                env:Config_set("menu/alternative_select_labels", env.alter_labels)
            else
                env:Config_set("menu/alternative_select_labels", env.normal_labels)
            end
        elseif (cand_text == "切换Emoji😂显隐") then
            local emoji_visible = env:Config_get("switches/@4/reset")
            local switch_to_val = (emoji_visible > 0) and 0 or 1
            env:Config_set("switches/@4/reset", switch_to_val)
        elseif (cand_text == "切换中英标点输出") then
            local ascii_punct_state = env:Config_get("switches/@1/reset")
            local switch_to_val = (ascii_punct_state > 0) and 0 or 1
            env:Config_set("switches/@1/reset", switch_to_val)
        elseif (cand_text == "切换半角全角符号") then
            local full_shape_state = env:Config_get("switches/@2/reset")
            local switch_to_val = (full_shape_state > 0) and 0 or 1
            env:Config_set("switches/@2/reset", switch_to_val)
        elseif (cand_text == "切换简体繁体显示") then
            local simp_tran_state = env:Config_get("switches/@3/reset")
            local switch_to_val = (simp_tran_state > 0) and 0 or 1
            env:Config_set("switches/@3/reset", switch_to_val)
        elseif (cand_text == "增加候选字体大小") then
            config:set_int("style/font_point", (env.font_point + 1))
        elseif (cand_text == "减少候选字体大小") then
            config:set_int("style/font_point", (env.font_point - 1))
        elseif (cand_text == "增加行间距的大小") then
            config:set_int("style/line_spacing", (env.line_spacing + 1))
        elseif (cand_text == "减少行间距的大小") then
            config:set_int("style/line_spacing", (env.line_spacing - 1))
        elseif (cand_text == "增加单页候选项数") then
            config:set_int("menu/page_size", (env.page_size + 1))
        elseif (cand_text == "减少单页候选项数") then
            config:set_int("menu/page_size", (env.page_size - 1))
        elseif (cand_text == "恢复分号自动上屏") then
            env:Config_set("punctuator/half_shape/;", "；")
        elseif (cand_text == "恢复常规候选按键") then
            config:set_int("menu/alternative_select_keys", 1234567890)
        elseif (cand_text == "开关短语自动上屏") then
            local switch_to_val = not env.word_auto_commit_enabled
            config:set_bool("flypy_phrase/auto_commit", switch_to_val)
        elseif (cand_text == "开关字符码区提示") then
            local charset_hint = env:Config_get("switches/@last/reset")
            local switch_to_val = (charset_hint > 0) and 0 or 1
            env:Config_set("switches/@last/reset", switch_to_val)
        elseif (cand_text == "开关中英词条空格") then
            local filters = env:Config_get("engine/filters")
            local target_filter = "lua_filter@*word_append_space*filter"
            local filter_idx = table.find_index(filters, target_filter)
            if filter_idx then
                table.remove(filters, filter_idx)
            else
                table.insert(filters, #filters, target_filter)
            end
            env:Config_set("engine/filters", filters)
        elseif (cand_text == "关闭候选注解提示") then
            config:set_int("translator/spelling_hints", 0)
            config:set_bool("radical_reverse_lookup/overwrite_comment", false) -- 重写注释为空
            env:Config_set('radical_reverse_lookup/comment_format/@last', "xform/^.+$//")
        elseif (cand_text == "禁用中英前置空格") then
            local processors = env:Config_get("engine/processors")
            local target_processor = "lua_processor@*word_append_space*processor"
            local processor_idx = table.find_index(processors, target_processor)
            if processor_idx then
                table.remove(processors, processor_idx)
            end
            env:Config_set("engine/processors", processors)
        end
        engine:apply_schema(Schema(schema.schema_id))
        return 1 -- kAccept
    end
    return 2     -- kNoop, 不做任何操作, 交给下个组件处理
end

function translator.func(input, seg, env)
    local composition = env.engine.context.composition
    if (composition:empty()) then return end
    local segment = composition:back()
    local trigger_prefix = env.switch_options or "/so" or "sopt"
    if seg:has_tag("switch_options") or (input == trigger_prefix) then
        segment.prompt = "〔" .. "切换配置选项" .. "〕"
        for _, text in ipairs(env.switch_options_menu) do
            yield(Candidate("switch_options", seg.start, seg._end, text, ""))
        end
    end
end

return {
    processor = { init = flypy_switcher.init, func = processor.func },
    translator = { init = flypy_switcher.init, func = translator.func },
}
