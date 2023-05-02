-- local puts = require("tools/debugtool")

-- ============================================================= translator

local translator = {}

local history_list = {}

function translator.init(env)
    env.notifier_commit_history = env.engine.context.commit_notifier:connect(function (ctx)
        local cand = ctx:get_selected_candidate()
        table.insert(history_list, cand)
    end)
end

function translator.fini(env)
    env.notifier_commit_history:disconnect()
end

function translator.func(input, seg, env)
    if (seg:has_tag("history") or input == "hisz") then
        -- for _, v in ipairs(history_list) do
        for i = #history_list , 1 , -1 do
            local cand = Candidate("history", seg.start, seg._end, history_list[i].text, "history")
            local cand_uniq = UniquifiedCandidate(cand, cand.type, cand.text, cand.comment)
            yield(cand_uniq)
        end
    end
end

return {
    translator = { init = translator.init, func = translator.func, fini = translator.fini }
}
