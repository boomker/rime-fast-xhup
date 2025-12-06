-- pair_punct.lua
-- author: kuroame, boomker
-- license: MIT
-- 雙符成形

-- 配置說明
-- 在你的schema文件裏引入這個segmentor，需要放在abc_segmentor的前面

-- local logEnable, log = pcall(require, "lib/logger")
-- if logEnable then
--     log.writeLog('\n')
--     log.writeLog('--- start ---')
--     log.writeLog('log from pair_punct.lua\n')
-- end

require("lib/rime_helper")
local M = {}
local processor = {}
local segmentor = {}

local tag_prefix = "pair_punct_"

local pairTable = {
    ["a"] = { "`" },
    ["b"] = { "```" },
    ["c"] = { "'" },
    ["d"] = { '"' },
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
    ["quotedbl"] = { '“', '”' },
    ["apostrophe"] = { "‘", "’" },
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
                -- log.writeLog("ct: " .. type(cand))
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
    env.system_name = detect_os()
    env.pair_toggle = config:get_string("pair_symbol/toggle") or "off"
    env.enclosed_a = config:get_string("key_binder/enclosed_cand_chars_a") or nil
    env.enclosed_b = config:get_string("key_binder/enclosed_cand_chars_b") or nil
    env.enclosed_c = config:get_string("key_binder/enclosed_cand_chars_c") or nil
    env.enclosed_d = config:get_string("key_binder/enclosed_cand_chars_d") or nil
end

function processor.func(key, env)
    local key_value = key:repr()
    local schema = env.engine.schema
    local context = env.engine.context
    local input_code = context.input
    local preedit_code = context:get_script_text()
    local page_size = schema.page_size

    if env.pair_toggle == "off" then return 2 end
    local composition = context.composition

    if key.keycode == 34 then key_value = "quotedbl" end
    local ascii_punct = context:get_option("ascii_punct")
    if (key_value == "quotedbl") and pairTable[key_value] and composition:empty() then
        if ascii_punct or env.system_name:lower():match("android") then return 2 end
        context:push_input(pairTable[key_value][1])
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        return 1                                    -- kAccept
    end

    if composition:empty() then return 2 end
    local segment = composition:back()

    if context:has_menu() or context:is_composing() then
        local cand = context:get_selected_candidate()
        if env.enclosed_a or env.enclosed_b or env.enclosed_c or env.enclosed_d then
            local matched = false
            if key_value == env.enclosed_a then
                matched = true
                env.engine:commit_text("「" .. cand.text .. "」")
            elseif key_value == env.enclosed_b then
                matched = true
                env.engine:commit_text("【" .. cand.text .. "】")
            elseif key_value == env.enclosed_c then
                matched = true
                env.engine:commit_text("（" .. cand.text .. "）")
            elseif key_value == env.enclosed_d then
                matched = true
                env.engine:commit_text("〔" .. cand.text .. "〕")
            end
            if matched then
                context:clear()
                return 1
            end
        end
    end

    local idx = segment.selected_index
    local selected_cand_index = get_selected_candidate_index(key_value, idx, page_size)

    if context:has_menu() and (key_value == "space") and input_code:match("^%p$") then
        env.engine:commit_text(preedit_code)
        context:clear()
        return 1
    end

    if context:has_menu() and (selected_cand_index > 0) and input_code:match("^[`<%(%[{]$") then
        for i = 1, tonumber(selected_cand_index) do
            env.engine:process_key(KeyEvent(tostring("Down")))
        end
        -- local cand = segment:get_candidate_at(selected_cand_index)
        -- local cand_text = cand.text
        -- context:pop_input(1)
        -- context:push_input(cand_text)
        -- context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
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
