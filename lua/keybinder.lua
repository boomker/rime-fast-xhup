local P = {}
local Shift_Key_Map = {
    ["<"] = "Shift+less",
    [">"] = "Shift+greater",
    ["{"] = "Shift+braceleft",
    ["}"] = "Shift+braceright",
    ["("] = "Shift+parenleft",
    [")"] = "Shift+parenright",
    ["|"] = "Shift+bar",
    ["!"] = "Shift+exclam",
    ["%"] = "Shift+percent",
    ["?"] = "Shift+question",
    ["&"] = "Shift+ampersand",
    ["^"] = "Shift+asciicircum",
}

---@class KeyBinderEnv: Env
---@field redirecting boolean
---@field bindings Binding[]

---@class Binding
---element
---@field tag string
---@field match string
---@field accept KeyEvent
---@field send KeySequence
---@field send_sequence KeySequence
---@field sequence_text string

---解析配置文件中的按键绑定配置
---@param value ConfigMap
---@return Binding | nil
local function parse(value)
    local tag = value:get_value("tag")
    local match = value:get_value("match")
    local accept = value:get_value("accept")
    local send_key = value:get_value("send")
    local send_sequence = value:get_value("send_sequence")
    if (not match) and (not tag) then return nil end
    local tag_match = tag and tag:get_string()
    local match_pattern = match and match:get_string()
    local accept_str = accept and accept:get_string()
    local accept_key = accept and (Shift_Key_Map[accept_str] or accept_str)
    local key_event = accept_key and KeyEvent(accept_key)
    local send_key_event = send_key and KeySequence(send_key:get_string())
    local sequence = send_sequence and KeySequence(send_sequence:get_string())
    local sequence_text = send_sequence and send_sequence:get_string()
    if match_pattern and key_event and sequence then
        return { match = match_pattern, accept = key_event, send_sequence = sequence, sequence_text = sequence_text }
    elseif tag_match and key_event and sequence then
        return { tag = tag_match, accept = key_event, send_sequence = sequence, sequence_text = sequence_text }
    elseif tag_match and key_event and send_key then
        return { tag = tag_match, accept = key_event, send_sequence = send_key_event, sequence_text = send_key:get_string() }
    elseif match_pattern and key_event and send_key then
        return { match = match_pattern, accept = key_event, send_sequence = send_key_event, sequence_text = send_key:get_string() }
    end
    return nil
end

---@param env KeyBinderEnv
function P.init(env)
    env.redirecting = false
    ---@type Binding[]
    env.bindings = {}
    local bindings = env.engine.schema.config:get_list("key_binder/bindings")
    if not bindings then return end
    for i = 1, bindings.size do
        local item = bindings:get_at(i - 1)
        if not item then goto continue end
        local value = item:get_map()
        if not value then goto continue end
        local binding = parse(value)
        if not binding then goto continue end
        table.insert(env.bindings, binding)
        ::continue::
    end
end

---@param key_event KeyEvent
---@param env KeyBinderEnv
---@return ProcessResult
function P.func(key_event, env)
    local context = env.engine.context
    local raw_input = context.input
    if env.redirecting then return 2 end
    if not raw_input then return 2 end

    if not (context.composition or context.composition:back()) then return 2 end
    local segment = context.composition:back()
    if (not segment) then return 2 end
    local tags = segment.tags

    for _, binding in ipairs(env.bindings) do
        -- 只有当按键和当前输入的模式都匹配的时候，才起作用
        local match_tag = (not tags:empty()) and binding.tag and tags[binding.tag]
        local match_input = binding.match and rime_api.regex_match(raw_input, binding.match)
        if key_event:eq(binding.accept) and (match_input or match_tag) then
            env.redirecting = true
            for _, key in ipairs(binding.send_sequence:toKeyEvent()) do
                if key:repr() == binding.accept:repr() then
                    context:push_input(binding.sequence_text)
                else
                    env.engine:process_key(key)
                end
            end
            env.redirecting = false
            return 1
        end
    end
    return 2
end

return P
