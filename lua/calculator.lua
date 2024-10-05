-- author: https://github.com/ChaosAlphard
-- 说明 https://github.com/gaboolic/rime-shuangpin-fuzhuma/pull/41
local T = {}

function T.init(env)
	local config = env.engine.schema.config
	--   env.name_space = env.name_space:gsub('^*', '')
	local _calc_pat = config:get_string("recognizer/patterns/calculator") or nil
	T.prefix = _calc_pat and _calc_pat:match("%^([a-z/=]+).*") or "/="
	T.tips = config:get_string("calculator/tips") or "计算器"
end

local function startsWith(str, start)
	return string.sub(str, 1, string.len(start)) == start
end

-- 函数表
local calc_methods = {
	-- e, exp(1) = e^1 = e
	e = math.exp(1),
	-- π
	pi = math.pi,
    b = 100,
    q = 1000,
    w = 10000,
    m = 1000000,
}

-- random([m [,n ]]) 返回m-n之间的随机数, n为空则返回1-m之间, 都为空则返回0-1之间的小数
local function random(...)
	return math.random(...)
end
-- 注册到函数表中
calc_methods["rdm"] = random

-- 正弦
local function sin(x)
	return math.sin(x)
end
calc_methods["sin"] = sin

-- 双曲正弦
local function sinh(x)
	return (math.exp(x) - math.exp(-x)) / 2
end
calc_methods["sinh"] = sinh

-- 反正弦
local function asin(x)
	return math.asin(x)
end
calc_methods["asin"] = asin

-- 余弦
local function cos(x)
	return math.cos(x)
end
calc_methods["cos"] = cos

-- 双曲余弦
local function cosh(x)
	return (math.exp(x) + math.exp(-x)) / 2
end
calc_methods["cosh"] = cosh

-- 反余弦
local function acos(x)
	return math.acos(x)
end
calc_methods["acos"] = acos

-- 正切
local function tan(x)
	return math.tan(x)
end
calc_methods["tan"] = tan

-- 双曲正切
local function tanh(x)
	local e = math.exp(2 * x)
	return (e - 1) / (e + 1)
end
calc_methods["tanh"] = tanh

-- 反正切
local function atan(x)
	return math.atan(x)
end
calc_methods["atan"] = atan

-- 返回以弧度为单位的点(x,y)相对于x轴的逆时针角度。y是点的纵坐标，x是点的横坐标
-- 返回范围从−π到π （以弧度为单位），其中负角度表示向下旋转，正角度表示向上旋转
-- 它与传统的 math.atan(y/x) 函数相比，具有更好的数学定义，因为它能够正确处理边界情况（例如x=0）
local function atan2(y, x)
	if x == 0 and y == 0 then
		return 0 / 0 -- 返回NaN
	elseif x == 0 and y ~= 0 then
		if y > 0 then
			return math.pi / 2
		else
			return -math.pi / 2
		end
	else
		return math.atan(y / x) + (x < 0 and math.pi or 0)
	end
end
calc_methods["atan2"] = atan2

-- 将角度从弧度转换为度 e.g. deg(π) = 180
local function deg(x)
	return math.deg(x)
end
calc_methods["deg"] = deg

-- 将角度从度转换为弧度 e.g. rad(180) = π
local function rad(x)
	return math.rad(x)
end
calc_methods["rad"] = rad

-- 返回两个值, 无法参与运算后续
-- 返回m,e 使得x = m*2^e
--[[
local function frexp(x)
  return math.frexp(x)
end
calcPlugin["frexp"] = frexp
--]]

-- 返回 x*2^y
local function ldexp(x, y)
	return x * 2 ^ y
end
calc_methods["ldexp"] = ldexp

-- 返回 e^x
local function exp(x)
	return math.exp(x)
end
calc_methods["exp"] = exp

-- 计算开 N 次方
local function nth_root(x, n)
    if n % 2 == 0 and x < 0 then
        return nil  -- 偶次方时负数没有实数解
    elseif x < 0 then
        return -math.pow(-x, 1/n)
    else
        return math.pow(x, 1/n)
    end
end
calc_methods["nroot"] = nth_root

-- 返回x的平方根 e.g. sqrt(x) = x^0.5
local function sqrt(x)
	return math.sqrt(x)
end
calc_methods["sqrt"] = sqrt

-- x为底的对数, log(10, 100) = log(100) / log(10) = 2
local function log(x, y)
	-- 不能为负数或0
    if x <= 0 or y <= 0 then return nil end

	return math.log(y) / math.log(x)
end
calc_methods["log"] = log

-- 自然数e为底的对数
local function loge(x)
	-- 不能为负数或0
    if x <= 0 then return nil end

	return math.log(x)
end
calc_methods["loge"] = loge

-- 10为底的对数
local function logt(x)
	-- 不能为负数或0
    if x <= 0 then return nil end

	-- return math.log10(x)
	return math.log(x) / math.log(10)
end
calc_methods["logt"] = logt

-- 平均值
local function avg(...)
	local data = { ... }
	local n = select("#", ...)
	-- 样本数量不能为0
    if n == 0 then return nil end

	-- 计算总和
	local sum = 0
	for _, value in ipairs(data) do
		sum = sum + value
	end

	return sum / n
end
calc_methods["avg"] = avg

-- 方差
local function variance(...)
	local data = { ... }
	local n = select("#", ...)
	-- 样本数量不能为0
	if n == 0 then return nil end

	-- 计算均值
	local sum = 0
	for _, value in ipairs(data) do
		sum = sum + value
	end
	local mean = sum / n

	-- 计算方差
	local sum_squared_diff = 0
	for _, value in ipairs(data) do
		sum_squared_diff = sum_squared_diff + (value - mean) ^ 2
	end

	return sum_squared_diff / n
end
calc_methods["var"] = variance

-- 阶乘
local function factorial(x)
	-- 不能为负数
	if x < 0 then return nil end
	if x == 0 or x == 1 then return 1 end

	local result = 1
	for i = 1, x do
		result = result * i
	end

	return result
end
calc_methods["fact"] = factorial

-- 实现阶乘计算(!)
local function replaceToFactorial(str)
	-- 替换[0-9]!字符为fact([0-9])以实现阶乘
	return str:gsub("([0-9]+)!", "fact(%1)")
end

-- 简单计算器
function T.func(input, seg, env)
	local composition = env.engine.context.composition
	if composition:empty() then return end
	local segment = composition:back()

	if startsWith(input, T.prefix) or (seg:has_tag("calculator")) then
		segment.prompt = "〔" .. T.tips .. "〕"
		-- 提取算式
		local express = input:gsub(T.prefix, "")
		-- 算式长度 < 2 直接终止(没有计算意义)
		if string.len(express) < 2 then return end
		local code = replaceToFactorial(express)

		local success, result = pcall(load("return " .. code, "calculate", "t", calc_methods))
		if success then
			yield(Candidate(input, seg.start, seg._end, result, ""))
			yield(Candidate(input, seg.start, seg._end, express .. "=" .. result, ""))
		else
			yield(Candidate(input, seg.start, seg._end, express, "解析失败"))
			yield(Candidate(input, seg.start, seg._end, code, "入参"))
		end
	end
end

return T
