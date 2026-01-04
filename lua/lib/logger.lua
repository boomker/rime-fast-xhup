-- loggger.lua

-- -- 导入log模块记录日志
-- local logEnable, log = pcall(require, "lib/logger")

local M = {}
local dbgFlg = false
local _initialized = false
local user_data_dir = rime_api:get_user_data_dir()
M.logDoc = user_data_dir .. '/debug.log'

--设置 dbg 开关
M.setDbg = function(flag)
    dbgFlg = flag
    print('debug flag: ' .. tostring(dbgFlg))
end

local function init(logfile, filename)
    --如果有需要初始化的动作，可以在这里运行
    logfile:write('debug flag: ' .. tostring(dbgFlg))
    logfile:write('\n')
    logfile:write(filename .. ': --- debug start ---\n')
end

-- 获取调用者文件名的核心函数
local function get_caller_info(level)
    -- 1=当前函数，2=logger.log，3=调用者（用户代码）
    local info = debug.getinfo(level or 2, "Sl")
    if not info then return "unknown" end

    local source = info.source
    if source:sub(1, 1) == "@" then
        -- 提取文件名（支持Windows和Unix路径格式）
        local filename = source:match("[\\/]([^\\/]+)$"):gsub(".lua$", "") or source:sub(2)
        return filename, info.currentline or "?"
    else
        return "unknown"
    end
end

M.write = function(logStr)
    if not dbgFlg then return end

    local f = io.open(M.logDoc, 'a')
    local filename, line = get_caller_info(3)

    if not _initialized then
        init(f, filename)
        _initialized = true
    end

    if nil == logStr then
        logStr = 'null'
    else
        logStr = tostring(logStr)
    end

    if f then
        if '' == logStr then
            f:write('\n')
        else
            local timeStamp = os.date("%Y/%m/%d %H:%M:%S")
            local logmsg = string.format("[%s] [F:%s | L:%s]\t%s\n", timeStamp, filename, line, logStr)
            f:write(logmsg)
        end
        f:close()
    end
end

return M
