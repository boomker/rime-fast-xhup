require("lib/rime_helper")

local P = {}
local T = {}
local F = {}
local M = {}

local function get_filter_limit(env)
    local limit = env.candidate_cache_limit or 100
    if limit < 1 then
        return 1
    end
    return limit
end

local function ensure_translator_resources(env)
    if env.custom_phrase_tran and env.reversedb then
        return
    end

    local config = env.engine.schema.config
    local schema_id = config:get_string("schema/schema_id")
    env.reversedb = env.reversedb or ReverseLookup(schema_id)
    local schema = Schema(schema_id)
    if not env.custom_phrase_tran then
        env.custom_phrase_tran = Component.TableTranslator(env.engine, schema, "custom_phrase", "")
    end
end

local function get_record_filename()
    local system_name = detect_os()
    local user_data_dir = rime_api:get_user_data_dir()
    if system_name:lower():match("windows") then
        return string.format("%s\\lua\\pin_word_record.lua", user_data_dir)
    elseif system_name:lower():match("ios") then
        user_data_dir =
            "/private/var/mobile/Library/Mobile Documents/iCloud~dev~fuxiao~app~hamsterapp/Documents/RIME/Rime"
        return string.format("%s/lua/pin_word_record.lua", user_data_dir)
    else
        return string.format("%s/lua/pin_word_record.lua", user_data_dir)
    end
end

local function write_word_to_file(env)
    local filename = get_record_filename()
    local record_header = string.format("local pin_word_records =\n")
    local record_tailer = string.format("\nreturn pin_word_records")
    if not filename then
        return false
    end

    local fd = assert(io.open(filename, "w")) --打开
    if not fd then
        return false
    end
    fd:setvbuf("line")
    fd:write(record_header) --写入文件头部
    -- fd:flush() --刷新
    local record = table.serialize(env.pin_word_records) -- lua 的 table 对象 序列化为字符串
    fd:write(record) --写入 序列化的字符串
    fd:write(record_tailer) --写入文件尾部, 结束记录
    fd:close() --关闭
end

function M.init(env)
    local config = env.engine.schema.config
    local ok, pin_word_records = pcall(require, "pin_word_record")
    env.pin_word_records = ok and pin_word_records or {}
    env.word_quality = config:get_int("pin_word/word_quality") or 999
    env.pin_mark = config:get_string("pin_word/comment_mark") or " ᵀᴼᴾ"
    env.custom_phrase_mark = config:get_string("custom_phrase/comment_mark") or " 📌"
    env.pin_cand_key = config:get_string("key_binder/pin_cand") or "Control+t"
    env.unpin_cand_key = config:get_string("key_binder/unpin_cand") or "Control+t"
    env.candidate_cache_limit = config:get_int("pin_word/candidate_cache_limit") or 100
end

function P.init(env)
    M.init(env)
end

function T.init(env)
    M.init(env)
    ensure_translator_resources(env)
end

function F.init(env)
    M.init(env)
end

function M.fini(env)
    if env.custom_phrase_tran then
        env.custom_phrase_tran = nil
    end
    if env.reversedb then
        env.reversedb = nil
    end
end

function P.func(key, env)
    local engine = env.engine
    local context = engine.context
    local preedit_code = context.input
    local pin_unpin_keymap = {
        [env.pin_cand_key] = "pin",
        [env.unpin_cand_key] = "unpin",
    }

    if context:has_menu() and pin_unpin_keymap[key:repr()] then
        local cand = context:get_selected_candidate()
        local cand_text = cand.text:gsub(" ", "")
        if not cand then
            return 2
        end

        if not env.pin_word_records[preedit_code] then
            env.pin_word_records[preedit_code] = {}
        end

        local key_accepted = false
        local candidate_changed = false
        local idx = table.find_index(env.pin_word_records[preedit_code], cand_text)

        if key:repr() == env.pin_cand_key then
            key_accepted = true
            if not idx then
                table.insert(env.pin_word_records[preedit_code], cand_text)
                candidate_changed = true
            end
        end

        if key:repr() == env.unpin_cand_key then
            key_accepted = true
            if idx then
                table.remove(env.pin_word_records[preedit_code], idx)
                candidate_changed = true
            end
            if table.len(env.pin_word_records[preedit_code]) == 0 then
                env.pin_word_records[preedit_code] = nil
            end
        end

        if candidate_changed then
            context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
            write_word_to_file(env)
        end

        if key_accepted then
            return 1
        end
    end

    return 2 -- kNoop, 不做任何操作, 交给下个组件处理
