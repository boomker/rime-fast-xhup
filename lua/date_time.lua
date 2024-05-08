--[[

读取系统时间

  dt/rq => 日期、time => 时间、week => 星期

--
参考：
  1. https://github.com/LEOYoon-Tsaw/Rime_collections/blob/master/Rime_description.md
  2. https://www.zhihu.com/question/268770492/answer/2190114796
  3. https://zhuanlan.zhihu.com/p/471429749
  4. https://github.com/xkinput/Rime_JD/blob/master/rime/lua/date.lua

--]]

local tool = require("tools/number_to_cn")

local conf = {
    day_en_st = {
        "1st",
        "2nd",
        "3th",
        "4th",
        "5th",
        "6th",
        "7th",
        "8th",
        "9th",
        "10th",
        "11th",
        "12th",
        "13th",
        "14th",
        "15th",
        "16th",
        "17th",
        "18th",
        "19th",
        "20th",
        "21th",
        "22th",
        "23th",
        "24th",
        "25th",
        "26th",
        "27th",
        "28th",
        "29th",
        "30th",
        "31th",
    },
    week_cn = {
        "星期日",
        "星期一",
        "星期二",
        "星期三",
        "星期四",
        "星期五",
        "星期六",
    },
    week_en = {
        "Sunday",
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
    },
    week_en_st = { "Sun.", "Mon.", "Tues.", "Wed.", "Thur.", "Fri.", "Sat." },
    month_en = {
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
    },
    month_en_st = {
        "Jan.",
        "Feb.",
        "Mar.",
        "Apr.",
        "May.",
        "Jun.",
        "Jul.",
        "Aug.",
        "Sept.",
        "Oct.",
        "Nov.",
        "Dec.",
    },
}

conf.pattern_date = {
    "{year}年{month}月{day}日", -- 2022年09月05日
    "{year}{month}{day}", -- 20220905
    "{year}/{month}/{day}", -- 2022/09/05
    "{year}.{month}.{day}", -- 2022.09.05
    "{year}-{month}-{day}", -- 2022-09-05
    "{year.number_cn}年{month.arith.number_cn}月{day.arith.number_cn}日", -- 二〇二二年十一月二十五日
    "{month_en} {day_en_st},{year}", -- September 05th,2022
    "{month_en_st} {day_en_st},{year}", -- Sept.05th,2022
}

conf.pattern_day = {
    "{year}{month}{day}",                      -- 20220905
    "{year}{month}{day}{hour}{min}",           -- 202209051836
    "{year}{month}{day}{hour}{min}{sec}",      -- 20220905183658
    "{year}-{month}-{day} {hour}:{min}:{sec}", -- 2022-09-05 18:36:58
}

conf.pattern_week = {
    "{week_cn}",    -- 星期一
    "{week_en}",    -- Monday
    "{week_en_st}", -- Mon.
}

conf.pattern_time = {
    "{hour}:{min}", -- 18:36
    "{hour}:{min}:{sec}", -- 18:36:58
    "{hour}点{min}分", -- 18点37分
    "{hour}点{min}分{sec}秒", -- 18点37分06秒
}

local function gen_day_pattern(num)
    local pattern_days = {}
    local offset_num = tostring(num):match("^-") and num or "+" .. num
    for _, v in ipairs(conf.pattern_day) do
        local cp = string.gsub(v, "day", "day" .. offset_num)
        table.insert(pattern_days, cp)
    end
    return pattern_days
end

