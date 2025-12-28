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

local function save_entry(env, code)
    local entry       = DictEntry()
    entry.text        = code -- 上屏英文本身
    entry.weight      = 1
    entry.custom_code = code -- 编码 + 空格
    env.en_memory:update_userdict(entry, 1, "")
    if code:match("%u") then
        save_entry(env, code:lower())
    end
end

function T.init(env)
    local context = env.engine.context
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
    env.notifier_commit_en = context.commit_notifier:connect(function(ctx)
        local segment = ctx.composition:back()
        local cand = ctx:get_selected_candidate()
        local cand_text = cand and cand.text
        if (cand and segment and segment:has_tag("make_en_word")) or
            (cand and cand_text:match("^%a[%a%p]+$") and env.enable_en_make_word)
        then
            env.enable_en_make_word = false
            local file = assert(io.open(env.dict_path, "a"))
            local record = cand_text .. "\t" .. cand_text .. "\t100000"

            save_entry(env, cand_text)
            file:write(record .. "\n"):close()
        end
    end)
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
end

function T.func(input, seg, env)
    if seg:has_tag("make_en_word") then -- 输入开头必须是 `~`
        local cand_text = input:gsub(",", " ")
        yield(Candidate("en_custom", seg.start, seg._end, cand_text, ""))
    end
    if input:match("^%a[%a%p]+\\$") then -- 输入末尾必须是 `\`
        local inp = input:sub(1, -2):gsub(" ", "")
        local record = inp .. "\t" .. inp .. "\t100000"
        if not user_dict_exist(record, env.dict_path) then
            env.enable_en_make_word = true
            yield(Candidate("en_custom", seg.start, seg._end, inp, "✅"))
        end
    end
end

return T