end

function T.func(input, seg, env)
    ensure_translator_resources(env)
    local input_code = input:gsub(" ", "")
    local pin_word_tab = env.pin_word_records[input_code] or nil

    if pin_word_tab and seg:has_tag("abc") then
        for _, w in ipairs(pin_word_tab) do
            local reverse_code = (env.reversedb:lookup(w) or ""):gsub("~%l%l", "")
            if
                (utf8.len(input_code) / utf8.len(w) ~= 2)
                or w:match("[%a%d%p]+")
                or ((#reverse_code == 2) and (not reverse_code:match(input_code)))
            then
                -- 只对非完整编码的字词或不在码表里的字进行置顶, 否则会导致造词失效
                local cand = Candidate("pin_word", seg.start, seg._end, w, env.pin_mark)
                cand.quality = env.word_quality
                yield(cand)
            end
        end
    end

    -- 自定义短语的置顶字词加类型标记
    local custom_tran = env.custom_phrase_tran and env.custom_phrase_tran:query(input, seg) or nil
    if not custom_tran then
        return
    end

    local yielded = 0
    local limit = get_filter_limit(env)
    for cand in custom_tran:iter() do
        cand.type = "custom_phrase_" .. cand.type
        yield(cand)
        yielded = yielded + 1
        if yielded >= limit then
            break
        end
    end
end

function F.func(input, env)
    local pin_cands = {}
    local other_cands = {}
    local single_char_cands = {}
    local custom_phrase_cands = {}
    local pin_mark = env.pin_mark
    local custom_mark = env.custom_phrase_mark
    local raw_input = env.engine.context.input
    local pin_word_tab = env.pin_word_records[raw_input] or nil
    local other_limit = get_filter_limit(env)

    for cand in input:iter() do
        local cand_text = cand.text
        if cand.type:match("^custom_phrase") then
            cand.comment = custom_mark
            table.insert(custom_phrase_cands, cand)
        end

        if pin_word_tab and table.find_index(pin_word_tab, cand_text) then
            if #pin_cands < #pin_word_tab then
                cand.comment = pin_mark
                table.insert(pin_cands, cand)
            end
            if #pin_cands == #pin_word_tab then
                table.sort(pin_cands, function(a, b)
                    return table.find_index(pin_word_tab, a.text) < table.find_index(pin_word_tab, b.text)
                end)
            end
        elseif cand.comment:match(pin_mark) then
            table.insert(pin_cands, cand)
        else
            if #other_cands < other_limit then
                table.insert(other_cands, cand)
            else
                break
            end
        end

        if cand.type:match("^single_char") then
            table.insert(single_char_cands, cand)
        end
    end

    if #pin_cands > 0 then
        for _, cand in ipairs(pin_cands) do
            yield(cand)
        end
    elseif #single_char_cands > 0 then
        for _, cand in ipairs(single_char_cands) do
            yield(cand)
        end
    elseif #custom_phrase_cands > 0 then
        for _, cand in ipairs(custom_phrase_cands) do
            yield(cand)
        end
    end

    for _, cand in ipairs(other_cands) do
        yield(cand)
    end
end

return {
    processor = { init = P.init, func = P.func, fini = M.fini },
    translator = { init = T.init, func = T.func, fini = M.fini },
    filter = { init = F.init, func = F.func, fini = M.fini },
}
