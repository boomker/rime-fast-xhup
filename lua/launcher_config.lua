-- 默认应用启动或切换触发前缀为"jj"
-- 可在下行配置其他的触发前缀
local appLaunchPrefix = "af"

local commands = {
	-- 应用启动切换
	["Windows"] = {
		["jjcm"] = { "CMD", "cmd.exe" },
		["jjdn"] = { "Explorer", "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}" },
		["jjec"] = { "Excel", "excel.exe" },
		["jjwd"] = { "Word", "word.exe" },
		["jjht"] = { "画图", "mspaint.exe" },
		["jjjs"] = { "计算器", "calc.exe" },
	},
	["Darwin"] = {
		["jjjt"] = { "截图", "com.apple.screenshot.launcher" },
		["jjss"] = { "截图", "com.apple.screenshot.launcher" },
		["jjam"] = { "任务监视器", "com.apple.ActivityMonitor" },
		["jjtm"] = { "任务监视器", "com.apple.ActivityMonitor" },
		["jjsp"] = { "系统设置", "com.apple.systempreferences" },
		["jjfl"] = { "ForkLift", "com.binarynights.ForkLift-3" },
		["jjfd"] = { "Finder", "com.apple.finder" },
		["jjsf"] = { "Safari 浏览器", "com.apple.Safari" },
		["jjgc"] = { "Chrome 浏览器", "com.google.Chrome" },
		["jjch"] = { "Chrome 浏览器", "com.google.Chrome" },
		["jjff"] = { "Firefox 浏览器", "org.mozilla.firefox" },
		["jjfy"] = { "Easydict", "com.izual.Easydict" },
		["jjed"] = {
			{ "Edge 浏览器", "com.microsoft.edgemac" },
			{ "Easy 词典", "com.izual.Easydict" },
			{ "Eudic", "com.eusoft.eudic" },
		},
		["jjol"] = { "Outlook 邮箱", "com.microsoft.Outlook" },
		["jjwm"] = { "网易云音乐", "com.netease.163music" },
		["jjqw"] = { "企业微信", "com.tencent.WeWorkMac" },
		["jjww"] = { "企业微信", "com.tencent.WeWorkMac" },
		["jjwx"] = { "微信", "com.tencent.xinWeChat" },
		["jjwc"] = { "微信", "com.tencent.xinWeChat" },
		["jjqq"] = { "QQ", "com.tencent.qq" },
		["jjnv"] = { "Neovide", "com.neovide.neovide" },
		["jjvc"] = { "VSCode", "com.microsoft.VSCode" },
		["jjob"] = { "Obsidian", "md.obsidian" },
		["jjat"] = { "alacritty 终端", "org.alacritty" },
		["jjit"] = { "iTerm2 终端", "com.googlecode.iterm2" },
		["jjdl"] = { "FDM 下载", "org.freedownloadmanager.fdm6" },
	},
	["iOS"] = {},

	-- 快捷指令〔邮箱账号, 书签网址, 各种卡号(手机/银行卡/身份证), 文件夹位置〕
	["Favor"] = {
		-- [中括号]里的为索引键, 最好不要带「空 格」字符
		-- [action]里的为执行动作, "commit" 为字符上屏, "open" 为打开对象
		-- 动作名称"commit/open", 不能更改
		["mb邮箱"] = {
			["action"] = "commit",
			["items"] = {
				"000000000@gmail.com",
				"000000@yamu.com",
				"000000000000@outlook.com",
			},
		},
		["tc终端命令"] = {
			["action"] = "exec",
			["items"] = {
				["隐藏桌面图标"] = "defaults write com.apple.finder CreateDesktop false && killall Finder",
				["显示桌面图标"] = "defaults write com.apple.finder CreateDesktop true && killall Finder",
				["暗夜模式开关"] = "osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode'",
				["开启屏保"] = "osascript -e 'tell application \"System Events\" to start current screen saver'",
                ["立即熄屏"] = "pmset displaysleepnow",
                ["刷新DNS缓存"] = "dscacheutil -flushcache"
			},
		},
		["cn卡号"] = {
			["action"] = "commit",
			["items"] = {
				["电信个人"] = "00000000000",
				["移动工作"] = "00000000000",
				["招商工资"] = "6000000000000000",
				["身份证号"] = "000000000000000000",
			},
		},
		["bm书签"] = {
			["action"] = "open",
			["items"] = {
				"https://youtube.com",
				"https://bilibili.com",
				"https://github.com",
			},
		},
		["fl文件夹路径"] = {
			["action"] = "open",
			["items"] = {
				["〔下载〕文件夹"] = "~/Downloads",
				["〔文档〕文件夹"] = "~/Documents",
				["〔Rime〕用户配置"] = "~/Library/Rime",
				["〔iCloud〕文件夹"] = "~/Library/Mobile Documents",
				["〔系统应用〕文件夹"] = "/System/Applications",
				["〔Rime〕安装目录"] = "/Library/Input Methods/Squirrel.app/Contents/SharedSupport",
			},
		},
	},
}

return { appLaunchPrefix, commands }
