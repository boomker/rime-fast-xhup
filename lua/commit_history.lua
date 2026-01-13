local P = {}
local T = {}

local function candidate_in_type(cand, excluded_types)
    local ct = cand:get_genuines()
    local cand_txt = cand.text
    if cand_txt:match("[%p]") then return true end
    for _, c in pairs(ct) do
        if table.find_index(excluded_types, c.type) then
            return true
        end
    end
    return false
end

function P.init(env)
    local config = env.engine.schema.config
    env.mem = Memory(env.engine, env.engine.schema)
    env.prompt = config:get_string("history" .. "/tips") or "上屏历史"
    env.remove_user_word_key = config:get_string("key_binder/remove_user_word") or "Control+r"
end

function P.func(key, env)
    local engine = env.engine
    local context = engine.context
    local composition = context.composition
    if composition:empty() then return 2 end
    local segment = composition:back()
    if segment.prompt:match(env.prompt) and (key:repr() == env.remove_user_word_key) then
        local cand = context:get_selected_candidate()
        local cand_comment = cand and cand.comment
        if (not cand) or (not cand_comment) then return end
        env.mem:user_lookup(cand_comment, true)
        for entry in env.mem:iter_user() do
            if entry.text == cand.text then
                local de       = DictEntry()
                de.text        = cand.text
                de.weight      = 0
                de.custom_code = cand_comment:gsub("%s+$", "") .. " "
                env.mem:update_userdict(de, -1, "")
            end
        end
    end
    return 2
end

function P.fini(env)
    if env.mem then
        env.mem:disconnect()
        env.mem = nil
    end
end

function T.init(env)
    env.history_list = {}
    local excluded_types = { "punct" }
    local context = env.engine.context
    local config = env.engine.schema.config
    env.tag = config:get_string("history" .. "/tag") or "history"
    env.prompt = config:get_string("history" .. "/tips") or "上屏历史"
    env.trigger_prefix = config:get_string("history" .. "/prefix") or "/hs"
    env.initial_quality = config:get_int("history" .. "/initial_quality") or 999
    env.comment_max_length = config:get_int("history" .. "/comment_max_length") or 9

    local history_num_max = config:get_string("history" .. "/max_count") or 30
    if #env.history_list >= tonumber(history_num_max) then
        table.remove(env.history_list, 1)
    end

    env.notifier_commit_history = context.commit_notifier:connect(function(ctx)
        local cand = ctx:get_selected_candidate()
        if cand and (not candidate_in_type(cand, excluded_types)) then
            table.insert(env.history_list, cand)
        end
    end)
end

function T.func(input, seg, env)
    local context = env.engine.context
    local composition = context.composition
    if composition:empty() then return end
    if #env.history_list < 1 then return end
    local segment = composition:back()
    local commit_history = context.commit_history
    if seg:has_tag(env.tag) or (input == env.trigger_prefix) then
        segment.prompt = "〔" .. env.prompt .. "〕"
        local his_cands = env.history_list
        local comment_max_length = env.comment_max_length
        if (not commit_history:empty()) then
            local ch_text = commit_history:back().text
            if ch_text ~= his_cands[#his_cands].text then
                local cand = Candidate("history", seg.start, seg._end, ch_text, "")
                table.insert(env.history_list, cand)
            end
        end
        for i = #his_cands, 1, -1 do
            local cand = his_cands[i]
            cand = Candidate("history", seg.start, seg._end, cand.text, cand.preedit)
            local cand_comment = cand.comment:sub(1, comment_max_length)
            local cand_uniq = cand:to_uniquified_candidate(cand.type, cand.text, cand_comment)
            cand_uniq.quality = env.initial_quality
            yield(cand_uniq)
        end
    end
end

function T.fini(env)
    if env.notifier_commit_history then
        env.notifier_commit_history:disconnect()
        env.notifier_commit_history = nil
    end
end

return {
    processor = { init = P.init, func = P.func, fini = P.fini },
    translator = { init = T.init, func = T.func, fini = T.fini },
}
