local P = {}

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
    local key_event = accept and KeyEvent(accept:get_string())
    local send_key_event = send_key and KeySequence(send_key:get_string())
    local sequence = send_sequence and KeySequence(send_sequence:get_string())
    if match_pattern and key_event and sequence then
        return { match = match_pattern, accept = key_event, send_sequence = sequence }
    elseif tag_match and key_event and sequence then
        return { tag = tag_match, accept = key_event, send_sequence = sequence }
    elseif tag_match and send_key then
        return { tag = tag_match, accept = key_event, send_sequence = send_key_event }
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
    local input_code = context.input
    if env.redirecting then return 2 end
    if not input_code then return 2 end

    if not (context.composition or context.composition:back()) then return 2 end
    local segment = context.composition:back()
    if (not segment) then return 2 end
    local tags = segment.tags

    for _, binding in ipairs(env.bindings) do
        -- 只有当按键和当前输入的模式都匹配的时候，才起作用
        local match_tag = (not tags:empty()) and binding.tag and tags[binding.tag]
        local match_input = binding.match and rime_api.regex_match(input_code, binding.match)
        if key_event:eq(binding.accept) and (match_input or match_tag) then
            env.redirecting = true
            for _, key in ipairs(binding.send_sequence:toKeyEvent()) do
                env.engine:process_key(key)
            end
            env.redirecting = false
            return 1
        end
    end
    return 2
end

return P
