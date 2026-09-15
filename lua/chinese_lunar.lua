local n2cn = require("lib/number_to_cn")

--天干名称
local tianGan = { "甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸" }

--地支名称
local diZhi = { "子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥" }

--属相名称
local animalSign = { "鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪" }

--农历日期名
local lunarDayShuXu = {
    "初一", "初二", "初三", "初四", "初五",
    "初六", "初七", "初八", "初九", "初十",
    "十一", "十二", "十三", "十四", "十五",
    "十六", "十七", "十八", "十九", "二十",
    "廿一", "廿二", "廿三", "廿四", "廿五",
    "廿六", "廿七", "廿八", "廿九", "三十",
}

--农历月份名
local lunarMonthShuXu = { "正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊" }

local daysToMonth365 = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 }
local daysToMonth366 = { 0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335 }

--每个农历月所属的季节名称和季节符号表
local jiJieNames = { "春", "春", "春", "夏", "夏", "夏", "秋", "秋", "秋", "冬", "冬", "冬" }
local jiJieLogos = { "🌱", "🌱", "🌱", "🌾", "🌾", "🌾", "🍂", "🍂", "🍂", "❄", "❄", "❄" }

--[[dateLunarInfo说明：
自1900年起，至2100年每年的农历信息，与万年历核对完成
每年第1个数字为闰月月份（0表示无闰月）
每年第2、3个数字为当年春节所在的阳历月份和日期
每年第4个数字为当年中对应月份的大小月标志，最高位对应正月，依次往后
大月（30天）对应 bit 为 1，小月（29天）对应 bit 为 0
--]]
local BEGIN_YEAR = 1900
local NUMBER_YEAR = 200
local dateLunarInfo = {
    -- 1900年：庚子年，闰八月，春节1月31日
    { 8,  1, 31, 37600 },
    -- 1901年起的原有数据 --
    { 0,  2, 19, 19168 },
    { 0,  2, 8,  42352 },
    { 5,  1, 29, 21096 },
    { 0,  2, 16, 53856 },
    { 0,  2, 4,  55632 },
    { 4,  1, 25, 27304 },
    { 0,  2, 13, 22176 },
    { 0,  2, 2,  39632 },
    { 2,  1, 22, 19176 },
    { 0,  2, 10, 19168 },
    { 6,  1, 30, 42200 },
    { 0,  2, 18, 42192 },
    { 0,  2, 6,  53840 },
    { 5,  1, 26, 54568 },
    { 0,  2, 14, 46400 },
    { 0,  2, 3,  54944 },
    { 2,  1, 23, 38608 },
    { 0,  2, 11, 38320 },
    { 7,  2, 1,  18872 },
    { 0,  2, 20, 18800 },
    { 0,  2, 8,  42160 },
    { 5,  1, 28, 45656 },
    { 0,  2, 16, 27216 },
    { 0,  2, 5,  27968 },
    { 4,  1, 24, 44456 },
    { 0,  2, 13, 11104 },
    { 0,  2, 2,  38256 },
    { 2,  1, 23, 18808 },
    { 0,  2, 10, 18800 },
    { 6,  1, 30, 25776 },
    { 0,  2, 17, 54432 },
    { 0,  2, 6,  59984 },
    { 5,  1, 26, 27976 },
    { 0,  2, 14, 23248 },
    { 0,  2, 4,  11104 },
    { 3,  1, 24, 37744 },
    { 0,  2, 11, 37600 },
    { 7,  1, 31, 51560 },
    { 0,  2, 19, 51536 },
    { 0,  2, 8,  54432 },
    { 6,  1, 27, 55888 },
    { 0,  2, 15, 46416 },
    { 0,  2, 5,  22176 },
    { 4,  1, 25, 43736 },
    { 0,  2, 13, 9680 },
    { 0,  2, 2,  37584 },
    { 2,  1, 22, 51544 },
    { 0,  2, 10, 43344 },
    { 7,  1, 29, 46248 },
    { 0,  2, 17, 27808 },
    { 0,  2, 6,  46416 },
    { 5,  1, 27, 21928 },
    { 0,  2, 14, 19872 },
    { 0,  2, 3,  42416 },
    { 3,  1, 24, 21176 },
    { 0,  2, 12, 21168 },
    { 8,  1, 31, 43344 },
    { 0,  2, 18, 59728 },
    { 0,  2, 8,  27296 },
    { 6,  1, 28, 44368 },
    { 0,  2, 15, 43856 },
    { 0,  2, 5,  19296 },
    { 4,  1, 25, 42352 },
    { 0,  2, 13, 42352 },
    { 0,  2, 2,  21088 },
    { 3,  1, 21, 59696 },
    { 0,  2, 9,  55632 },
    { 7,  1, 30, 23208 },
    { 0,  2, 17, 22176 },
    { 0,  2, 6,  38608 },
    { 5,  1, 27, 19176 },
    { 0,  2, 15, 19152 },
    { 0,  2, 3,  42192 },
    { 4,  1, 23, 53864 },
    { 0,  2, 11, 53840 },
    { 8,  1, 31, 54568 },
    { 0,  2, 18, 46400 },
    { 0,  2, 7,  46752 },
    { 6,  1, 28, 38608 },
    { 0,  2, 16, 38320 },
    { 0,  2, 5,  18864 },
    { 4,  1, 25, 42168 },
    { 0,  2, 13, 42160 },
    { 10, 2, 2,  45656 },
    { 0,  2, 20, 27216 },
    { 0,  2, 9,  27968 },
    { 6,  1, 29, 44448 },
    { 0,  2, 17, 43872 },
    { 0,  2, 6,  38256 },
    { 5,  1, 27, 18808 },
    { 0,  2, 15, 18800 },
    { 0,  2, 4,  25776 },
    { 3,  1, 23, 27216 },
    { 0,  2, 10, 59984 },
    { 8,  1, 31, 27432 },
    { 0,  2, 19, 23232 },
    { 0,  2, 7,  43872 },
    { 5,  1, 28, 37736 },
    { 0,  2, 16, 37600 },
    { 0,  2, 5,  51552 },
    { 4,  1, 24, 54440 },
    { 0,  2, 12, 54432 },
    { 0,  2, 1,  55888 },
    { 2,  1, 22, 23208 },
    { 0,  2, 9,  22176 },
    { 7,  1, 29, 43736 },
    { 0,  2, 18, 9680 },
    { 0,  2, 7,  37584 },
    { 5,  1, 26, 51544 },
    { 0,  2, 14, 43344 },
    { 0,  2, 3,  46240 },
    { 4,  1, 23, 46416 },
    { 0,  2, 10, 44368 },
    { 9,  1, 31, 21928 },
    { 0,  2, 19, 19360 },
    { 0,  2, 8,  42416 },
    { 6,  1, 28, 21176 },
    { 0,  2, 16, 21168 },
    { 0,  2, 5,  43312 },
    { 4,  1, 25, 29864 },
    { 0,  2, 12, 27296 },
    { 0,  2, 1,  44368 },
    { 2,  1, 22, 19880 },
    { 0,  2, 10, 19296 },
    { 6,  1, 29, 42352 },
    { 0,  2, 17, 42208 },
    { 0,  2, 6,  53856 },
    { 5,  1, 26, 59696 },
    { 0,  2, 13, 54576 },
    { 0,  2, 3,  23200 },
    { 3,  1, 23, 27472 },
    { 0,  2, 11, 38608 },
    { 11, 1, 31, 19176 },
    { 0,  2, 19, 19152 },
    { 0,  2, 8,  42192 },
    { 6,  1, 28, 53848 },
    { 0,  2, 15, 53840 },
    { 0,  2, 4,  54560 },
    { 5,  1, 24, 55968 },
    { 0,  2, 12, 46496 },
    { 0,  2, 1,  22224 },
    { 2,  1, 22, 19160 },
    { 0,  2, 10, 18864 },
    { 7,  1, 30, 42168 },
    { 0,  2, 17, 42160 },
    { 0,  2, 6,  43600 },
    { 5,  1, 26, 46376 },
    { 0,  2, 14, 27936 },
    { 0,  2, 2,  44448 },
    { 3,  1, 23, 21936 },
    { 0,  2, 11, 37744 },
    { 8,  2, 1,  18808 },
    { 0,  2, 19, 18800 },
    { 0,  2, 8,  25776 },
    { 6,  1, 28, 27216 },
    { 0,  2, 15, 59984 },
    { 0,  2, 4,  27424 },
    { 4,  1, 24, 43872 },
    { 0,  2, 12, 43744 },
    { 0,  2, 2,  37600 },
    { 3,  1, 21, 51568 },
    { 0,  2, 9,  51552 },
    { 7,  1, 29, 54440 },
    { 0,  2, 17, 54432 },
    { 0,  2, 5,  55888 },
    { 5,  1, 26, 23208 },
    { 0,  2, 14, 22176 },
    { 0,  2, 3,  42704 },
    { 4,  1, 23, 21224 },
    { 0,  2, 11, 21200 },
    { 8,  1, 31, 43352 },
    { 0,  2, 19, 43344 },
    { 0,  2, 7,  46240 },
    { 6,  1, 27, 46416 },
    { 0,  2, 15, 44368 },
    { 0,  2, 5,  21920 },
    { 4,  1, 24, 42448 },
    { 0,  2, 12, 42416 },
    { 0,  2, 2,  21168 },
    { 3,  1, 22, 43320 },
    { 0,  2, 9,  26928 },
    { 7,  1, 29, 29336 },
    { 0,  2, 17, 27296 },
    { 0,  2, 6,  44368 },
    { 5,  1, 26, 19880 },
    { 0,  2, 14, 19296 },
    { 0,  2, 3,  42352 },
    { 4,  1, 24, 21104 },
    { 0,  2, 10, 53856 },
    { 8,  1, 30, 59696 },
    { 0,  2, 18, 54560 },
    { 0,  2, 7,  55968 },
    { 6,  1, 27, 27472 },
    { 0,  2, 15, 22224 },
    { 0,  2, 5,  19168 },
    { 4,  1, 25, 42216 },
    { 0,  2, 12, 42192 },
    { 0,  2, 1,  53584 },
    { 2,  1, 21, 55592 },
    { 0,  2, 9,  54560 },
}

