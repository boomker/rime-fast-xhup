-- loggger.lua
-- Copyright (C) 2023 yaoyuan.dou <douyaoyuan@126.com>

-- -- 导入log模块记录日志
-- local logEnable, log = pcall(require, "lib/logger")
-- if logEnable then
--     log.writeLog('\n')
--     log.writeLog('--- start ---')
--     log.writeLog('log from emoji_reduce.lua\n')
-- end

local M={}
local dbgFlg = true

--设置 dbg 开关
M.setDbg = function(flg)
	dbgFlg = flg

	print('runLog dbgFlg is '..tostring(dbgFlg))
end

-- local current_path = string.sub(debug.getinfo(1).source, 2, string.len("/logger.lua") * -1)
local user_data_dir = rime_api:get_user_data_dir()
M.logDoc = user_data_dir ..'runLog.txt'

M.writeLog = function (logStr)
	if nil == logStr then
		logStr = ''
	else
		logStr = tostring(logStr)
	end

	local f = io.open(M.logDoc,'a')
	if f then
		if '' == logStr then
			f:write('\n')
		else
			local timeStamp = os.date("%Y/%m/%d %H:%M:%S")
			f:write(timeStamp..'['.._VERSION..']'..'\t'..tostring(logStr)..'\n')
		end
		f:close()
	end
end

--===========================test========================
M.test = function (printPrefix)
	if nil == printPrefix then
		printPrefix = ' '
	end
	if dbgFlg then
		M.writeLog('this is a test string on new line')
		M.writeLog('this is a test string appending the last line')
		M.writeLog('runLogDoc is: '..M.logDoc)
	end
end

function M.init(...)
	--如果有需要初始化的动作，可以在这里运行
end

M.init()

return M
