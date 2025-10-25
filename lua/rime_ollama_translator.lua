-- ollama_translator.lua
local os = require("os")
local io = require("io")

-- UTF-8 character count function
local function utf8_len(str)
    local _, count = string.gsub(str, "[^\128-\193]", "")
    return count
end

-- Configuration variables
local config = {
    host = "http://127.0.0.1:11434",
    model = "gemma3:latest",
    min_length = 2,
    timeout = 10,
    debug = false,  -- Default: no log output
    prompt = "请将中文「%s」翻译成日语，仅输出翻译结果，不要解释"
}

local log_file = "/tmp/rime_ollama_translator.log"
local translation_cache = {}
local prompt_index = 1
local last_query = { text = "", len = 0, time = 0 }
local last_max_text = ""
local last_max_time = 0
local pending_query = {}

local function log(message)
    if config.debug then
        local f = io.open(log_file, "a")
        if f then
            f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. message .. "\n")
            f:close()
        end
    end
end

local function query_ollama(prompt)
    log("Requesting translation: " .. prompt)
    local escaped = prompt:gsub('"', '\\"'):gsub("\\", "\\\\")
    local json = string.format('{"model":"%s","prompt":"%s","stream":false}', config.model, escaped)
    local cmd = string.format('curl -s -m %d -X POST -H "Content-Type: application/json" -d "%s" %s/api/generate', config.timeout, json:gsub('"', '\\"'), config.host)
    log("Executing: " .. cmd)

    local handle = io.popen(cmd)
    local resp = handle and handle:read("*a") or ""
    if handle then handle:close() end

    log("Response: " .. resp)
    local result = resp:match('"response":"(.-)"[,}]')
    if result then
        result = result:gsub('\\n', ' '):gsub('\\"', '"'):gsub('\\r', ''):gsub('\\\\', '\\')
        result = result:match("^%s*(.-)%s*$")
        return result
    end
    return nil
end

local function is_chinese_text(text)
    local has_chinese = false
    local byte_count = 0
    for i = 1, #text do
        local byte = string.byte(text, i)
        if byte >= 0xE4 and byte <= 0xE9 then
            local byte2 = string.byte(text, i + 1)
            local byte3 = string.byte(text, i + 2)
            if byte2 and byte3 and byte2 >= 0x80 and byte2 <= 0xBF and byte3 >= 0x80 and byte3 <= 0xBF then
                has_chinese = true
                break
            end
        end
        if byte > 127 then byte_count = byte_count + 1 end
    end
    return has_chinese or (byte_count > 0 and not text:match("^[%w%s%p]*$"))
end

local function ollama_translator_filter(input, env)
    log("=== Processing started ===")
    local candidates = {}
    for cand in input:iter() do
        table.insert(candidates, cand)
    end

    if #candidates > 1 then
        local first = candidates[1]
        local text = first.text
        local len = utf8_len(text)
        log("Need translation: " .. text .. " (len=" .. len .. ")")

        if len >= config.min_length and is_chinese_text(text) then
            if translation_cache[text] then
                local t = translation_cache[text]
                log("Using cache: " .. t)
                pending_query[text] = nil
                table.insert(candidates, 2, Candidate("ollama", first.start, first._end, t, "🌐"))
            elseif not pending_query[text] then
                pending_query[text] = os.time()
                log("Mark pending: " .. text)
            else
                pending_query[text] = nil
                local prompt = string.format(config.prompt, text)
                local t = query_ollama(prompt)
                if t and t ~= text then
                    translation_cache[text] = t
                    table.insert(candidates, 2, Candidate("ollama", first.start, first._end, t, "🌐"))
                    log("Do actual query and cache: " .. text)
                else
                    log("Translation failed: " .. tostring(t))
                end
            end
        end
    end

    -- clean pending_query, auto clean the item that not accessed in 1 minute
    local now = os.time()
    for k, ts in pairs(pending_query) do
        if now - ts > 60 then
            pending_query[k] = nil
        end
    end

    for _, c in ipairs(candidates) do
        yield(c)
    end
end

log("Module loaded successfully")
return ollama_translator_filter
