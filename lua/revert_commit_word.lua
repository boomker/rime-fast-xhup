-- https://github.com/qiuyue0/rime-lua-sendKeyCode
-- 文件名不能变，只能是sendKeyCode.so或dll

local T = {}
require("lib/rime_helper")

if detect_os():lower() == "macos" then
    package.cpath = os.getenv("HOME") .. "/Library/Rime/lua/lib/?.so;" .. package.cpath
elseif detect_os():lower() == "linux" then
    package.cpath = os.getenv("HOME") .. "/.config/Rime/lua/lib/?.so;" .. package.cpath
end

SendKeyCode = require("sendKeyCode")

-- 创建一个固定大小的栈
local function create_stack(max_size)
    local stack = {}
    return {
        push = function(_, value)
            table.insert(stack, value) -- 压入栈顶
            if #stack > max_size then
                table.remove(stack, 1) -- 移除栈底元素
            end
        end,
        pop = function(_) -- 弹出栈顶元素
            return table.remove(stack)
        end,
        peek = function(_) -- 查看栈顶元素
            return stack[#stack]
        end,
        get_all = function(_) -- 获取所有栈元素
            return stack
        end,
    }
end

-- 捕获上屏事件并压入栈
local function on_commit(text, env)
    local length = utf8.len(text) -- 计算上屏文字长度
    env.stack:push(length) -- 将长度压入栈
end

-- 初始化环境
function T.init(env)
    env.REVERT_KEY = ""     -- 定义撤回上屏编码
    env.GOTOEND_KEY = ""    -- 定义光标移到末尾编码
    env.STACK_SIZE = 20     -- 定义栈大小，表示可以连续撤回的最大次数

    env.stack = create_stack(env.STACK_SIZE) -- 创建长度为20的栈
    env.revert_notifier = env.engine.context.commit_notifier:connect(function(ctx)
        local text = ctx:get_commit_text()
        if text and text ~= "" then
            on_commit(text, env)
        end
    end)
end

-- 主过滤逻辑
function T.func(input, seg, env)
    if (env.REVERT_KEY:len() > 1) and (input == env.REVERT_KEY) then
        env.engine.context:clear()
        local n = env.stack:pop() or 1 -- 从栈中弹出一个数字
        SendKeyCode.press_key("\b", n)
    elseif (env.GOTOEND_KEY:len() > 1) and (input == env.GOTOEND_KEY) then
        env.engine.context:clear()
        SendKeyCode.press_key("END", 1)
    end
end

-- 绑定初始化和资源释放
function T.fini(env)
    if env.revert_notifier then
        env.revert_notifier:disconnect()
    end
end

return T
