-- pair_punct.lua
-- author: kuroame, boomker
-- license: MIT
-- 符号成对

-- 配置說明
-- 在你的schema文件裏引入這個segmentor，需要放在abc_segmentor的前面

-- local logEnable, logger = pcall(require, "lib/logger")
require("lib/rime_helper")
local M = {}
local processor = {}
local segmentor = {}

local tag_prefix = "pair_punct_"

local pairTable = {
    -- ["a"] = { "`" },
    -- 闭合符号不一样的
    ["h"] = { "(", ")" },
    ["i"] = { "[", "]" },
    ["j"] = { "{", "}" },
    ["k"] = { "<", ">" },
    -- 闭合符号是全角的
    ["d"] = { '“', '”' },
    ["e"] = { "‘", "’" },
    ["s"] = { "｛", "｝" },
    ["l"] = { "（", "）" },
    ["m"] = { "【", "】" },
    ["n"] = { "〔", "〕" },
    ["o"] = { "〚", "〛" },
    ["p"] = { "〘", "〙" },
    ["q"] = { "「", "」" },
    ["r"] = { "［", "］" },
    ["u"] = { "『", "』" },
    ["v"] = { "〖", "〗" },
    ["w"] = { "《", "》" },
    ["x"] = { "〈", "〉" },
    ['Y'] = {
        [34] = { '“', '”' },
        [39] = { "‘", "’" },
    }
}

