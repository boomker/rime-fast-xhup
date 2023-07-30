-- 天干名称
local nLTianGan = {
    "甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"
}
-- 地支名称
local nLDiZhi = {
    "子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌",
    "亥"
}
-- 属相名称
local nLShuXing = {
    "鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗",
    "猪"
}
-- 农历日期名
local nLDayName = {
    "*", "初一", "初二", "初三", "初四", "初五", "初六", "初七",
    "初八", "初九", "初十", "十一", "十二", "十三", "十四",
    "十五", "十六", "十七", "十八", "十九", "二十", "廿一",
    "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八",
    "廿九", "三十"
}
-- 农历月份名
local nLMonName = {
    "*", "正", "二", "三", "四", "五", "六", "七", "八", "九", "十",
    "十一", "腊"
}

local DaysToMonth366 = {0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335}

local DaysToMonth365 = {0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334}

local DateLunarInfo = {
    {0, 2, 19, 19168}, {0, 2, 8, 42352}, {5, 1, 29, 21096}, {0, 2, 16, 53856},
    {0, 2, 4, 55632}, {4, 1, 25, 27304}, {0, 2, 13, 22176}, {0, 2, 2, 39632},
    {2, 1, 22, 19176}, {0, 2, 10, 19168}, {6, 1, 30, 42200}, {0, 2, 18, 42192},
    {0, 2, 6, 53840}, {5, 1, 26, 54568}, {0, 2, 14, 46400}, {0, 2, 3, 54944},
    {2, 1, 23, 38608}, {0, 2, 11, 38320}, {7, 2, 1, 18872}, {0, 2, 20, 18800},
    {0, 2, 8, 42160}, {5, 1, 28, 45656}, {0, 2, 16, 27216}, {0, 2, 5, 27968},
    {4, 1, 24, 44456}, {0, 2, 13, 11104}, {0, 2, 2, 38256}, {2, 1, 23, 18808},
    {0, 2, 10, 18800}, {6, 1, 30, 25776}, {0, 2, 17, 54432}, {0, 2, 6, 59984},
    {5, 1, 26, 27976}, {0, 2, 14, 23248}, {0, 2, 4, 11104}, {3, 1, 24, 37744},
    {0, 2, 11, 37600}, {7, 1, 31, 51560}, {0, 2, 19, 51536}, {0, 2, 8, 54432},
    {6, 1, 27, 55888}, {0, 2, 15, 46416}, {0, 2, 5, 22176}, {4, 1, 25, 43736},
    {0, 2, 13, 9680}, {0, 2, 2, 37584}, {2, 1, 22, 51544}, {0, 2, 10, 43344},
    {7, 1, 29, 46248}, {0, 2, 17, 27808}, {0, 2, 6, 46416}, {5, 1, 27, 21928},
    {0, 2, 14, 19872}, {0, 2, 3, 42416}, {3, 1, 24, 21176}, {0, 2, 12, 21168},
    {8, 1, 31, 43344}, {0, 2, 18, 59728}, {0, 2, 8, 27296}, {6, 1, 28, 44368},
    {0, 2, 15, 43856}, {0, 2, 5, 19296}, {4, 1, 25, 42352}, {0, 2, 13, 42352},
    {0, 2, 2, 21088}, {3, 1, 21, 59696}, {0, 2, 9, 55632}, {7, 1, 30, 23208},
    {0, 2, 17, 22176}, {0, 2, 6, 38608}, {5, 1, 27, 19176}, {0, 2, 15, 19152},
    {0, 2, 3, 42192}, {4, 1, 23, 53864}, {0, 2, 11, 53840}, {8, 1, 31, 54568},
    {0, 2, 18, 46400}, {0, 2, 7, 46752}, {6, 1, 28, 38608}, {0, 2, 16, 38320},
    {0, 2, 5, 18864}, {4, 1, 25, 42168}, {0, 2, 13, 42160}, {10, 2, 2, 45656},
    {0, 2, 20, 27216}, {0, 2, 9, 27968}, {6, 1, 29, 44448}, {0, 2, 17, 43872},
    {0, 2, 6, 38256}, {5, 1, 27, 18808}, {0, 2, 15, 18800}, {0, 2, 4, 25776},
    {3, 1, 23, 27216}, {0, 2, 10, 59984}, {8, 1, 31, 27432}, {0, 2, 19, 23232},
    {0, 2, 7, 43872}, {5, 1, 28, 37736}, {0, 2, 16, 37600}, {0, 2, 5, 51552},
    {4, 1, 24, 54440}, {0, 2, 12, 54432}, {0, 2, 1, 55888}, {2, 1, 22, 23208},
    {0, 2, 9, 22176}, {7, 1, 29, 43736}, {0, 2, 18, 9680}, {0, 2, 7, 37584},
    {5, 1, 26, 51544}, {0, 2, 14, 43344}, {0, 2, 3, 46240}, {4, 1, 23, 46416},
    {0, 2, 10, 44368}, {9, 1, 31, 21928}, {0, 2, 19, 19360}, {0, 2, 8, 42416},
    {6, 1, 28, 21176}, {0, 2, 16, 21168}, {0, 2, 5, 43312}, {4, 1, 25, 29864},
    {0, 2, 12, 27296}, {0, 2, 1, 44368}, {2, 1, 22, 19880}, {0, 2, 10, 19296},
    {6, 1, 29, 42352}, {0, 2, 17, 42208}, {0, 2, 6, 53856}, {5, 1, 26, 59696},
    {0, 2, 13, 54576}, {0, 2, 3, 23200}, {3, 1, 23, 27472}, {0, 2, 11, 38608},
    {11, 1, 31, 19176}, {0, 2, 19, 19152}, {0, 2, 8, 42192}, {6, 1, 28, 53848},
    {0, 2, 15, 53840}, {0, 2, 4, 54560}, {5, 1, 24, 55968}, {0, 2, 12, 46496},
    {0, 2, 1, 22224}, {2, 1, 22, 19160}, {0, 2, 10, 18864}, {7, 1, 30, 42168},
    {0, 2, 17, 42160}, {0, 2, 6, 43600}, {5, 1, 26, 46376}, {0, 2, 14, 27936},
    {0, 2, 2, 44448}, {3, 1, 23, 21936}, {0, 2, 11, 37744}, {8, 2, 1, 18808},
    {0, 2, 19, 18800}, {0, 2, 8, 25776}, {6, 1, 28, 27216}, {0, 2, 15, 59984},
    {0, 2, 4, 27424}, {4, 1, 24, 43872}, {0, 2, 12, 43744}, {0, 2, 2, 37600},
    {3, 1, 21, 51568}, {0, 2, 9, 51552}, {7, 1, 29, 54440}, {0, 2, 17, 54432},
    {0, 2, 5, 55888}, {5, 1, 26, 23208}, {0, 2, 14, 22176}, {0, 2, 3, 42704},
    {4, 1, 23, 21224}, {0, 2, 11, 21200}, {8, 1, 31, 43352}, {0, 2, 19, 43344},
    {0, 2, 7, 46240}, {6, 1, 27, 46416}, {0, 2, 15, 44368}, {0, 2, 5, 21920},
    {4, 1, 24, 42448}, {0, 2, 12, 42416}, {0, 2, 2, 21168}, {3, 1, 22, 43320},
    {0, 2, 9, 26928}, {7, 1, 29, 29336}, {0, 2, 17, 27296}, {0, 2, 6, 44368},
    {5, 1, 26, 19880}, {0, 2, 14, 19296}, {0, 2, 3, 42352}, {4, 1, 24, 21104},
    {0, 2, 10, 53856}, {8, 1, 30, 59696}, {0, 2, 18, 54560}, {0, 2, 7, 55968},
    {6, 1, 27, 27472}, {0, 2, 15, 22224}, {0, 2, 5, 19168}, {4, 1, 25, 42216},
    {0, 2, 12, 42192}, {0, 2, 1, 53584}, {2, 1, 21, 55592}, {0, 2, 9, 54560}
}
-- 转为二进制
function DecimalismToBinary(num)
    local str = ""
    local tmp = num
    while (tmp > 0) do
        if (tmp % 2 == 1) then
            str = str .. "1"
        else
            str = str .. "0"
        end

        tmp = math.modf(tmp / 2)
    end
    str = string.reverse(str)
    return str
