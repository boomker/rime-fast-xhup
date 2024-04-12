require("tools/metatable")
local idiom_abbr_expand = {}
local idiom_cands = {}

function idiom_abbr_expand.processor(key, env)
    local engine = env.engine
    local context = engine.context
    local pos = context.caret_pos
    local input_code = context.input
    local preedit_code_length = #input_code

    if (table.find({ 3, 4 }, preedit_code_length))
        and (table.find({ 3, 4 }, pos)) and (key:repr() == "slash")
    then
        local composition = context.composition

        if not composition:empty() then
            local segment = composition:back()
            for i = 1, 30, 1 do
                local fchar_cand = segment:get_candidate_at(i)
                if not (fchar_cand and idiom_cands) and (i == 30) then
                    return 2 -- kNoop
                else
                    local fchar_cand_text = fchar_cand.text
                    local cand_length = utf8.len(fchar_cand_text)
                    if table.find({ 3, 4 }, cand_length) then
                        table.insert(idiom_cands, fchar_cand_text)
                    end
                end
            end
        end
    end

    if (preedit_code_length >= 4) and (input_code:match("^[a-z][a-z']+$")) and (key:repr() == "0") then
        local composition = context.composition

        if not composition:empty() then
            context:clear()
            if string.find(input_code, "'") then -- 已经是展开模式，则退出
                -- 清空编码中的'并发送给上下文供Rime引擎处理
                context:push_input(input_code:gsub("[^%a]", ""))
                context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
            else                                            -- 进入展开超级简拼模式
                -- 将新的简拼编码发送给上下文供Rime引擎处理
                context:push_input(input_code:gsub("[^%a]", ""):gsub("(.)", "%1'"):sub(1, -1))
                context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
            end
        end
    end
    return 2 -- kNoop
end

function idiom_abbr_expand.translator(input, seg, env)
    local context = env.engine.context
    local pos = context.caret_pos

    -- 四码四字词, 按下'/'时, 长词优先
    if
        idiom_cands
        and string.match(input, "^%l+%/$")
        and (table.find({ 4, 5 }, #input))
        and (table.find({ 4, 5 }, pos))
    then
        for _, val in ipairs(idiom_cands) do
            local cand = Candidate("idiom", seg.start, seg._end, val, "")
            yield(cand)
        end
        idiom_cands = {}
    end
end

return idiom_abbr_expand
