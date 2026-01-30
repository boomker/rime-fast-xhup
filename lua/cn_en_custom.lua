require("lib/rime_helper")

local T = {}

local function user_dict_exist(word_record, path)
    local file = assert(io.open(path, "r")) --打开
    for line in file:lines() do
        if line == word_record then
            file:close()
            return true
        end
    end
    file:close()
    return false
end

local function save_entry(env, cand_or_text)
    local text = (type(cand_or_text) == string) and cand_or_text or cand_or_text.text
    if text:match("[a-zA-Z]") then
        local entry = DictEntry()
        entry.text = text -- 上屏英文本身
        entry.weight = 1
        entry.custom_code = text .. " " -- 编码 + 空格
        env.en_memory:update_userdict(entry, 1, "")
        if text:match("%u") then
            save_entry(env, text:lower())
        end
    else
        local entry = DictEntry()
        entry.text = text -- 上屏文
        entry.weight = 1
        entry.custom_code = cand_or_text.comment .. " " -- 编码 + 空格
        env.cn_memory:update_userdict(entry, 1, "")
    end
end

function T.init(env)
    local context = env.engine.context
    local config = env.engine.schema.config
    local cn_schema = Schema("flypy_xhfast")
    local en_schema = Schema("easy_en")
    local dict_name = "en_dicts/en_custom.dict.yaml"
    local user_data_dir = rime_api:get_user_data_dir()
    if detect_os():lower() == "windows" then
        env.dict_path = string.format("%s/%s", user_data_dir, dict_name):gsub("/", "\\")
    elseif detect_os():lower() == "ios" then
        user_data_dir =
            "/private/var/mobile/Library/Mobile Documents/iCloud~dev~fuxiao~app~hamsterapp/Documents/RIME/Rime"
        env.dict_path = string.format("%s/%s", user_data_dir, dict_name)
    else
        env.dict_path = string.format("%s/%s", user_data_dir, dict_name)
    end

    env.enable_en_make_word = false
    env.en_memory = Memory(env.engine, en_schema)
    env.cn_memory = Memory(env.engine, env.engine.schema, "free_make_word")
    env.en_tag = config:get_string("make_en_word/tag") or "make_en_word"
    env.cn_tag = config:get_string("free_make_word/tag") or "free_make_word"
    env.cn_make_word_prefix = config:get_string("free_make_word/prefix") or "`/"
    env.free_make_word_tran = Component.Translator(env.engine, cn_schema, "", "script_translator@free_make_word")

    local function handle_save_userdict(ctx)

        local segment = ctx.composition:back()
        local cand = ctx:get_selected_candidate()
        if not cand then return end

        local cand_text = cand.text
        if segment:has_tag(env.cn_tag) then
            if cand.comment:match("^[a-zA-Z]+$") then
                save_entry(env, cand)
            end
        elseif segment:has_tag(env.en_tag) or
            (cand_text:match("^%a[%a%p]+$") and env.enable_en_make_word)
        then
            env.enable_en_make_word = false
            local file = assert(io.open(env.dict_path, "a"))
            local record = cand_text .. "\t" .. cand_text .. "\t100000"

            save_entry(env, cand)
            file:write(record .. "\n"):close()
        end
    end

    env.notifier_commit_en = context.commit_notifier:connect(handle_save_userdict)
end

function T.fini(env)
    if env.notifier_commit_en then
        env.notifier_commit_en:disconnect()
        env.notifier_commit_en = nil
    end
    if env.en_memory then
        env.en_memory:disconnect()
        env.en_memory = nil
    end
    if env.cn_memory then
        env.cn_memory:disconnect()
        env.cn_memory = nil
    end
    if env.free_make_word_tran then
        env.free_make_word_tran:disconnect()
        env.free_make_word_tran = nil
    end
end

function T.func(input, seg, env)

    local context = env.engine.context
    local raw_input_code = context.input
    local composition = context.composition
    if composition:empty() then return end

    local segment = composition:back()
    -- local has_finished_seg = segment:has_finished_segmentation()

    -- if has_finished_seg then
    --     local seg_start = segment:get_confirmed_position() + 1
    --     raw_input_code = raw_input_code:sub(seg_start, #raw_input_code)
    -- end
    if seg:has_tag(env.cn_tag) then -- 输入必须 ``/`
        local prefix = env.cn_make_word_prefix
        local query_encode = raw_input_code:match("^" .. prefix .. "([^=]+)")
        local cand_comment = raw_input_code:match("=(.+)$") or " ~造词中..."
        local word_cands = env.free_make_word_tran:query(query_encode, segment) or nil
        if not word_cands then return end

        for cand in word_cands:iter() do
            local free_cand = Candidate("cn_custom", seg.start, seg._end, cand.text, cand_comment)
            yield(free_cand)
        end
    end

    if seg:has_tag(env.en_tag) then -- 输入开头必须是 `~`
        local cand_text = input:gsub(",", " ")
        yield(Candidate("en_custom", seg.start, seg._end, cand_text, ""))
    end
    if input:match("^%a[%a%p]+\\$") then -- 输入末尾必须是 `\`
        local inp = input:sub(1, -2):gsub(" ", "")
        local record = inp .. "\t" .. inp .. "\t100000"
        if not user_dict_exist(record, env.dict_path) then
            env.enable_en_make_word = true
            local en_cand = Candidate("en_custom", seg.start, seg._end, inp, " ᵀᴼᴾ")
            en_cand.quality = 999
            yield(en_cand)
        end
    end
end

return T