end
-- 先补齐两个数字的二进制位数
function MakeSameLength(num1, num2)
    local str1 = DecimalismToBinary(num1)
    local str2 = DecimalismToBinary(num2)
    local len1 = string.len(str1)
    local len2 = string.len(str2)
    local len = 0
    local x = 0

    if (len1 > len2) then
        x = len1 - len2
        for i = 1, x do str2 = "0" .. str2 end
        len = len1
    elseif (len2 > len1) then
        x = len2 - len1
        for i = 1, x do str1 = "0" .. str1 end
        len = len2
    end
    len = len1
    return str1, str2, len
end
-- 按位与
function BitAnd(num1, num2)
    local str1, str2, len = MakeSameLength(num1, num2)
    local rtmp = ""
    for i = 1, len do
        local st1 = tonumber(string.sub(str1, i, i))
        local st2 = tonumber(string.sub(str2, i, i))
        if (st1 == 0) then
            rtmp = rtmp .. "0"
        else
            if (st2 ~= 0) then
                rtmp = rtmp .. "1"
            else
                rtmp = rtmp .. "0"
            end
        end
    end
    return tonumber(rtmp, 2)
end
-- 阳历转阴历
function GregorianToLunar(nSYear, nSMonth, nSDate)
    local nLYear, nLMonth, nLDay
    local i = (GregorianIsLeapYear(nSYear) == 1 and DaysToMonth366[nSMonth] or
                  DaysToMonth365[nSMonth]) + nSDate
    nLYear = nSYear
    local yearInfo
    local yearInfo2
    if nLYear == 2101 then
        nLYear = nLYear - 1
        i = i + (GregorianIsLeapYear(nLYear) == 1 and 366 or 365)
        yearInfo = GetYearInfo(nLYear, 1)
        yearInfo2 = GetYearInfo(nLYear, 2)
    else
        yearInfo = GetYearInfo(nLYear, 1)
        yearInfo2 = GetYearInfo(nLYear, 2)
        if nSMonth < yearInfo or (nSMonth == yearInfo and nSDate < yearInfo2) then
            nLYear = nLYear - 1
            i = i + (GregorianIsLeapYear(nLYear) == 1 and 366 or 365)
            yearInfo = GetYearInfo(nLYear, 1)
            yearInfo2 = GetYearInfo(nLYear, 2)
        end
    end
    i = i - DaysToMonth365[yearInfo]
    i = i - yearInfo2 + 1
    local num = 32768
    local yearInfo3 = GetYearInfo(nLYear, 3)
    local num2 = (BitAnd(yearInfo3, num)) ~= 0 and 30 or 29
    nLMonth = 1
    while (i > num2) do
        i = i - num2
        nLMonth = nLMonth + 1
        num = num / 2
        num2 = (BitAnd(yearInfo3, num)) ~= 0 and 30 or 29
    end
    nLDay = i
    -- 生成农历天干、地支、属相 ==> nongLi--
    local shuXing = nLShuXing[(((nLYear - 4) % 60) % 12) + 1]
    local nongLi =
        shuXing .. '(' .. nLTianGan[(((nLYear - 4) % 60) % 10) + 1] ..
            nLDiZhi[(((nLYear - 4) % 60) % 12) + 1] .. ')年'
    local nLDate
    -- 生成农历月、日 ==> nLDate--*/
    if nLMonth < 1 then
        nLDate = "闰" .. nLMonName[(-1 * nLMonth) + 1]
    else
        nLDate = nLMonName[nLMonth + 1]
    end
    nLDate = nongLi .. nLDate .. "月" .. nLDayName[nLDay + 1]
    return nLYear, nLMonth, nLDay, nLDate
