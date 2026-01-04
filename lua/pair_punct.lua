-- pair_punct.lua
-- author: kuroame, boomker
-- license: MIT
-- 符号成对

-- 配置說明
-- 在你的schema文件裏引入這個segmentor，需要放在abc_segmentor的前面

local logEnable, logger = pcall(require, "lib/logger")
require("lib/rime_helper")
local M = {}
local processor = {}
local segmentor = {}

local tag_prefix = "pair_punct_"

local pairTable = {
    -- ["a"] = { "`" },
    ["b"] = { "```" },
    ["c"] = { "'" },
    ["d"] = { '"' },
    [34] = { '"', '""' },
    [39] = { "'", "''" },
    -- 闭合符号不一样的
    ["e"] = { "“", "”" },
    ["f"] = { "‘", "’" },
    ["h"] = { "(", ")" },
    ["i"] = { "[", "]" },
    ["j"] = { "{", "}" },
    ["k"] = { "<", ">" },
    -- 闭合符号是全角的
    ["l"] = { "（", "）" },
    ["m"] = { "【", "】" },
    ["n"] = { "〔", "〕" },
    ["o"] = { "〚", "〛" },
    ["p"] = { "〘", "〙" },
    ["q"] = { "「", "」" },
    ["r"] = { "［", "］" },
    ["s"] = { "｛", "｝" },
    ["u"] = { "『", "』" },
    ["v"] = { "〖", "〗" },
    ["w"] = { "《", "》" },
    ["x"] = { "〈", "〉" },
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
                -- local menu = Menu()
                -- menu:add_translation(translation)
                -- pp_seg.menu = menu
                -- pp_seg.menu:prepare(7)
                local index = pp_seg.selected_index
                local cand = pp_seg:get_candidate_at(index)
                if cand then cand.preedit = opening_punct end
            end
            if segmentation:get_confirmed_position() >= pp_seg.start then
                pp_seg.status = "kConfirmed" -- auto confirm
            end
            ctx.composition:back().prompt = env.closing_punct
        end
    end
end

local function on_commit(env)
    return function(ctx)
        if env.closing_punct then
            local back = ctx.composition:back()
            if back then back:get_selected_candidate() end
            local segmentation = ctx.composition:toSegmentation()
            local pp_seg = get_pp_seg(segmentation)
            if pp_seg then
                env.engine:commit_text(env.closing_punct)
            end
            env.closing_punct = nil
        end
    end
end

function segmentor.init(env)
    env.closing_punct = nil
    local config = env.engine.schema.config
    local schema_id = config:get_string("schema/schema_id")
    local schema = Schema(schema_id)
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

function processor.init(env)
    local schema = env.engine.schema
    local config = schema.config
    local default_selkey = "1234567890"
    env.system_name = detect_os()
    env.dist_code = rime_api:get_distribution_code_name()
    env.cand_menu_layout = config:get_bool("style/horizontal")
    env.pair_toggle = config:get_string("pair_symbol/toggle") or "off"
    env.candidate_layout = config:get_string("style/candidate_list_layout")
    env.select_keys = config:get_string("menu/alternative_select_keys") or default_selkey
end

function processor.func(key, env)
    local key_code = key.keycode
    local key_value = key:repr()
    local schema = env.engine.schema
    local context = env.engine.context
    local input_code = context.input
    local page_size = schema.page_size
    local preedit_text = context:get_script_text()

    if env.pair_toggle == "off" then return 2 end
    local composition = context.composition

    local special_key_map = {
        [34] = "p", -- quotedbl
        [39] = "p", -- apostrophe
        ["space"] = "1",
        ["return"] = "1",
        ["Return"] = "1",
    }
    local ascii_mode = context:get_option("ascii_mode")
    local unpair_flag = context:get_option("symbol_unpair_flag")
    if (special_key_map[key_code] == "p") and composition:empty() and (not unpair_flag) then
        if ascii_mode then
            context:push_input(pairTable[key_code][2])
            env.engine:process_key(KeyEvent(tostring("Left")))
        else
            context:push_input(pairTable[key_code][1])
            context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        end
        return 1                                        -- kAccept
    end

    if (special_key_map[key_value] == "1") then
        if input_code:match("^%p%a+%p$") and ascii_mode then
            env.engine:commit_text(input_code)
        elseif input_code:match("^%p$") then
            env.engine:commit_text(preedit_text)
        else
            return 2
        end
        context:clear()
        return 1
    end

    local segment = composition and composition:back()
    if input_code:match("^[/~@%*%|]") then return 2 end
    if not (segment and segment.menu) then return 2 end
    if not input_code:match("%p") then return 2 end

    local idx = segment.selected_index
    local select_keys = env.select_keys
    local cand_menu_layout = env.cand_menu_layout
    local candidate_layout = env.candidate_layout

    local selected_cand_index = get_selected_candidate_index(key_value, idx, select_keys, page_size)
    if context:has_menu() and (selected_cand_index > 0) and input_code:match("^[`<%(%[{]$") then
        local selected_cand = segment:get_candidate_at(selected_cand_index)
        local cand_text = selected_cand and selected_cand.text
        local symkey = nil
        for k, v in pairs(pairTable) do
            if (#v >= 1) and (v[1] == cand_text) then
                symkey = k
            end
        end
        if not symkey then return 2 end
        if env.system_name:lower():match("android") then
            for o = 1, tonumber(selected_cand_index) do
                env.engine:process_key(KeyEvent(tostring("Down")))
            end
        else
            context:clear()
            context:push_input(pairTable[symkey][1])
            return 1 -- kAccept
        end
        -- elseif (candidate_layout == "stacked") or (cand_menu_layout == false) then
        --     for i = 1, tonumber(selected_cand_index) do
        --         env.engine:process_key(KeyEvent(tostring("Down")))
        --     end
        -- else
        --     for j = 1, tonumber(selected_cand_index) do
        --         env.engine:process_key(KeyEvent(tostring("Right")))
        --     end
        -- end
        return 1 -- kAccept
    end

    return 2
end

function segmentor.func(segmentation, env)
    local symkey = nil
    local cand_text = nil
    local context = env.engine.context
    local config = env.engine.schema.config

    local pair_toggle = config:get_string("pair_symbol/toggle") or "off"
    if pair_toggle == "off" then return true end
    if segmentation:empty() then return true end

    local csp = segmentation:get_current_start_position() + 1
    if context:has_menu() or context:is_composing() then
        local cand = context:get_selected_candidate()
        cand_text = cand and cand.text
    end
    local input = segmentation.input:sub(0, csp)
    if cand_text and (input ~= cand_text) then input = cand_text end
    for k, v in pairs(pairTable) do
        if (#v >= 1) and (v[1] == input) then
            symkey = k
        end
    end
    if not symkey then return true end
    local match_start = segmentation:get_current_start_position()
    local match_end = segmentation:get_current_start_position() + 1
    local seg = Segment(match_start, match_end)
    seg.tags = Set({ tag_prefix .. symkey })
    segmentation:add_segment(seg)
    segmentation:forward()
    return true
end

return {
    processor = { init = processor.init, func = processor.func, fini = M.fini },
    segmentor = { init = segmentor.init, func = segmentor.func, fini = M.fini },
}
