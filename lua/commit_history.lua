
local reload_env = require("tools/env_api")
local T = {}
local history_list = {}

local function is_candidate_in_type(cand, excluded_types)
    local cs = cand:get_genuines()
    for _, c in pairs(cs) do
        if table.find_index(excluded_types, c.type) then
            return true
        end
    end
    return false
end

function T.init(env)
    reload_env(env)
    local config = env.engine.schema.config
    local history_num_max = config:get_string("history" .. "/history_num_max") or 30
    local excluded_types = env:Config_get("history" .. "/excluded_types") or {}
    if #history_list >= tonumber(history_num_max) then
        table.remove(history_list, 1)
    end
    env.notifier_commit_history = env.engine.context.commit_notifier:connect(function(ctx)
        local cand = ctx:get_selected_candidate()
        if cand and not is_candidate_in_type(cand, excluded_types) then
            table.insert(history_list, cand)
        end
    end)
end

function T.fini(env)
    env.notifier_commit_history:disconnect()
end

function T.func(input, seg, env)
    local config = env.engine.schema.config
    local composition = env.engine.context.composition
    if (composition:empty()) then return end
    local segment = composition:back()
    local trigger_prefix = config:get_string("history" .. "/prefix") or "/hs"
    local prompt = config:get_string("history" .. "/tips") or "上屏历史"
    if seg:has_tag("history") or (input == trigger_prefix) then
        segment.prompt = "〔" .. prompt .. "〕"
        for i = #history_list, 1, -1 do
            local cand = Candidate("history", seg.start, seg._end, history_list[i].text, "")
            local cand_uniq = UniquifiedCandidate(cand, cand.type, cand.text, cand.comment)
            cand_uniq.quality = 999
            yield(cand_uniq)
        end
    end
end

return T
