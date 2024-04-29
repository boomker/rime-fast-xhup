-- 默认应用启动或切换触发前缀为"jj"
-- 可在下行配置其他的触发前缀
local appLaunchPrefix = "/jk"
local favorCmdPrefix = "/fj"

local commands = {
	-- 应用启动切换
	["Windows"] = {
		["/jcm"] = { "CMD", "cmd.exe" },
		["/jdn"] = { "Explorer", "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}" },
		["/jec"] = { "Excel", "excel.exe" },
		["/jwd"] = { "Word", "word.exe" },
		["/jht"] = { "画图", "mspaint.exe" },
		["/jjs"] = { "计算器", "calc.exe" },
	},
	["MacOS"] = {
		["/jjt"] = { "截图", "com.apple.screenshot.launcher" },
		["/jss"] = { "截图", "com.apple.screenshot.launcher" },
		["/jam"] = { "任务监视器", "com.apple.ActivityMonitor" },
		["/jtm"] = { "任务监视器", "com.apple.ActivityMonitor" },
		["/jsp"] = { "系统设置", "com.apple.systempreferences" },
		["/jfl"] = { "ForkLift", "com.binarynights.ForkLift-3" },
		["/jpf"] = { "PathFinder", "com.cocoatech.PathFinder" },
		["/jfd"] = { "Finder", "com.apple.finder" },
		["/jsf"] = { "Safari 浏览器", "com.apple.Safari" },
		["/jgc"] = { "Chrome 浏览器", "com.google.Chrome" },
		["/jch"] = { "Chrome 浏览器", "com.google.Chrome" },
		["/jff"] = { "Firefox 浏览器", "org.mozilla.firefox" },
		["/jed"] = {
			{ "Edge 浏览器", "com.microsoft.edgemac" },
			{ "Eudic", "com.eusoft.eudic" },
		},
		["/jfy"] = { "Eudic", "com.eusoft.eudic" },
		["/jol"] = { "Outlook 邮箱", "com.microsoft.Outlook" },
		["/jwm"] = { "网易云音乐", "com.netease.163music" },
		["/jnm"] = { "网易云音乐", "com.netease.163music" },
		["/jqw"] = { "企业微信", "com.tencent.WeWorkMac" },
		["/jww"] = { "企业微信", "com.tencent.WeWorkMac" },
		["/jwx"] = { "微信", "com.tencent.xinWeChat" },
		["/jwc"] = { "微信", "com.tencent.xinWeChat" },
		["/jqq"] = { "QQ", "com.tencent.qq" },
		["/jnv"] = { "Neovide", "com.neovide.neovide" },
		["/jvc"] = { "VSCode", "com.microsoft.VSCode" },
		["/job"] = { "Obsidian", "md.obsidian" },
		["/jat"] = { "alacritty 终端", "org.alacritty" },
		["/jit"] = { "iTerm2 终端", "com.googlecode.iterm2" },
		["/jdl"] = { "FDM 下载", "org.freedownloadmanager.fdm6" },
	},
	["iOS"] = {},

	-- 快捷指令〔邮箱账号, 书签网址, 各种卡号(手机/银行卡/身份证), 文件夹位置〕
	["Favors"] = {
		-- [中括号]里的为索引键, 最好不要带「空 格」字符
		-- [action]里的为执行动作, "commit" 为字符上屏, "open" 为打开对象
		-- 动作名称"commit/open", 不能更改
		["mb邮箱1"] = {
			["action"] = "commit",
			["items"] = {
				"ooooooooo@gmail.com",
				"ooooooooo000@outlook.com",
			},
		},
		["cn卡号2"] = {
			["action"] = "commit",
			["items"] = {
				["d电信个人1"] = "00000000000",
				["m移动工作2"] = "00000000000",
				["z招商工资3"] = "0000000000000000",
				["f浦发工资4"] = "0000000000000000",
				["s身份证号5"] = "000000000000000000",
			},
		},
		["bm书签3"] = {
			["action"] = "open",
			["items"] = {
				["B站2"] = "https://bilibili.com",
				["Y油管1"] = "https://youtube.com",
				["GitHub码托3"] = "https://github.com",
			},
		},
		["tc终端命令4"] = {
			["action"] = "exec",
			["items"] = {
				["隐藏桌面图标1"] = "defaults write com.apple.finder CreateDesktop false && killall Finder",
				["显示桌面图标2"] = "defaults write com.apple.finder CreateDesktop true && killall Finder",
				["暗夜模式开关3"] = [[osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to not dark mode']],
				["开启屏保4"] = [[osascript -e 'tell application "System Events" to start current screen saver']],
				["立即熄屏5"] = "pmset displaysleepnow",
				["刷新DNS缓存6"] = "dscacheutil -flushcache",
				["部署Rime7"] = "/Library/Input Methods/Squirrel.app/Contents/MacOS/squirrel --reload",
				["同步Rime8"] = "/Library/Input Methods/Squirrel.app/Contents/MacOS/squirrel --sync",
			},
		},
		["fp常用文件夹5"] = {
			["action"] = "open",
			["items"] = {
				["〔下载〕文件夹1"] = "~/Downloads",
				["〔文档〕文件夹2"] = "~/Documents",
				["〔系统应用〕文件夹3"] = "/System/Applications",
				["〔iCloud〕文件夹4"] = "~/Library/Mobile Documents",
				["〔Rime〕用户配置5"] = "~/Library/Rime",
				["〔Rime〕安装目录6"] = "/Library/Input Methods/Squirrel.app/Contents/SharedSupport",
			},
		},
	},
}

return { appLaunchPrefix, favorCmdPrefix, commands }
