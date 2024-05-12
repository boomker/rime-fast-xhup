require("tools/metatable")
local idiom_abbr_expand = {}
local idiom_cands = {}

function idiom_abbr_expand.processor(key, env)
    local engine = env.engine
    local context = engine.context
    local pos = context.caret_pos
    local input_code = context.input:gsub("%s", "")
    local preedit_code_length = #input_code

    if (preedit_code_length == 4) and (pos == 4) and (key:repr() == "slash") then
        local composition = context.composition

        if composition:empty() then return 2 end
        local segment = composition:back()
        for i = 1, 30, 1 do
            local fchar_cand = segment:get_candidate_at(i)
            if not fchar_cand then return 2 end
            local fchar_cand_text = fchar_cand.text
            local cand_length = utf8.len(fchar_cand_text)
            if cand_length == 4 then
                table.insert(idiom_cands, fchar_cand_text)
            end
        end
    end

    if (preedit_code_length >= 3) and (input_code:match("^[a-z][a-z']+$")) and (key:repr() == "0") then
        local composition = context.composition

        if not composition:empty() then
            context:clear()
            if string.find(input_code, "'") then -- 已经是展开模式，则退出
                -- 清空编码中的'并发送给上下文供Rime引擎处理
                context:push_input(input_code:gsub("[^%a]", ""))
                context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
            else                                            -- 进入展开超级简拼模式
                -- 将新的简拼编码发送给上下文供Rime引擎处理
                local simp_code = input_code:gsub("[^%a]", ""):gsub("(.)", "%1'"):sub(1, -1)
                context:push_input(simp_code)
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
        and (#input == 5) and (pos == 5)
    then
        for _, val in ipairs(idiom_cands) do
            local cand = Candidate("idiom", seg.start, seg._end, val, "")
            yield(cand)
        end
        idiom_cands = {}
    end
end

return idiom_abbr_expand
