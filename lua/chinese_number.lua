-- 来源 https://github.com/yanhuacuo/98wubi-tables > http://98wb.ysepan.com/
-- 数字、金额大写 (任意大写字母引导+数字)

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
}

local function genChineseSeq(num)
    if not num:match("^%d") then
        return "请输入数字"
    end
    local result = ""
    for i = 1, #num do
        local _cs = string.sub(num, i, i)
        local cs = _cs ~= "." and _cs or "d"
        result = result .. n2c[cs]
    end
    return result
end

local function splitNumPart(str)
    local part = {}
    part.int, part.dot, part.dec = string.match(str, "^(%d*)(%.?)(%d*)")
    return part
end

local function decimal_func(str, posMap, valMap)
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
        return "请输入数字"
    end
    return result
end

local function number2zh(num, t)
    local result, wordFigure
    result = ""
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
    if not tostring(num) then
        return ""
    end
    for pos = 1, string.len(num) do
        result = result .. wordFigure[tonumber(string.sub(num, pos, pos) + 1)]
    end
    result = result:gsub(wordFigure[1] .. wordFigure[1], wordFigure[1])
    return result:gsub(wordFigure[1] .. wordFigure[1], wordFigure[1])
end

local function number_translatorFunc(num)
    local numberPart = splitNumPart(num)
    local result = {}
    if numberPart.dot ~= "" then
        table.insert(result, {
            number2cnChar(numberPart.int, 0, { "万", "亿" }, { "〇", "一", "十", "点" })
                .. number2zh(numberPart.dec, 0),
            "〔数字小写〕",
        })
        table.insert(result, {
            number2cnChar(numberPart.int, 1, { "萬", "億" }, { "〇", "一", "十", "点" })
                .. number2zh(numberPart.dec, 1),
            "〔数字大写〕",
        })
    else
        table.insert(result, {
            number2cnChar(numberPart.int, 0, { "万", "亿" }, { "〇", "一", "十", "" }),
            "〔数字小写〕",
        })
        table.insert(result, {
            number2cnChar(numberPart.int, 1, { "萬", "億" }, { "零", "壹", "拾", "" }),
            "〔数字大写〕",
        })
    end
    table.insert(result, { genChineseSeq(num), "〔数字序数〕" })
    table.insert(result, {
        number2cnChar(numberPart.int, 0) .. decimal_func(numberPart.dec, {
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
    table.insert(result, {
        number2cnChar(numberPart.int, 1) .. decimal_func(numberPart.dec, {
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
    return result
end

local P = {}
local T = {}
local CN = {}

function CN.init(env)
    local schema = env.engine.schema
    local context = env.engine.context
    local config = env.engine.schema.config
    local chinese_number_pattern = "recognizer/patterns/chinese_number"
    local _cn_pat = config:get_string(chinese_number_pattern) or "nN"
    env.trigger_prefix = _cn_pat:match("%^%(?([a-zA-Z/]+).*") or "/nn"
    env.tip = config:get_string("chinese_number" .. "/tips") or "中文数字"
    env.user_distribute_name = rime_api:get_distribution_code_name()
    env.select_keys = config:get_string("chinese_number/select_keys") or "HJKLIOM"
    env.alter_select_keys = config:get_int("menu/alternative_select_keys") or 1234567890
    CN.speller_alphabet = CN.speller_alphabet or config:get_string("speller/alphabet")
    env.notifier_commit_number = context.commit_notifier:connect(function(ctx)
        local segment = ctx.composition:back()
        if segment.prompt:match(env.tip) then
            config:set_int("menu/alternative_select_keys", env.alter_select_keys)
            config:set_string("speller/alphabet", CN.speller_alphabet)
            env.engine:apply_schema(Schema(schema.schema_id))
        end
    end)
end

function CN.fini(env)
    env.notifier_commit_number:disconnect()
end

function P.func(key, env)
    local engine = env.engine
    local schema = engine.schema
    local context = engine.context
    local input_code = context.input
    local config = engine.schema.config
    local segment = context.composition:back()
    local client_name = env.user_distribute_name
    if not table.find_index({ "Squirrel", "squirrel" }, client_name) then return 2 end
    if input_code:match("^/nn$") or input_code:match("^nN$") or segment.prompt:match(env.tip) then
        config:set_string("menu/alternative_select_keys", env.select_keys)
        config:set_string("speller/alphabet", "abcdefghijklmopqrstuvwxyz")
        engine:apply_schema(Schema(schema.schema_id))
        context:push_input(input_code)
        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单
    end
end

function T.func(input, seg, env)
    local str, numberPart
    local segment = env.engine.context.composition:back()
    if seg:has_tag("chinese_number") or string.match(input, "^" .. env.trigger_prefix) then
        segment.prompt = "〔" .. env.tip .. "〕"
        str = input:gsub("^" .. env.trigger_prefix, ""):gsub("%a+", "")
        numberPart = number_translatorFunc(str)
        if #numberPart > 0 then
            for i = 1, #numberPart do
                yield(Candidate(input, seg.start, seg._end, numberPart[i][1], numberPart[i][2]))
            end
        end
    end
end

return {
    processor = { init = CN.init, func = P.func, fini = CN.fini },
    translator = { init = CN.init, func = T.func, fini = CN.fini },
}
