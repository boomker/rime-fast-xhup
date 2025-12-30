-- 来源 https://github.com/yanhuacuo/98wubi-tables > http://98wb.ysepan.com/
-- 数字、金额大写 (任意大写字母引导+数字)

require("lib.rime_helper")
local Env = require("lib/env_api")
local n2c = {
    ["0"] = "〇",
    ["1"] = "一",
    ["2"] = "二",
    ["3"] = "三",
    ["4"] = "四",
    ["5"] = "五",
    ["6"] = "六",
    ["7"] = "七",
    ["8"] = "八",
    ["9"] = "九",
    ["d"] = "点",
    ["-"] = "负",
}

-- 定义函数：将数字转换为国际千分位格式
local function format_number_comma(num)
    -- 1. 将输入转换为字符串
    local str = tostring(num)

    -- 2. 分离整数部分和小数部分
    -- ^(-?%d+) : 捕获开头可能带负号的整数部分
    -- (%.?%d*)$ : 捕获可能存在的小数点及后续数字
    local int_part, dec_part = string.match(str, "^(-?%d+)(%.?%d*)$")

    -- 如果解析失败（例如输入非数字），直接返回原值
    if not int_part then return num end

    -- 3. 循环处理整数部分，插入逗号
    while true do
        -- string.gsub 返回两个值：替换后的字符串和替换次数
        -- 模式解释：^(-?%d+)(%d%d%d)
        -- 它的作用是找到 "一串数字" 后跟 "最后3个数字"，并在中间加逗号
        local formatted, k = string.gsub(int_part, "^(-?%d+)(%d%d%d)", "%1,%2")

        -- 如果替换次数为0，说明没有更多的千分位需要处理，跳出循环
        if k == 0 then
            break
        end

        -- 更新整数部分，继续下一次循环
        int_part = formatted
    end

    -- 4. 拼接整数部分和小数部分并返回
    return int_part .. dec_part
end

local function genChineseSeq(num)
    local result = ""
    for i = 1, #num do
        local _cs = string.sub(num, i, i)
        local cs = _cs ~= "." and _cs or "d"
        result = result .. n2c[cs]
    end
    return result
end

-- 把数字串按千分位四位数分割，进行转换为中文
local function formatNum(num, t)
    local digitUnit, wordFigure
    local result = ""
    num = tostring(num)
    if tonumber(t) < 1 then
        digitUnit = { "", "十", "百", "千" }
    else
        digitUnit = { "", "拾", "佰", "仟" }
    end
    if tonumber(t) < 1 then
        wordFigure = {
            "〇",
            "一",
            "二",
            "三",
            "四",
            "五",
            "六",
            "七",
            "八",
            "九",
        }
    else
        wordFigure = {
            "零",
            "壹",
            "贰",
            "叁",
            "肆",
            "伍",
            "陆",
            "柒",
            "捌",
            "玖",
        }
    end
    if string.len(num) > 4 or tonumber(num) == 0 then
        return wordFigure[1]
    end
    local lens = string.len(num)
    for i = 1, lens do
        local n = wordFigure[tonumber(string.sub(num, -i, -i)) + 1]
        if n ~= wordFigure[1] then
            result = n .. digitUnit[i] .. result
        else
            result = n .. result
        end
    end
    result = result:gsub(wordFigure[1] .. wordFigure[1], wordFigure[1])
    result = result:gsub(wordFigure[1] .. "$", "")
    result = result:gsub(wordFigure[1] .. "$", "")

    return result
end

-- 数值转换为中文
-- flag=0中文小写反之为大写
local function decNumber2cnChar(num, flag)
    local result, wordFigure
    result = ""
    if tonumber(flag) < 1 then
        wordFigure = {
            "〇",
            "一",
            "二",
            "三",
            "四",
            "五",
            "六",
            "七",
            "八",
            "九",
        }
    else
        wordFigure = {
            "零",
            "壹",
            "贰",
            "叁",
            "肆",
            "伍",
            "陆",
            "柒",
            "捌",
            "玖",
        }
    end
    if not tostring(num) then return "" end
    for pos = 1, string.len(num) do
        result = result .. wordFigure[tonumber(string.sub(num, pos, pos) + 1)]
    end
    result = result:gsub(wordFigure[1] .. wordFigure[1], wordFigure[1])
    return result:gsub(wordFigure[1] .. wordFigure[1], wordFigure[1])
end

