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

local function trim_history_list(history_list, max_count)
    max_count = tonumber(max_count) or 20
    while #history_list > max_count do
        table.remove(history_list, 1)
    end
end

local function make_history_record(cand)
    if not cand then return nil end
    return {
        text = cand.text or "",
        comment = cand.comment or "",
        preedit = cand.preedit or "",
        type = cand.type or "",
    }
end

function P.init(env)
    local config = env.engine.schema.config
    local schema_id = config:get_string("schema/schema_id")
    local schema = Schema(schema_id)
    env.mem = Memory(env.engine, schema, "translator")
    env.tag = config:get_string("history" .. "/tag") or "history"
    env.prompt = config:get_string("history" .. "/tips") or "上屏历史"
    env.remove_user_word_key = config:get_string("key_binder/remove_user_word") or "Control+r"
end

function P.func(key, env)
    local engine = env.engine
    local context = engine.context
    local composition = context.composition
    if composition:empty() then return 2 end

    local segment = composition:back()
    if not segment then return 2 end

    local commit_history = context.commit_history
    if context.input:match("^;f$") and (not commit_history:empty()) then
        if key:repr() == "f" then
            local ch_text = commit_history:latest_text()
            if not ch_text then return 2 end

            env.engine:commit_text(ch_text)
            context:clear()
            return 1
        end
    end
    if segment:has_tag(env.tag) and (key:repr() == env.remove_user_word_key) then
        local cand = context:get_selected_candidate()
        local cand_comment = cand and cand.comment
        if (not cand) or (cand_comment:len() < 1) then return end

        local ok = env.mem:user_lookup(cand_comment, false)
        if not ok then return 2 end
        for entry in env.mem:iter_user() do
            if entry.text == cand.text then
                local de = DictEntry()
                de.text = cand.text
                de.weight = 0
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
        collectgarbage('collect')
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
    env.history_num_max = config:get_int("history" .. "/max_count") or 99
    env.initial_quality = config:get_int("history" .. "/initial_quality") or 999
    env.comment_max_length = config:get_int("history" .. "/comment_max_length") or 9

    trim_history_list(env.history_list, env.history_num_max)

    env.notifier_commit_history = context.commit_notifier:connect(function(ctx)
        local cand = ctx:get_selected_candidate()
        if cand and (not candidate_in_type(cand, excluded_types)) then
            local record = make_history_record(cand)
            if record then
                table.insert(env.history_list, record)
                trim_history_list(env.history_list, env.history_num_max)
            end
        end
    end)
end

function T.func(input, seg, env)
    local context = env.engine.context
    local composition = context.composition
    if composition:empty() then return end
    if #env.history_list < 1 then return end

    local segment = composition:back()
    local input_code = context.input
    local commit_history = context.commit_history
    if seg:has_tag(env.tag) or (input_code == env.trigger_prefix) then
        segment.prompt = "〔" .. env.prompt .. "〕"
        local his_cands = env.history_list
        local comment_max_length = env.comment_max_length
        if not commit_history:empty() then
            local ch_text = commit_history:back().text
            local last_record = his_cands[#his_cands]
            if ch_text ~= (last_record and last_record.text or "") then
                table.insert(env.history_list, {
                    text = ch_text,
                    comment = "",
                    preedit = "",
                    type = "history",
                })
                trim_history_list(env.history_list, env.history_num_max)
            end
        end
        for i = #his_cands, 1, -1 do
            local record = his_cands[i]
            local cand = Candidate("history", seg.start, seg._end, record.text or "", record.preedit or "")
            local cand_comment = (record.comment or ""):sub(1, comment_max_length)
            local cand_uniq = cand:to_uniquified_candidate(record.type or cand.type, cand.text, cand_comment)
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
