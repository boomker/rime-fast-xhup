require("lib/string")
require("lib/metatable")

local cold_word_drop = {}
local processor = {}
local filter = {}

local function get_record_filername(record_type)
    local path_sep = "/"
    local user_data_dir = rime_api:get_user_data_dir()
    local user_distribute_name = rime_api:get_distribution_code_name()
    if user_distribute_name:lower():match("weasel") then
        path_sep = [[\]]
    end
    if user_distribute_name:lower():match("hamster") then
        user_data_dir =
            "/private/var/mobile/Library/Mobile Documents/iCloud~dev~fuxiao~app~hamsterapp/Documents/RIME/Rime"
    end
    if user_distribute_name:lower():match("ibus") then
        return string.format(
            "%s/rime/lua/cold_word_records/%s_words.lua",
            os.getenv("HOME") .. "/.config/ibus",
            record_type
        )
    else
        local file_path = string.format("%s/lua/cold_word_records/%s_words.lua", user_data_dir, record_type)
        return file_path:gsub("/", path_sep)
    end
end

local function write_word_to_file(env, record_type)
    local filename = get_record_filername(record_type)
    local record_header = string.format("local %s_words =\n", record_type)
    local record_tailer = string.format("\nreturn %s_words", record_type)
    if not filename then
        return false
    end
    local fd = assert(io.open(filename, "w")) -- 打开
    fd:setvbuf("line")
    fd:write(record_header) -- 写入文件头部
    -- fd:flush() --刷新
    local words_obj = string.format("%s_list", record_type)
    local records = table.serialize(env.words_tbl[words_obj]) -- lua 的 table 对象 序列化为字符串
    fd:write(records) -- 写入 序列化的字符串
    fd:write(record_tailer) -- 写入文件尾部, 结束记录
    fd:close() -- 关闭
end

local function append_word_to_droplist(env, ctx, action_type)
    local word = ctx.word:gsub(" ", "")
    local input_code = ctx.code:gsub(" ", "")

    if action_type == "drop" then
        table.insert(env.drop_words, word) -- 高亮选中的词条插入到 drop_list
        return true
    end

    if action_type == "hide" then
        if not env.hide_words[word] then
            env.hide_words[word] = { input_code }
            -- 隐藏的词条如果已经在 hide_list 中, 则将输入串追加到 值表中, 如: ['藏'] = {'chang', 'zhang'}
        elseif not table.find_index(env.hide_words[word], input_code) then
            table.insert(env.hide_words[word], input_code)
        end
        return true
    end

    if action_type == "reduce_freq" then
        if env.reduce_freq_words[word] then
            table.insert(env.reduce_freq_words[word], input_code)
        else
            env.reduce_freq_words[word] = { input_code }
        end
        return true
    end
end

function cold_word_drop.init(env)
    local engine = env.engine
    local config = engine.schema.config
    local _sd, drop_words = pcall(require, "cold_word_records/drop_words")
    local _sh, hide_words = pcall(require, "cold_word_records/hide_words")
    local _sr, reduce_freq_words = pcall(require, "cold_word_records/reduce_freq_words")

    env.pin_mark = config:get_string("pin_word/comment_mark") or "🔝"
    env.word_reduce_idx = config:get_int("cold_word_reduce/index") or 4
    env.drop_cand_key = config:get_string("key_binder/drop_cand") or "Control+d"
    env.hide_cand_key = config:get_string("key_binder/hide_cand") or "Control+x"
    env.reduce_cand_key = config:get_string("key_binder/reduce_fq_cand") or "Control+j"
    env.drop_words = _sd and drop_words or {}
    env.hide_words = _sh and hide_words or {}
    env.reduce_freq_words = _sr and reduce_freq_words or {}
    env.words_tbl = {
        ["drop_list"] = env.drop_words or {},
        ["hide_list"] = env.hide_words or {},
        ["reduce_freq_list"] = env.reduce_freq_words or {},
    }
end

function processor.func(key, env)
    local engine = env.engine
    local context = engine.context
    local preedit_code = context:get_script_text()
    local action_map = {
        [env.drop_cand_key] = "drop",
        [env.hide_cand_key] = "hide",
        [env.reduce_cand_key] = "reduce_freq",
    }

    if context:has_menu() and action_map[key:repr()] then
        local cand = context:get_selected_candidate()
        if not cand then
            return 2
        end
        local action_type = action_map[key:repr()]
        local ctx_map = {
            ["word"] = cand.text,
            ["code"] = preedit_code,
        }
        local res = append_word_to_droplist(env, ctx_map, action_type)

        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        if not res then
            return 2
        end

        if res then
            -- 期望被删的词和隐藏的词条写入文件(drop_words.lua, hide_words.lua)
            write_word_to_file(env, action_type)
        end

        return 1 -- kAccept
    end

    return 2 -- kNoop, 不做任何操作, 交给下个组件处理
end

function filter.func(input, env)
    local cands = {}
    local engine = env.engine
    local context = engine.context
    local preedit_str = context.input
    local drop_words = env.drop_words
    local hide_words = env.hide_words
    local word_reduce_idx = env.word_reduce_idx
    local reduce_freq_words = env.reduce_freq_words

    for cand in input:iter() do
        local cand_text = cand.text:gsub(" ", "")
        local preedit_code = cand.preedit:gsub(" ", "") or preedit_str

        local reduce_freq_list = reduce_freq_words[cand_text] or {}
        if word_reduce_idx > 1 then
            -- 前三个 候选项排除 要调整词频的词条, 要删的(实际假性删词, 彻底隐藏罢了) 和要隐藏的词条
            if reduce_freq_list and table.find_index(reduce_freq_list, preedit_code) then
                table.insert(cands, cand)
            elseif
                not (
                    table.find_index(drop_words, cand_text)
                    or (hide_words[cand_text] and table.find_index(hide_words[cand_text], preedit_code))
                )
            then
                yield(cand)
                word_reduce_idx = word_reduce_idx - 1
            end
        else
            if
                not (
                    table.find_index(drop_words, cand_text)
                    or (hide_words[cand_text] and table.find_index(hide_words[cand_text], preedit_code))
                )
            then
                table.insert(cands, cand)
            end
        end

        if #cands >= 150 then break end
    end

    for _, cand in ipairs(cands) do
        yield(cand)
    end
end

return {
    processor = {
        init = cold_word_drop.init,
        func = processor.func,
    },
    filter = {
        init = cold_word_drop.init,
        func = filter.func,
    },
}
