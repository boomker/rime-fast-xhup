-- 默认应用启动或切换触发前缀为"jj"
-- 可在下行配置其他的触发前缀
local appLaunchPrefix = "/jk"
local favorCmdPrefix = "/kj"

local commands = {
	-- 应用启动切换
	["Windows"] = {
		["/jcm"] = { "CMD", "cmd.exe" },
		["/jwd"] = { "Word", "word.exe" },
		["/jec"] = { "Excel", "excel.exe" },
		["/jjs"] = { "计算器", "calc.exe" },
		["/jht"] = { "画图", "mspaint.exe" },
		["/jdn"] = { "Explorer", "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}" },
	},
	["MacOS"] = {
		["/jjt"] = { "截图录屏", "com.apple.screenshot.launcher" },
		["/jss"] = { "截图录屏", "com.apple.screenshot.launcher" },
		-- ["/jam"] = { "任务监视器", "com.apple.ActivityMonitor" },
		["/jtm"] = { "任务监视器", "com.apple.ActivityMonitor" },
		["/jsp"] = { "系统设置", "com.apple.systempreferences" },
		["/jdt"] = { "磁盘工具", "com.apple.DiskUtility" },
		["/jlt"] = { "Latest", "com.max-langer.Latest" },
		["/jal"] = { "Applite", "dev.aerolite.Applite" },
		["/jfd"] = {
			{ "Finder 访达", "com.apple.finder" },
			{ "PathFinder", "com.cocoatech.PathFinder" },
			{ "FDM 下载", "org.freedownloadmanager.fdm6" },
		},
		["/jsf"] = { "Safari 浏览器", "com.apple.Safari" },
		["/jgc"] = { "Chrome 浏览器", "com.google.Chrome" },
		["/jch"] = { "Chrome 浏览器", "com.google.Chrome" },
		["/jff"] = { "Firefox 浏览器", "org.mozilla.firefox" },
		["/jed"] = { "Edge 浏览器", "com.microsoft.edgemac" },
		["/jfy"] = { "Eudic 词典翻译", "com.eusoft.eudic" },
		["/jam"] = { "AirMail", "it.bloop.airmail2" },
		["/jol"] = { "Outlook 邮箱", "com.microsoft.Outlook" },
		["/jtg"] = { "Telegram", "com.tdesktop.Telegram" },
		["/jqq"] = { "QQ", "com.tencent.qq" },
		["/jwx"] = { "微信", "com.tencent.xinWeChat" },
		["/jwc"] = { "微信", "com.tencent.xinWeChat" },
		["/jqw"] = { "企业微信", "com.tencent.WeWorkMac" },
		["/jww"] = { "企业微信", "com.tencent.WeWorkMac" },
		["/jwm"] = { "网易云音乐", "com.netease.163music" },
		["/jnm"] = { "网易云音乐", "com.netease.163music" },
		["/jii"] = { "iina 播放器", "com.colliderli.iina" },
		["/job"] = { "Obsidian 笔记", "md.obsidian" },
		["/jnv"] = { "Neovide 编辑器", "com.neovide.neovide" },
		["/jvc"] = { "VSCode 编辑器", "com.microsoft.VSCode" },
		["/jat"] = { "alacritty 终端", "org.alacritty" },
		["/jit"] = { "iTerm2 终端", "com.googlecode.iterm2" },
		["/jpf"] = { "PathFinder", "com.cocoatech.PathFinder" },
		["/jfl"] = { "ForkLift", "com.binarynights.ForkLift-3" },
		["/jdl"] = { "FDM 下载", "org.freedownloadmanager.fdm6" },
		["/jpr"] = { "PDF Reader", "com.brother.pdfreaderprofree.mac" },
	},
	["iOS"] = {},

	-- 快捷指令〔邮箱账号, 书签网址, 各种卡号(手机/银行卡/身份证), 文件夹位置〕
	["Favors"] = {
		-- [中括号]里的为索引键, *不要*带「空 格」字符
		-- [action]里的为执行动作, "commit" 为字符上屏, "open" 为打开对象
		-- 动作名称"commit/open/exec", 不能更改
		[1] = {
			["menu_name"] = "mb邮箱",
			["action"] = "commit",
			["submenu_items"] = {
				"000000000@gmail.com",
				"000000000@outlook.com",
			},
		},
		[2] = {
			["menu_name"] = "cn卡号",
			["action"] = "commit",
			["submenus"] = {
				[1] = "d电信个人",
				[2] = "m移动工作",
				[3] = "g公积金号",
				[4] = "z招商工资",
				[5] = "f浦发工资",
				[6] = "s身份证号",
			},
			["submenu_items"] = {
				[1] = "1",
				[2] = "1",
				[3] = "1",
				[4] = "6",
				[5] = "6",
				[6] = "4",
			},
		},
		[3] = {
			["menu_name"] = "rp密码>",
			["action"] = "commit",
			["submenus"] = {
				[1] = "a-6位随机密码",
				[2] = "s-8位随机密码",
				[3] = "c-10位随机密码",
				[4] = "d-12位随机密码",
				[5] = "e-14位随机密码",
				[6] = "f-16位随机密码",
			},
            ["submenu_items"] = {
				[1] = "6位随机密码",
				[2] = "8位随机密码",
				[3] = "10位随机密码",
				[4] = "12位随机密码",
				[5] = "14位随机密码",
				[6] = "16位随机密码",
			},
		},
		[4] = {
			["menu_name"] = "bm书签",
			["action"] = "open",
			["submenus"] = {
				[1] = "B站",
				[2] = "Y油管",
				[3] = "GitHub",
			},
			["submenu_items"] = {
				[1] = "https://bilibili.com",
				[2] = "https://youtube.com",
				[3] = "https://github.com",
			},
		},
		[5] = {
			["menu_name"] = "tc终端命令",
			["action"] = "exec",
			["submenus"] = {
				[1] = "d部署Rime",
				[2] = "r同步Rime",
				[3] = "b部署Fcitx",
				[4] = "f同步Fcitx",
				-- "c刷新DNS缓存",
				[6] = "s立即开启屏保",
				[7] = "l明暗模式切换",
				[10] = "x立即熄屏黑屏",
				[11] = "w窗口智能拖拽",
				[12] = "a显示所有文件",
				[15] = "i显示桌面图标",
				[16] = "h隐藏桌面图标",
				[13] = "m鼠标自然滚动",
				[14] = "t触控板自然滚动",
			},
			["submenu_items"] = {
				[10] = "pmset displaysleepnow", -- [5] = "dscacheutil -flushcache",
				[1] = "/Library/Input Methods/Squirrel.app/Contents/MacOS/squirrel --reload",
				[2] = "/Library/Input Methods/Squirrel.app/Contents/MacOS/squirrel --sync",
				[3] =
				"/Library/Input Methods/Fcitx5.app/Contents/bin/fcitx5-curl /config/addon/rime/deploy -X POST -d '{}' &",
				[4] =
				"/Library/Input Methods/Fcitx5.app/Contents/bin/fcitx5-curl /config/addon/rime/sync -X POST -d '{}' &",
				[11] = "defaults write -g NSWindowShouldDragOnGesture -bool true &",
				[13] = "defaults write com.apple.AppleMultitouchMouse MouseWheels -int 1 &",
				[14] = "defaults write com.apple.AppleMultitouchTrackpad MouseWheels -int 1 &",
				[15] = "defaults write com.apple.finder CreateDesktop true && killall Finder",
				[16] = "defaults write com.apple.finder CreateDesktop false && killall Finder",
				[12] = "defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder",
				[6] = [[osascript -e 'tell application "System Events" to start current screen saver']],
				[7] =
				[[osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to not dark mode']],
			},
		},
		[6] = {
			["menu_name"] = "fd常用文件夹",
			["action"] = "open",
			["submenus"] = {
				[1] = "D〔下载〕文件夹",
				[2] = "W〔文档〕文件夹",
				[4] = "C〔iCloud〕文件夹",
				[5] = "R〔Rime〕用户配置",
				[6] = "F〔Fcitx5〕配置目录",
				[3] = "A〔系统应用〕文件夹",
			},
			["submenu_items"] = {
				[1] = "~/Downloads",
				[2] = "~/Documents",
				[5] = "~/Library/Rime",
				[6] = "~/.local/share/fcitx5",
				[3] = "/System/Applications",
				[4] = "~/Library/Mobile Documents/com~apple~CloudDocs",
			},
		},
	},
}

return { appLaunchPrefix, favorCmdPrefix, commands }