end

-- 公历闰年
function GregorianIsLeapYear(year)
    if year % 4 ~= 0 then return 0 end
    if year % 100 ~= 0 then return 1 end
    if year % 400 == 0 then return 1 end
    return 0
end

function GetYearInfo(lunarYear, index)
    if lunarYear < 1901 or lunarYear > 2100 then return end
    lunarYear = lunarYear + 1
    index = index + 1
    return DateLunarInfo[lunarYear - 1901][index]
end
-- 此处获取农历的代码来自博客
-- Lua 阳历转阴历_BlueMustard的博客-CSDN博客
------------------------------------------------------------------------------------
-- local date_y=os.date("%Y") --取年
local date_y = tonumber(os.date("%Y"))
-- local date_m=os.date("%m") --取月
local date_m = tonumber(os.date("%m"))
-- local date_d=os.date("%d") --取日
local date_d = tonumber(os.date("%d"))
local nLYear, nLMonth, nLDay, nLDate = GregorianToLunar(date_y, date_m, date_d)
local date1 = nLDate
local date2 = nLYear .. "年" .. nLMonth .. "月" .. nLDay .. "日"
-- local date3 = nLMonth .. "月" .. nLDay .. "日"
---------------------------------------------------------------------------------
-- 农历
local function translator(input, seg)
    if (input == "cnl")  or (input == "znl") then
        local lunar_date = (Candidate("date", seg.start, seg._end, date1, "农历"))
        lunar_date.quality = 999
        yield(lunar_date)
        local lunar_ymd = (Candidate("date", seg.start, seg._end, date2, "农历"))
        lunar_ymd.quality = 999
        yield(lunar_ymd)
    end
end
return {translator = translator}