local function decimalNumber2cuChar(str, posMap, valMap)
    local dec
    posMap = posMap or { [1] = "角", [2] = "分", [3] = "厘", [4] = "毫" }
    valMap = valMap
        or {
            [0] = "零",
            "壹",
            "贰",
            "叁",
            "肆",
            "伍",
            "陆",
            "柒",
            "捌",
            "玖",
        }
    if #str > 4 then
        dec = string.sub(tostring(str), 1, 4)
    else
        dec = tostring(str)
    end
    dec = string.gsub(dec, "0+$", "")

    if dec == "" then
        return "整"
    end

    local result = ""
    for pos = 1, #dec do
        local val = tonumber(string.sub(dec, pos, pos))
        if val ~= 0 then
            result = result .. valMap[val] .. posMap[pos]
        else
            result = result .. valMap[val]
        end
    end
    result = result:gsub(valMap[0] .. valMap[0], valMap[0])
    return result:gsub(valMap[0] .. valMap[0], valMap[0])
end

local function number2cnChar(num, flag, digitUnit, wordFigure)
    local result
    num = tonumber(num) or 0
    local num1, num2 = math.modf(num)
    if tonumber(num2) == 0 then
        if tonumber(flag) < 1 then
            digitUnit = digitUnit or { [1] = "万", [2] = "亿" }
            wordFigure = wordFigure
                or {
                    [1] = "〇",
                    [2] = "一",
                    [3] = "十",
                    [4] = "元",
                }
        else
            digitUnit = digitUnit or { [1] = "万", [2] = "亿" }
            wordFigure = wordFigure
                or {
                    [1] = "零",
                    [2] = "壹",
                    [3] = "拾",
                    [4] = "元",
                }
        end

        local lens = string.len(num1)
        if lens < 5 then
            result = formatNum(num1, flag)
        elseif lens < 9 then
            result = formatNum(string.sub(num1, 1, -5), flag)
                .. digitUnit[1]
                .. formatNum(string.sub(num1, -4, -1), flag)
        elseif lens < 13 then
            result = formatNum(string.sub(num1, 1, -9), flag)
                .. digitUnit[2]
                .. formatNum(string.sub(num1, -8, -5), flag)
                .. digitUnit[1]
                .. formatNum(string.sub(num1, -4, -1), flag)
        else
            result = ""
        end

        result = result:gsub("^" .. wordFigure[1], "")
        result = result:gsub(wordFigure[1] .. digitUnit[1], "")
        result = result:gsub(wordFigure[1] .. digitUnit[2], "")
        result = result:gsub(wordFigure[1] .. wordFigure[1], wordFigure[1])
        result = result:gsub(wordFigure[1] .. "$", "")
        if lens > 4 then
            result = result:gsub("^" .. wordFigure[2] .. wordFigure[3], wordFigure[3])
        end

        if result ~= "" then
            result = result .. wordFigure[4]
        else
            result = "请输入数字!"
        end
    else
        return "请输入数字!"
    end
    return result
end

local function sign2char(str)
    if not str then return "" end
    if str == "-" then return "负" end
    return ""
end

local function splitNumPart(str)
    local part = {}
    part.sign, part.int, part.dot, part.dec = string.match(str, "^(%-?)(%d*)(%.?)(%d*)")
    return part
end

local function number_translator(num)
    local numberPart = splitNumPart(num)
    local result = {}
    table.insert(result, {
        sign2char(numberPart.sign) .. number2cnChar(numberPart.int, 1) .. decimalNumber2cuChar(numberPart.dec, {
            [1] = "角",
            [2] = "分",
            [3] = "厘",
            [4] = "毫",
        }, {
            [0] = "零",
            "壹",
            "贰",
            "叁",
            "肆",
            "伍",
            "陆",
            "柒",
            "捌",
            "玖",
        }),
        "〔金额大写〕",
    })
    table.insert(result, {
        sign2char(numberPart.sign) .. number2cnChar(numberPart.int, 0) .. decimalNumber2cuChar(numberPart.dec, {
            [1] = "角",
            [2] = "分",
            [3] = "厘",
            [4] = "毫",
        }, {
            [0] = "〇",
            "一",
            "二",
            "三",
            "四",
            "五",
            "六",
            "七",
            "八",
            "九",
        }),
        "〔金额小写〕",
    })
    if numberPart.dot then
        table.insert(result, {
            sign2char(numberPart.sign) .. number2cnChar(numberPart.int, 1, { "萬", "億" }, { "零", "壹", "拾", "点" })
            .. decNumber2cnChar(numberPart.dec, 1),
            "〔数字大写〕",
        })
        table.insert(result, {
            sign2char(numberPart.sign) .. number2cnChar(numberPart.int, 0, { "万", "亿" }, { "〇", "一", "十", "点" })
            .. decNumber2cnChar(numberPart.dec, 0),
            "〔数字小写〕",
        })
    else
        table.insert(result, {
            sign2char(numberPart.sign) .. number2cnChar(numberPart.int, 1, { "萬", "億" }, { "零", "壹", "拾", "" }),
            "〔数字大写〕",
        })
        table.insert(result, {
            sign2char(numberPart.sign) .. number2cnChar(numberPart.int, 0, { "万", "亿" }, { "〇", "一", "十", "" }),
            "〔数字小写〕",
        })
    end
    table.insert(result, { genChineseSeq(num), "〔数字序数〕" })
    table.insert(result, { format_number_comma(num), "〔国际标读〕" })
    return result
