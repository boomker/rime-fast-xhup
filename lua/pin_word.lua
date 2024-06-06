local pin_word_records = require("pin_word_record")
local reload_env = require("tools/env_api")

local pin_word = {}
local processor = {}
local translator = {}
local filter = {}
local custom_phrase_cands = {}

local function get_record_filername()
    local user_distribute_name = rime_api:get_distribution_name()
    if user_distribute_name == "小狼毫" then
        return string.format("%s\\Rime\\lua\\pin_word_record.lua", os.getenv("APPDATA"))
    end
    local system = io.popen("uname -s"):read("*l")
    local filename = nil
    if system == "Darwin" then
        filename = string.format("%s/Library/Rime/lua/pin_word_record.lua", os.getenv("HOME"))
    elseif system == "Linux" then
        local gtk_env = os.getenv("GTK_IM_MODULE")
        filename = string.format(
            "%s/%s/rime/lua/%pin_word_record.lua",
            os.getenv("HOME"),
            gtk_env and (string.find(gtk_env, "fcitx") and ".local/share/fcitx5" or ".config/ibus")
        )
    end
    return filename
end

local function write_word_to_file()
    local filename = get_record_filername()
    local record_header = string.format("local pin_word_records =\n")
    local record_tailer = string.format("\nreturn pin_word_records")
    if not filename then
        return false
    end
    local fd = assert(io.open(filename, "w"))        --打开
    fd:setvbuf("line")
    fd:write(record_header)                          --写入文件头部
    -- fd:flush() --刷新
    local record = table.serialize(pin_word_records) -- lua 的 table 对象 序列化为字符串
    fd:write(record)                                 --写入 序列化的字符串
    fd:write(record_tailer)                          --写入文件尾部, 结束记录
    fd:close()                                       --关闭
end

local function is_excluded_type(seg)
    return function(type) return seg:has_tag(type) end
end

function pin_word.init(env)
    reload_env(env)
    env.pin_cand_key = env:Config_get("key_binder/pin_cand") or "Control+t"
    env.word_quality = env:Config_get("pin_word/word_quality") or 999
    env.pin_mark = env:Config_get("pin_word/comment_mark") or " 🔝"
    env.comment_mark = env:Config_get("custom_phrase/comment_mark") or " 📌"
    env.excluded_types = env:Config_get("pin_word/excluded_types")
    local flypy_help_pat = "recognizer/patterns/flypy_key_help"
    env.key_help_prefix = env:Config_get(flypy_help_pat):match("%^([a-z/]+).*") or "/ok"
    env.custom_phrase_tran = Component.Translator(env.engine, "", "table_translator@custom_phrase")
end

function processor.func(key, env)
    local engine = env.engine
    local config = engine.schema.config
    local context = engine.context
    local preedit_code = context:get_script_text():gsub(" ", "")

    local pin_cand_key = env.pin_cand_key or "Control+t"
    if context:has_menu() and (key:repr() == pin_cand_key) then
        local cand = context:get_selected_candidate()
        local cand_text = cand.text:gsub(" ", "")
        if not cand then return 2 end

        if not pin_word_records[preedit_code] then pin_word_records[preedit_code] = {} end
        if not table.find_index(pin_word_records[preedit_code], cand_text) then
            table.insert(pin_word_records[preedit_code], cand_text)
        end

        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        write_word_to_file()
        return 1                                    -- kAccept
    end

    return 2 -- kNoop, 不做任何操作, 交给下个组件处理
end

function translator.func(input, seg, env)
    local comment_text = env.pin_mark
    local custom_mark = env.comment_mark
    local excluded_types = env.excluded_types
    local input_code = input:gsub(" ", "")
    local pin_word_tab = pin_word_records[input_code] or nil

    if pin_word_tab and not (table.any(excluded_types, is_excluded_type(seg))) then
        for _, w in ipairs(pin_word_tab) do
            -- Fix: 一个置顶字词可能对应多个不同长度的编码(如: "字" -> `zi`, `zi[bz`)
            if string.utf8_len(input_code) / string.utf8_len(w) ~= 2 then
                -- 只对非完整编码的字词或不在码表里的字进行置顶, 否则会导致造词失效
                local cand = Candidate("pin_word", seg.start, seg._end, w, comment_text)
                cand.quality = env.word_quality
                yield(cand)
            end
        end
    end

    -- 自定义短语的置顶字词加标记
    env.custom_tran = env.custom_phrase_tran:query(input, seg)
    if not env.custom_tran then return end
    for cand in env.custom_tran:iter() do
        if not cand.text:match("<br>") then
            cand.comment = custom_mark
            table.insert(custom_phrase_cands, cand)
        end
    end
end

function filter.func(input, env)
    local pin_cands = {}
    local other_cands = {}
    local pin_mark = env.pin_mark
    local input_code = env.engine.context.input:gsub(" ", "")

    for cand in input:iter() do
        local cand_text = cand.text
        local pin_word_tab = pin_word_records[input_code] or nil
        if pin_word_tab and table.find_index(pin_word_tab, cand_text) then
            if #pin_cands < #pin_word_tab then
                cand.comment = pin_mark
                table.insert(pin_cands, cand)
            end
            if #pin_cands == #pin_word_tab then
                for i, word in ipairs(pin_word_tab) do
                    if pin_cands[i].text ~= word then
                        for j, pcand in ipairs(pin_cands) do
                            if pcand.text == word then
                                table.insert(pin_cands, i, pcand)
                                table.remove(pin_cands, j + 1)
                            end
                        end
                    end
                end
            end
        elseif cand.comment:match(pin_mark) then
            table.insert(pin_cands, cand)
        else
            table.insert(other_cands, cand)
        end
        if #other_cands >= 80 then break end
    end

    if #pin_cands > 0 then
        for _, cand in ipairs(pin_cands) do
            yield(cand)
        end
    end

    if (#custom_phrase_cands > 0) then
        for i, _cand in ipairs(custom_phrase_cands) do
            table.insert(other_cands, i, _cand)
        end
        custom_phrase_cands = {}
    end

    for _, cand in ipairs(other_cands) do
        yield(cand)
    end
end

return {
    processor = { init = pin_word.init, func = processor.func },
    translator = { init = pin_word.init, func = translator.func },
    filter = { init = pin_word.init, func = filter.func }
}
