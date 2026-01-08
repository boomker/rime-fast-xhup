require("lib/rime_helper")
local processor = {}

function processor.func(key, env)
    local kNoop = 2
    local kAccepted = 1
    -- local kRejected = 0
    local engine = env.engine
    local key_value = key:repr()
    local context = engine.context
    local input_code = context.input
    local config = engine.schema.config
    local composition = context.composition
    local page_size = engine.schema.page_size

    if composition:empty() then return kNoop end
    local segment = composition:back()
    if not (segment and segment.menu) then return kNoop end

    local default_selkey = "1234567890"
    local trigger_prefix = config:get_string("punctuator/symbol_menu_prefix") or '/vs'
    local symbol_normal_prefix = config:get_string("punctuator/symbol_normal_prefix") or '/'
    local fallback_key = config:get_string("key_binder/symbol_menu_fallback") or "slash"

    if context:has_menu() and (key_value == fallback_key) and
        input_code:match("^" .. symbol_normal_prefix .. "[a-z]+$")
    then
        context:pop_input(#input_code)
        context:push_input(trigger_prefix)
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单
        return kAccepted
    end

    if not (input_code:match("^" .. trigger_prefix)) then return kNoop end
    local selected_index = segment.selected_index or -1
    local select_keys = config:get_string("menu/alternative_select_keys") or default_selkey
    local selected_cand_idx = get_selected_candidate_index(key_value, selected_index, select_keys, page_size)
    if (selected_cand_idx >= 0) then
        local cand_text = segment:get_candidate_at(selected_cand_idx).text
        local _, _, second_prefix = cand_text:find(":?([a-z]+):?")
        context:pop_input(#trigger_prefix)
        context:push_input(symbol_normal_prefix .. second_prefix)
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单
        return kAccepted
    end

    return kNoop
end

return processor
