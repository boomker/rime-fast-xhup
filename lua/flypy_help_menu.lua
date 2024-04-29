-- helper.lua
-- List features and usage of the schema.

local function translator(input, seg, env)
    local composition = env.engine.context.composition
    local segment = composition:back()
    if seg:has_tag("flypy_help") or (input == "/oh") or (input == "/help") then
        local table = {
            { '时间输出', '→ ' .. "date" .. ' | ' .. "time" },
            { '日期时间', '→ ' .. "/wd" .. ' | ' .. "/wt" },
            { '农历星期', '→ ' .. "lunar | week" },
            { '农历周几', '→ ' .. "/nl | /wk " },
            { '历史上屏', '→ /hs' },
            { '快捷指令', '→ /fj' },
            { '应用闪切', '→ /jj' },
            { '中文数字', '→ /cn' },
            { 'LaTeX式', '→ /lt' },
            { '英文模式', '→ /oe' },
            { '小鹤键位', '→ /ok' },
            { '帮助菜单', '→ /oh' },
            { '词条置顶', '→ Ctrl+t' },
            { '词条降频', '→ Ctrl+j' },
            { '词条隐藏', '→ Ctrl+x' },
            { '词条删除', '→ Ctrl+d' },
            { '注解切换', '→ Ctrl+n' },
            { '注解上屏', '→ Ctrl+p' },
            { '繁简切换', '→ Ctrl+0' },
            { '中英标点', '→ Ctrl+.' },
            { '方案选单', '→ Alt+`' },
            { '表😂显隐', '→ Ctrl+Shift+/' },
            { '码区提示', "→ Ctrl+Shift+'" },
            { '以形查音', '→ ~键引导以形查音' },
            { '精准造词', '→ `键引导精准造词' },
            { '单词大写', '→ 大写字母开头触发' },
            { '项目地址', 'boomker/rime-fast-xhup' }
        }
        segment.prompt = '〔简要说明〕'
        for _, v in ipairs(table) do
            local cand = Candidate('help', seg.start, seg._end, v[1], ' ' .. v[2])
            cand.quality = 999
            yield(cand)
        end
    end
end

return { translator = translator }