-- ============================================================
-- 纯算法计算天数，避免使用 os.time() 处理 1970 年前日期的兼容问题
-- 返回从公元1年1月1日到给定日期的绝对天数（以 proleptic Gregorian 历法）
-- ============================================================
local function isLeapYear(y)
    return (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
end

local function dateToAbsDay(y, m, d)
    -- 利用公式计算格里历绝对天数（Rata Die 算法）
    -- 参考：Calendrical Calculations
    local y1 = y - 1
    return 365 * y1
        + math.floor(y1 / 4)
        - math.floor(y1 / 100)
        + math.floor(y1 / 400)
        + (isLeapYear(y) and daysToMonth366[m] or daysToMonth365[m])
        + d
end

-- 2000年1月7日的绝对天数（甲子记日的起点）
local BASE_ABS_DAY = dateToAbsDay(2000, 1, 7)

-- 将给定的两个十进制数进行按位与运算
local function bitAnd(num1, num2)
    local result = 0
    local bit = 1
    while num1 > 0 and num2 > 0 do
        if num1 % 2 == 1 and num2 % 2 == 1 then
            result = result + bit
        end
        num1 = math.floor(num1 / 2)
        num2 = math.floor(num2 / 2)
        bit = bit * 2
    end
    return result
end

local function getYearInfo(lunarYear, index)
    if lunarYear < BEGIN_YEAR or lunarYear > BEGIN_YEAR + NUMBER_YEAR - 1 then
        return nil
    end
    return dateLunarInfo[lunarYear - BEGIN_YEAR + 1][index]
end

--计算指定公历日期是这一年中的第几天
local function daysCntInSolar(solarYear, solarMonth, solarDay)
    local daysToMonth = isLeapYear(solarYear) and daysToMonth366 or daysToMonth365
    return daysToMonth[solarMonth] + solarDay
end

local function numToCNumber(number)
    local year          = tonumber(string.sub(number, 1, 4))
    local month         = tonumber(string.sub(number, 5, 6))
    local day           = tonumber(string.sub(number, 7, 8))
    local _lunarYear    = n2cn.convert_arab_to_chinese(year)
    local lunarMonth    = n2cn.convert_arab_to_chinese(month)
    local lunarDay      = n2cn.convert_arab_to_chinese(day)
    local tmp_lunarYear = string.gsub(_lunarYear, "千", "")
    tmp_lunarYear       = string.gsub(tmp_lunarYear, "百", "")
    tmp_lunarYear       = string.gsub(tmp_lunarYear, "十", "")
    local lunarYear     = string.gsub(tmp_lunarYear, "零", "〇")
    return lunarYear .. "年" .. lunarMonth .. "月" .. lunarDay .. "日"
end

--[[根据指定的阳历日期，返回一个农历日期的结构体，结构如下：
lunarDate.solarYear：对应的阳历日期年份
lunarDate.solarMonth：对应的阳历日期月份
lunarDate.solarDay：对应的阳历日期日期
lunarDate.solarDate_YYYYMMDD：对应的阳历日期 YYYYMMDD
lunarDate.year：对应农历年份
lunarDate.month：对应农历月份
lunarDate.day：对应农历的日期
lunarDate.leap：是否为农历的闰年
lunarDate.year_animalSign：用生肖表示的农历年份
lunarDate.year_ganZhi：用干支表示的农历年份
lunarDate.month_shuXu：农历月份的名称
lunarDate.month_ganZhi：用干支表示的农历月份
lunarDate.day_shuXu：农历日期的名称
lunarDate.day_ganZhi：用干支表示的农历日期
lunarDate.lunarDate_YYYYMMDD：以 YYYYMMDD 格式表示的农历日期
lunarDate.lunarDate_1：癸卯年四月十一
lunarDate.lunarDate_2：兔年四月十一
lunarDate.lunarDate_3：癸卯年四月丁亥日
lunarDate.lunarDate_4：癸卯(兔)年四月十一
lunarDate.jiJieName: 日期所属的季节名称
lunarDate.jiJieLogo：日期所属的季节的符号
]]
--阳历转阴历
local function solar2Lunar(solarYear, solarMonth, solarDay)
    local lunarDate              = {}
    lunarDate.solarYear          = solarYear
    lunarDate.solarMonth         = solarMonth
    lunarDate.solarDay           = solarDay
    lunarDate.solarDate_YYYYMMDD = string.format("%04d%02d%02d", solarYear, solarMonth, solarDay)
    lunarDate.year               = solarYear
    lunarDate.month              = 0
    lunarDate.day                = 0
    lunarDate.leap               = false
    lunarDate.year_animalSign     = ""
    lunarDate.year_ganZhi        = ""
    lunarDate.month_shuXu        = ""
    lunarDate.month_ganZhi       = ""
    lunarDate.day_shuXu          = ""
    lunarDate.day_ganZhi         = ""
    lunarDate.lunarDate_YYYYMMDD = ""
    lunarDate.lunarDate_YMD      = ""
    lunarDate.lunarDate_1        = ""
    lunarDate.lunarDate_2        = ""
    lunarDate.lunarDate_3        = ""
    lunarDate.lunarDate_4        = ""
    lunarDate.jiJieName          = ""
    lunarDate.jiJieLogo          = ""

    -- 用纯算法计算距基准日的天数（兼容 1970 年前的日期）
    lunarDate.daysToBase         = dateToAbsDay(solarYear, solarMonth, solarDay) - BASE_ABS_DAY

    -- 超出数据范围则直接返回（注意：用 < BEGIN_YEAR，不含等于号）
    if lunarDate.solarYear < BEGIN_YEAR or lunarDate.solarYear > BEGIN_YEAR + NUMBER_YEAR - 1 then
        return lunarDate
    end

    --春节的公历日期
    local solarMontSpring        = getYearInfo(lunarDate.year, 2)
    local solarDaySpring         = getYearInfo(lunarDate.year, 3)

    --计算这天是公历年的第几天
    local daysCntInSolarThisDate = daysCntInSolar(solarYear, solarMonth, solarDay)
    --计算春节是公历年的第几天
    local daysCntInSolarSprint   = daysCntInSolar(solarYear, solarMontSpring, solarDaySpring)
    --计算这天是农历年的第几天（从正月初一算起为第1天）
    local daysCntInLunarThisDate = daysCntInSolarThisDate - daysCntInSolarSprint + 1

    if daysCntInLunarThisDate <= 0 then
        -- 指定日期在当前农历年春节之前，属于上一农历年
        lunarDate.year = lunarDate.year - 1

        -- 修复：使用 < BEGIN_YEAR 而非 <= BEGIN_YEAR，确保 BEGIN_YEAR 本身可被查询
        if lunarDate.year < BEGIN_YEAR then
            return lunarDate
        end

        --重新确定上一年农历春节所在的公历日期
        solarMontSpring           = getYearInfo(lunarDate.year, 2)
        solarDaySpring            = getYearInfo(lunarDate.year, 3)

        --重新计算上一年春节是公历上一年的第几天
        daysCntInSolarSprint      = daysCntInSolar(solarYear - 1, solarMontSpring, solarDaySpring)
        --计算公历上一年共几天
        local daysCntInSolarTotal = isLeapYear(solarYear - 1) and 366 or 365
        --上一农历年的第几天
        daysCntInLunarThisDate    = daysCntInSolarThisDate + daysCntInSolarTotal - daysCntInSolarSprint + 1
    end

    --开始计算农历月份
    local lunarMonth = 1
    local lunarDaysCntInMonth = 0
    -- dec 32768 = bin 1000000000000000，最高位掩码，对应正月
    local bitMask = 32768
    --大小月份的标志数据
    local lunarMonth30Flg = getYearInfo(lunarDate.year, 4)

    while lunarMonth <= 13 do
        --计算这个月总共有多少天
        if bitAnd(lunarMonth30Flg, bitMask) ~= 0 then
            lunarDaysCntInMonth = 30
        else
            lunarDaysCntInMonth = 29
        end

        --检查剩余天数是否在这个月之内
        if daysCntInLunarThisDate <= lunarDaysCntInMonth then
            lunarDate.month = lunarMonth
            lunarDate.day   = daysCntInLunarThisDate
            break
        else
            daysCntInLunarThisDate = daysCntInLunarThisDate - lunarDaysCntInMonth
            lunarMonth = lunarMonth + 1
            bitMask = math.floor(bitMask / 2)
        end
    end

    --闰月所在的月份
    local leapMontInLunar = getYearInfo(lunarDate.year, 1)
    --确定闰月信息
    if leapMontInLunar > 0 and leapMontInLunar < lunarDate.month then
        lunarDate.month = lunarDate.month - 1
        if leapMontInLunar == lunarDate.month then
            lunarDate.leap = true
        end
    end

    --合成农历的年月日格式：YYYYMMDD
    lunarDate.lunarDate_YYYYMMDD = string.format("%04d%02d%02d",
        lunarDate.year, lunarDate.month, lunarDate.day)
    lunarDate.lunarDate_YMD = numToCNumber(lunarDate.lunarDate_YYYYMMDD)

    lunarDate.jiJieName = jiJieNames[lunarDate.month]
    lunarDate.jiJieLogo = jiJieLogos[lunarDate.month]

    --确定年份的生肖
    lunarDate.year_animalSign = animalSign[(((lunarDate.year - 4) % 60) % 12) + 1]
    --确定年份的干支
    lunarDate.year_ganZhi = tianGan[(((lunarDate.year - 4) % 60) % 10) + 1]
        .. diZhi[(((lunarDate.year - 4) % 60) % 12) + 1]
    --确定月份的数序
    lunarDate.month_shuXu = (lunarDate.leap and "闰" or "") .. lunarMonthShuXu[lunarDate.month]
    --确定月份的干支（暂不支持计算）
    lunarDate.month_ganZhi = ""
    --确定日期的数序
    lunarDate.day_shuXu = lunarDayShuXu[lunarDate.day]
    --确定日期的干支
    lunarDate.day_ganZhi = tianGan[((lunarDate.daysToBase % 60) % 10) + 1]
        .. diZhi[((lunarDate.daysToBase % 60) % 12) + 1]

    --提供国标第一类计年表示格式：癸卯年四月十一
    lunarDate.lunarDate_1 = lunarDate.year_ganZhi
        .. "年" .. lunarDate.month_shuXu .. "月" .. lunarDate.day_shuXu
    --提供国标第二类计年表示格式：兔年四月十一
    lunarDate.lunarDate_2 = lunarDate.year_animalSign
        .. "年" .. lunarDate.month_shuXu .. "月" .. lunarDate.day_shuXu
    --提供国标第三类计年表示格式：癸卯年四月丁亥日
    lunarDate.lunarDate_3 = lunarDate.year_ganZhi
        .. "年" .. lunarDate.month_shuXu .. "月" .. lunarDate.day_ganZhi .. "日"
    --提供非国标的第四类计年表示格式：癸卯(兔)年四月十一
    lunarDate.lunarDate_4 = lunarDate.year_ganZhi
        .. "(" .. lunarDate.year_animalSign .. ")年"
        .. lunarDate.month_shuXu .. "月" .. lunarDate.day_shuXu

    return lunarDate
end

--通过传入的阳历时间字符串（YYYYMMDD），返回一个阴历数据结构
local function solar2LunarByTime(t)
    local year  = tonumber(string.sub(t, 1, 4))
    local month = tonumber(string.sub(t, 5, 6))
    local day   = tonumber(string.sub(t, 7, 8))
    return solar2Lunar(
        math.floor(year or 0),
        math.floor(month or 1),
        math.floor(day or 1)
    )
end

-- 每月最大天数表（非闰年），用于日期合法性校验
local maxDaysInMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

-- 校验年月日是否合法，返回错误提示字符串；合法则返回 nil
local function validateDate(date_str)
    if not date_str:match("^[12]%d%d%d%d%d%d%d$") then
        return nil -- 不是完整的 8 位日期，交由后续逻辑处理
    end
    local y = tonumber(string.sub(date_str, 1, 4))
    local m = tonumber(string.sub(date_str, 5, 6))
    local d = tonumber(string.sub(date_str, 7, 8))

    if y < BEGIN_YEAR or y > BEGIN_YEAR + NUMBER_YEAR - 1 then
        return "年份超出支持范围（1900～2099年）"
    end
    if m < 1 or m > 12 then
        return "月份无效，请输入 01～12"
    end
    -- 计算当月实际最大天数（考虑闰年二月）
    local maxDay = maxDaysInMonth[m]
    if m == 2 and isLeapYear(y) then
        maxDay = 29
    end
    if d < 1 or d > maxDay then
        return string.format("日期无效，%d年%02d月的范围是 01～%02d", y, m, maxDay)
    end
    return nil
end

local T = {}

function T.init(env)
    local config = env.engine.schema.config
    env.prompt   = config:get_string("chinese_lunar/tips") or "农历"
    env.prefix   = config:get_string("chinese_lunar/prefix") or "nL"
    env.tag      = config:get_string("chinese_lunar/tag") or "chinese_lunar"
end

-- 农历
function T.func(input, seg, env)
    local context     = env.engine.context
    local composition = context.composition
    if composition:empty() then return end
    local segment = composition:back()

    local input_code = context.input
    if seg:has_tag(env.tag) or input_code:match("^" .. env.prefix .. "$") then
        segment.tags         = segment.tags - Set({ "abc" })
        segment.prompt       = "〔" .. env.prompt .. "〕"

        local solarDateTable = {}
        local input_date     = input:gsub("[%a%/]", "")

        local input_year     = tonumber(string.sub(input_date, 1, 4))
        -- 年份超出范围（不足 8 位时 input_year 可能为不完整数字，此处仅对完整输入报错）
        if input_date:match("^[12]%d%d%d%d%d%d%d$") then
            local err = validateDate(input_date)
            if err then
                yield(Candidate("lunar_error", seg.start, seg._end, "⚠ " .. err, ""))
                return
            end
            solarDateTable = solar2LunarByTime(input_date)
        elseif input_year and (input_year < BEGIN_YEAR or input_year > BEGIN_YEAR + NUMBER_YEAR - 1) then
            yield(Candidate("lunar_error", seg.start, seg._end, "⚠ 年份超出支持范围（1900～2099年）", ""))
            return
        else
            solarDateTable = solar2LunarByTime(os.date("%Y%m%d"))
        end

        if (not solarDateTable["lunarDate_YMD"]) or (solarDateTable.lunarDate_YMD == "") then return end

        local lunar_date   = Candidate("lunar", seg.start, seg._end, solarDateTable.lunarDate_4, "")
        local lunar_ymd    = Candidate("lunar", seg.start, seg._end, solarDateTable.lunarDate_YMD, "")
        lunar_date.quality = 999
        lunar_ymd.quality  = 999
        yield(lunar_date)
        yield(lunar_ymd)
    end
end

return T
