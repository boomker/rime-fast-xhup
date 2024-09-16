local T = {}

local rime_api_helper = require("tools/rime_api_helper")

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

function T.init(env)
    local user_data_dir = rime_api:get_user_data_dir()
    local dict_name = "en_dicts/en_custom.dict.yaml"
    if rime_api_helper.detect_os():lower() ~= "windows" then
        env.dict_path = string.format("%s/%s", user_data_dir, dict_name)
    else
        env.dict_path = string.format("%s/%s", user_data_dir, dict_name):gsub("/", "\\")
    end
end

function T.func(input, seg, env)
    if input:match("^%a[%a%p]+\\$") or input:match("^%a[%a%p]+%]$") then           -- 输入末尾必须是 `\`
        local inp = input:sub(1, -2):gsub(" ", "") -- -3对应两个末尾符号, -2对应一个
        local record = inp .. "\t" .. inp:gsub("]+", "") .. "\t100000"
        if not user_dict_exist(record, env.dict_path) then
            yield(Candidate("en_custom", seg.start, seg._end, inp, "✅"))
            local file = assert(io.open(env.dict_path, "a"))
            file:write(record .. "\n"):close()
        end
    end
end

return T