local function getTimeStr(str)
    while true do
        local pattern = string.match(str, "%b{}")
        local replace_index = nil
        local replace_value = ""
        local flag = false -- 处理链，以flag基准，判断是否处理下去

        if pattern then
            if string.find(pattern, "^{year") then
                replace_index = os.date("%Y")                    -- 年
            elseif string.find(pattern, "^{month") then
                replace_index = os.date("%m")                    -- 月
            elseif string.match(pattern, "^{day%-%d") then
                local _day = os.date("%d") - pattern:match("%d") -- -N日
                replace_index = _day >= 10 and _day or "0" .. _day
            elseif string.match(pattern, "^{day%+%d") then
                local _day = os.date("%d") + pattern:match("%d") -- +N日
                replace_index = _day >= 10 and _day or "0" .. _day
            elseif string.find(pattern, "^{day") then
                replace_index = os.date("%d")     -- 日
            elseif string.find(pattern, "^{week") then
                replace_index = os.date("%w") + 1 -- 星期
            elseif string.find(pattern, "^{hour") then
                replace_index = os.date("%H")     -- 时
            elseif string.find(pattern, "^{min") then
                replace_index = os.date("%M")     -- 分
            elseif string.find(pattern, "^{sec") then
                replace_index = os.date("%S")     -- 秒
            end

            if replace_index then
                local _ni = tonumber(replace_index)
                -- 值：转换为中文，e.g. 0=>〇，1=>一，...
                if (not flag) and string.find(pattern, ".number_cn}$") then
                    if string.find(pattern, ".arith.number_cn}$") then
                        -- 21 => 二十一
                        replace_value = tool.convert_arab_to_chinese(_ni)
                    else
                        -- 21 => 二一
                        local _nis = tostring(_ni)
                        for i = 1, _nis:len() do
                            local _ni_digit = tonumber(_nis:sub(i, i))
                            replace_value = replace_value .. tool.convert_arab_to_chinese(_ni_digit)
                        end
                    end
                    replace_value = string.gsub(replace_value, "零", "〇")
                    flag = true
                end

                -- 值：根据conf的prop转换
                if not flag then
                    local prop_name = string.match(pattern, "{(.+)}")
                    local prop = conf[prop_name]
                    if prop then
                        replace_value = prop[_ni]
                        flag = true
                    end
                end
            end

            if not flag then -- 默认值
                replace_value = tostring(replace_index)
            end

            local cpattern = pattern:gsub("+", "%%+"):gsub("-", "%%-")
            str = replace_value and string.gsub(str, cpattern, replace_value)
        else
            break
        end
    end
    return str
end

local translator = {}
local input_prefixs = {
    ["/wqt"] = { -2, "前天" },
    ["/wzt"] = { -1, "昨天" },
    ["/now"] = { 0, "此刻" },
    ["/wjt"] = { 0, "今天" }, -- 今天
    ["/wmt"] = { 1, "明天" }, -- 明天
    ["/wht"] = { 2, "后天" }, -- 后天
}

function translator.func(input, seg, env)
    local composition = env.engine.context.composition
    local config = env.engine.schema.config
    local pin_mark = config:get_string("pin_word/comment_mark") or "🔝"
    if (composition:empty()) then return end
    local segment = composition:back()

    if (
            seg:has_tag("date") or (input == "date")
            or (input == "/wd") or (input == "rq")
        ) and (not seg:has_tag("easy_en"))
    then
        -- 日期
        local tip = "〔日期〕"
        for _, v in ipairs(conf.pattern_date) do
            local comment = getTimeStr(v)
            local cand = Candidate("date", seg.start, seg._end, comment, tip)
            cand.preedit = string.sub(input, seg._start + 1, seg._end)
            cand.quality = 999
            yield(cand)
        end
    end

    if (seg:has_tag("week") or input == "week" or input == "/wk")
        and (not seg:has_tag("easy_en"))
    then
        -- 星期
        local tip = "〔星期〕"
        for _, v in ipairs(conf.pattern_week) do
            local comment = getTimeStr(v)
            local cand = Candidate("week", seg.start, seg._end, comment, tip)
            cand.preedit = string.sub(input, seg._start + 1, seg._end)
            cand.quality = 999
            yield(cand)
        end
    end

    if (seg:has_tag("time") or input == "time" or input == "/wt")
        and (not seg:has_tag("easy_en"))
    then
        -- 时间
        local tip = "〔时间 " .. pin_mark .. " 〕"
        for _, v in ipairs(conf.pattern_time) do
            local comment = getTimeStr(v)
            local cand = Candidate("time", seg.start, seg._end, comment, tip)
            cand.preedit = string.sub(input, seg._start + 1, seg._end)
            cand.quality = 999
            yield(cand)
        end
    end

    if input_prefixs[input] then
        -- 最近几天日期
        local _num = input_prefixs[input][1]
        local new_pattern_days = gen_day_pattern(_num)
        segment.prompt = "〔" .. input_prefixs[input][2] .. "〕"
        for _, v in ipairs(new_pattern_days) do
            local comment = getTimeStr(v)
            local cand = Candidate("day", seg.start, seg._end, comment, "")
            cand.preedit = string.sub(input, seg._start + 1, seg._end)
            cand.quality = 999
            yield(cand)
        end
    end
end

return { translator = translator }
