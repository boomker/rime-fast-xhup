local translator = {}

local history_list = {}

local function is_candidate_in_type(cand, type)
    local cs = cand:get_genuines()
    for _, c in pairs(cs) do
        if c.type == type then
            return true
        end
    end
    return false
end

function translator.init(env)
    local config = env.engine.schema.config
    local history_num_max = config:get_string("history" .. "/history_num_max") or 10
    local excluded_type = config:get_string("history" .. "/excluded_type") or {}
    if #history_list >= tonumber(history_num_max) then
        table.remove(history_list, 1)
    end
    env.notifier_commit_history = env.engine.context.commit_notifier:connect(function(ctx)
        local cand = ctx:get_selected_candidate()
        if cand and not is_candidate_in_type(cand, excluded_type) then
            table.insert(history_list, cand)
        end
    end)
end

function translator.fini(env)
    env.notifier_commit_history:disconnect()
end

---@diagnostic disable-next-line: unused-local
function translator.func(input, seg, env)
    if seg:has_tag("history") or input == "hisz" then
        for i = #history_list, 1, -1 do
            local cand = Candidate("history", seg.start, seg._end, history_list[i].text, "history")
            local cand_uniq = UniquifiedCandidate(cand, cand.type, cand.text, cand.comment)
            cand_uniq.quality = 999
            yield(cand_uniq)
        end
    end
end

return {
    translator = { init = translator.init, func = translator.func, fini = translator.fini },
}