end

local P = {}
local T = {}
local M = {}

function M.init(env)
    Env(env)
    local schema = env.engine.schema
    local context = env.engine.context
    local config = env.engine.schema.config
    local cn_pattern_key = "recognizer/patterns/chinese_number"
    local cn_pattern = config:get_string(cn_pattern_key) or "nN"
    local default_labels = { "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨" }
    env.system_name = detect_os()
    env.current_speller = config:get_string("speller/alphabet")
    env.prompt = config:get_string("chinese_number/tips") or "中文数字"
    env.trigger_prefix = cn_pattern:match("%^?%(?([a-zA-Z/|]+)%)?.*") or "nN"
    env.current_labels = config:get_string("menu/alternative_select_labels")
    env.current_select_keys = config:get_string("menu/alternative_select_keys")
    env.alter_labels = env.alter_labels or env.current_labels or default_labels
    M.speller_string = M.speller_string or env.current_speller -- 缓存speller
    M.alter_select_keys = M.alter_select_keys or env.current_select_keys or "1234567"
    env.alpha_select_keys = config:get_string("chinese_number/select_keys") or "sdfjklm"
    env.notifier_commit_number = context.commit_notifier:connect(function(ctx)
        if env.system_name:lower():match("android") then return end
        local segment = ctx.composition:back()
        if segment and segment.prompt:match(env.prompt) then
            env:Config_set("speller/alphabet", M.speller_string)
            env:Config_set("menu/alternative_select_keys", M.alter_select_keys)
            env:Config_set("menu/alternative_select_labels", env.alter_labels)
            env.engine:apply_schema(Schema(schema.schema_id))
        end
    end)
end

function M.fini(env)
    if env.notifier_commit_number then
        env.notifier_commit_number:disconnect()
        env.notifier_commit_number = nil
    end
end

function P.func(key, env)
    local engine = env.engine
    local schema = engine.schema
    local context = engine.context
    local input_code = context.input
    local composition = context.composition

    if (env.current_speller ~= M.speller_string) and (key:repr() == "Escape") then
        env:Config_set("menu/alternative_select_keys", M.alter_select_keys)
        env:Config_set("menu/alternative_select_labels", env.alter_labels)
        env:Config_set("speller/alphabet", M.speller_string)
        engine:apply_schema(Schema(schema.schema_id))
        return 1 -- kAccepted 收下此key
    end
    if composition:empty() then return 2 end
    local segment = composition:back()
    if not (segment and segment.menu) then return 2 end
    if env.system_name:lower():match("android") then return 2 end
    if env.current_select_keys == env.alpha_select_keys then return 2 end

    local alpha_labels = { "s", "d", "f", "j", "k", "l", "m" }
    local _speller_str = env.current_speller:gsub("[a-z%p]", "")
    local speller_str = _speller_str:gsub("[" .. env.trigger_prefix .. "]", "")
    local prefix_tbl = env.trigger_prefix:match("|") and string.split(env.trigger_prefix, "|") or { "/nn", "nN" }
    if table.find(prefix_tbl, input_code) or segment.prompt:match(env.prompt) then
        env:Config_set("menu/alternative_select_keys", env.alpha_select_keys)
        env:Config_set("menu/alternative_select_labels", alpha_labels)
        env:Config_set("speller/alphabet", speller_str)
        engine:apply_schema(Schema(schema.schema_id))
        context:push_input(input_code)
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单
    end
    return 2
end

function T.func(input, seg, env)
    local payload_str, numberPart
    local segment = env.engine.context.composition:back()
    local prefix_tbl = env.trigger_prefix:match("|") and string.split(env.trigger_prefix, "|") or { "/nn", "nN" }
    if seg:has_tag("chinese_number") or table.find(prefix_tbl, input) then
        segment.prompt = "〔" .. env.prompt .. "〕"
        payload_str = input:gsub("[%a/]+", "")
        numberPart = (payload_str:len() > 0) and number_translator(payload_str) or nil
        if numberPart and #numberPart > 0 then
            for i = 1, #numberPart do
                yield(Candidate(input, seg.start, seg._end, numberPart[i][1], numberPart[i][2]))
            end
        end
    end
end

return {
    processor = { init = M.init, func = P.func, fini = M.fini },
    translator = { init = M.init, func = T.func, fini = M.fini },
}
