-- helper.lua
-- List features and usage of the schema.
local T = {}

function T.func(input, seg, env)
	local composition = env.engine.context.composition
	local segment = composition:back()
	if seg:has_tag("flypy_help") or (input == "/oh") or (input == "/help") then
		local table = {
			{ "帮助菜单", "→ /oh" },
			{ "小鹤键位", "→ /ok" },
			{ "英文模式", "→ /oe" },
			{ "LaTeX式",  "→ /lt" },
			{ "中文数字", "→ /cn" },
			{ "快捷指令", "→ /fj" },
			{ "应用闪切", "→ /jk" },
			{ "选项切换", "→ /so" },
			{ "历史上屏", "→ /hs" },
			{ "计算器🆚", "→ /vs" },
			{ "二三候选", "→ ;'号键" },
			{ "上下翻页", "→ ,.号键" },
			{ "以词定字", "→ []号键" },
			{ "方案选单", "→ Alt+`" },
			{ "词条置顶", "→ Ctrl+t" },
			{ "词条降频", "→ Ctrl+j" },
			{ "词条隐藏", "→ Ctrl+x" },
			{ "词条删除", "→ Ctrl+d" },
			{ "注解切换", "→ Ctrl+n" },
			{ "注解上屏", "→ Ctrl+p" },
			{ "删用户词", "→ Ctrl+q" },
			{ "切换英打", "→ Ctrl+g" },
			{ "Easydict", "→ Ctrl+y" },
			{ "简拼展开", "→ Ctrl+0" },
			{ "中英标点", "→ Ctrl+." },
			{ "全角半角", "→ Ctrl+\\" },
			{ "繁简切换", "→ Ctrl+/" },
			{ "表😂显隐", "→ Ctrl+Shift+/" },
			{ "码区提示", "→ Ctrl+Shift+," },
			{ "以形查音", "→ ~键引导以形查音" },
			{ "精准造词", "→ `键引导精准造词" },
			{ "单词大写", "→ AZ大写字母触发" },
			{ "时间戳值", "→ " .. "timestamp | /uts" },
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
