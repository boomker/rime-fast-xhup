-- helper.lua
-- List features and usage of the schema.
local T = {}

function T.func(input, seg, env)
    local composition = env.engine.context.composition
    local segment = composition:back()
    if seg:has_tag("flypy_help") then
        local table = {
            { "帮助菜单", "→ /oh" },
            { "小鹤键位", "→ /ok" },
            { "快捷指令", "→ /kj" },
            { "应用闪切", "→ /jk" },
            { "重复上屏", "→ ;ff" },
            { "以词定字", "→ 90键" },
            { "上下翻页", "→ ,]键" },
            { "二三候选", "→ ;.键" },
            { "计算器🆚", "→ /=  | cC" },
            { "组字反查", "→ /fr | rL" },
            { "LaTeX 式", "→ /lt | lT" },
            { "中文数字", "→ /nn | nN" },
            { "选项切换", "→ /so | sO" },
            { "历史上屏", "→ /hs | hH" },
            { "全角半角", "→ Ctrl+," },
            { "中英标点", "→ Ctrl+." },
            { "词条置顶", "→ Ctrl+t" },
            { "词条降频", "→ Ctrl+j" },
            { "词条隐藏", "→ Ctrl+x" },
            { "词条删除", "→ Ctrl+d" },
            { "删用户词", "→ Ctrl+k" },
            { "删上屏词", "→ Ctrl+r" },
            { "注解切换", "→ Ctrl+n" },
            { "注解上屏", "→ Ctrl+p" },
            { "单字优先", "→ Ctrl+s" },
            { "EasyDict", "→ Ctrl+y" },
            { "切换英打", "→ Ctrl+g" },
            { "切换英打", "→ Ctrl+g" },
            { "简拼展开", "→ Ctrl+q / 8" },
            { "英文方案", "→ Ctrl+Shift+E" },
            { "切换方案", "→ Ctrl+Shift+0" },
            { "表😂显隐", "→ Ctrl+Shift+4" },
            { "码区提示", "→ Ctrl+Shift+5" },
            { "繁简切换", "→ Ctrl+Shift+6" },
            { "方案选单", "→ Alt+grave(`) | F4" },
            { "精准造词", "→ grave键引导精准造词" },
            { "单词大写", "→ AZ 开头大写字母触发" },
            { "时间戳值", "→ " .. "timestamp | /wts | /uts" },
            { "日期时间", "→ " .. "date | time | /wd | /wt" },
            { "农历星期", "→ " .. "lunar | week | /nl | /wk" },
            { "最近几天", "→ " .. "/wqt | /wzt | /wmt | /wht" },
            { "最近几周", "→ " .. "/wuz | /wlk | /wxz | /wnk" },
            { "最近几月", "→ " .. "/wuy | /wlm | /wxy | /wnm" },
            { "项目地址", "→ " .. "boomker/rime-fast-xhup" },
        }
        segment.prompt = "〔帮助菜单〕"
        for _, v in ipairs(table) do
            local cand = Candidate("help", seg.start, seg._end, v[1], " " .. v[2])
            cand.quality = 999
            yield(cand)
        end
    end
end

return T