local function get_key_char(segment)
    for tag in pairs(segment.tags) do
        if tag:sub(1, #tag_prefix) == tag_prefix then
            return tag:sub(#tag_prefix + 1)
        end
    end
    return nil
end

local function get_pp_seg(segmentation)
    for i = 0, segmentation.size - 1 do
        local seg = segmentation:get_at(i)
        if seg and get_key_char(seg) then
            return seg
        end
    end
    return nil
end

local function on_update_or_select(env)
    return function(ctx)
        local segmentation = ctx.composition:toSegmentation()
        local pp_seg = get_pp_seg(segmentation)
        if pp_seg then
            local key_char = get_key_char(pp_seg)
            local punct_pair = pairTable[key_char]
            if not punct_pair or (#punct_pair < 1) then return end
            env.closing_punct = (#punct_pair == 1) and punct_pair[1] or punct_pair[2]
            local opening_punct = punct_pair[1]
            local translation = env.echo_translator:query(opening_punct, pp_seg)
            if translation then
                local index = pp_seg.selected_index
                local cand = pp_seg:get_candidate_at(index)
                if cand then cand.preedit = opening_punct end
            end
            if segmentation:get_confirmed_position() >= pp_seg.start then
                pp_seg.status = "kConfirmed" -- auto confirm
            end
            ctx.composition:back().prompt = env.closing_punct
        end
        if ctx.composition:back() and env.defer and env.closing_punct then
            env.defer = false
            ctx.composition:back().prompt = env.closing_punct
        end
    end
end

local function on_commit(env)
    return function(ctx)
        if env.closing_punct then
            local prompt = ctx.composition:get_prompt()
            local segmentation = ctx.composition:toSegmentation()
            local pp_seg = get_pp_seg(segmentation)
            if pp_seg then
                env.engine:commit_text(env.closing_punct)
            elseif prompt and prompt:match("%p") then
                env.engine:commit_text(env.closing_punct)
            end
            env.defer = false
            env.closing_punct = nil
        end
    end
end

local function get_pair_punct_idx(op)
    if not op then return nil end
    for k, v in pairs(pairTable) do
        if (#v >= 1) and (v[1] == op) then
            return k
        end
    end
    return nil
end

function processor.init(env)
    local config         = env.engine.schema.config
    env.system_name      = detect_os()
    env.pair_toggle      = config:get_bool("pair_punct/enable") or false
    env.select_keys      = config:get_string("menu/alternative_select_keys") or '123456789'
end

function segmentor.init(env)
    local config        = env.engine.schema.config
    local schema_id     = config:get_string("schema/schema_id")
    local schema        = Schema(schema_id)
    env.closing_punct   = nil
    env.defer           = false
    env.system_name      = detect_os()
    env.pair_toggle     = config:get_bool("pair_punct/enable") or false
    env.echo_translator = Component.Translator(env.engine, schema, "", "echo_translator")
    env.update_notifier = env.engine.context.update_notifier:connect(on_update_or_select(env))
    env.select_notifier = env.engine.context.select_notifier:connect(on_update_or_select(env))
    env.commit_notifier = env.engine.context.commit_notifier:connect(on_commit(env))
end

function M.fini(env)
    if env.echo_translator or env.update_notifier
        or env.select_notifier or env.commit_notifier
    then
        env.update_notifier:disconnect()
        env.select_notifier:disconnect()
        env.commit_notifier:disconnect()
        env.echo_translator = nil
        env.update_notifier = nil
        env.select_notifier = nil
        env.commit_notifier = nil
    end
end

function processor.func(key, env)
    local key_code   = key.keycode
    local key_value  = key:repr()
    local schema     = env.engine.schema
    local context    = env.engine.context
    local input_code = context.input
    local page_size  = schema.page_size

    if not env.pair_toggle then return 2 end

    local composition = context.composition
    local ascii_mode  = context:get_option("ascii_mode")
    local unpair_flag = context:get_option("punct_unpair_flag")
    if (pairTable['Y'][key_code]) and composition:empty()
        and (not env.system_name:lower():match("android"))
        and (not ascii_mode) and (not unpair_flag)
    then
        context:pop_input(1)
        context:push_input(pairTable['Y'][key_code][1])
        return 1 -- kAccept
    end

    local segment = composition and composition:back()
    if not (segment and segment.menu) then return 2 end
    if not input_code:match('[<%(%[{]') then return 2 end

    local idx = segment.selected_index
    local select_keys = env.select_keys or "123456789"

    local selected_cand_index = get_selected_candidate_index(key_value, idx, select_keys, page_size)
    if context:has_menu() and (selected_cand_index > 0) then
        local selected_cand = segment:get_candidate_at(selected_cand_index)
        local cand_text = selected_cand and selected_cand.text
        if env.system_name:lower():match("android") then
            for i = 1, tonumber(selected_cand_index) do
                env.engine:process_key(KeyEvent(tostring("Down")))
            end
            return 1 -- kAccept
        else
            context:pop_input(1)
            context:push_input(cand_text)
            return 1 -- kAccept
        end
    end

    return 2
end

function segmentor.func(segmentation, env)
    local opening_punct = nil
    local punct_index_key = nil
    local context = env.engine.context

    if not env.pair_toggle then return true end
    if segmentation:empty() then return true end

    local csp = segmentation:get_current_start_position() + 1
    local match_start = segmentation:get_current_start_position()
    local match_end = segmentation:get_current_start_position() + 1
    local input_code = segmentation.input:sub(0, csp)
    opening_punct = string.utf8_sub(input_code, -1, -1) or nil
    if (input_code:match("^%a+%p$")) then
        opening_punct = nil
    elseif not (opening_punct and opening_punct:match("[%a%d%p]")) then
        opening_punct = input_code:gsub("%a", "")
    elseif (input_code:match("^%a+%p%a$")) then
        opening_punct = input_code:gsub("%a", "")
        punct_index_key = get_pair_punct_idx(opening_punct)
        local punct_pair = pairTable[punct_index_key]
        if (not punct_pair) or (#punct_pair < 1) then return true end
        env.closing_punct = (#punct_pair == 1) and punct_pair[1] or punct_pair[2]
        env.defer = true
        return true
    end
    if context:has_menu() and env.system_name:lower():match("android") then
        local cand = context:get_selected_candidate()
        local cand_text = cand and cand.text
        if cand_text then
            opening_punct = cand_text
        end
    end
    punct_index_key = get_pair_punct_idx(opening_punct)
    if not punct_index_key then return true end
    local seg = Segment(match_start, match_end)
    seg.tags = Set({ tag_prefix .. punct_index_key })
    segmentation:add_segment(seg)
    segmentation:forward()
    return true
end

return {
    processor = { init = processor.init, func = processor.func, fini = M.fini },
    segmentor = { init = segmentor.init, func = segmentor.func, fini = M.fini },
}
