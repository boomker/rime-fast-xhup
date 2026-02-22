--[[

读取系统时间或时间戳

  date/orq => 日期、time/osj => 时间、week/oxq => 星期、timestamp/ots => 时间戳

--
参考：
  1. https://github.com/LEOYoon-Tsaw/Rime_collections/blob/master/Rime_description.md
  2. https://www.zhihu.com/question/268770492/answer/2190114796
  3. https://zhuanlan.zhihu.com/p/471429749
  4. https://github.com/xkinput/Rime_JD/blob/master/rime/lua/date.lua

--]]

local number_to_cn = require("lib/number_to_cn")

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
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sept",
        "Oct",
        "Nov",
        "Dec",
    },
}

conf.pattern_date = {
    "{year}年{month}月{day}日", -- 2022年09月05日
    "{year}{month}{day}", -- 20220905
    "{year}/{month}/{day}", -- 2022/09/05
    "{year}.{month}.{day}", -- 2022.09.05
    "{year}-{month}-{day}", -- 2022-09-05
    "{month_en} {day_en_st}, {year}", -- September 05th,2022
    "{month_en_st} {day_en_st}, {year}", -- Sept.05th,2022
    "{year.number_cn}年{month.arith.number_cn}月{day.arith.number_cn}日", -- 二〇二二年十一月二十五日
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

local function gen_day_pattern(time_delta, date_patterns)
    local pattern_days = {}
    local offset_day = tostring(time_delta)
    date_patterns = date_patterns or conf.pattern_date
    for _, v in ipairs(date_patterns) do
        local cp = v:gsub("{(.-)}", function(capture)
            if capture:match("^year") or capture:match("^month") then
                return "{" .. capture .. "~}"
            elseif capture:match("^day") then
                return "{" .. capture .. offset_day .. "}"
            end
            return "{" .. capture .. "}"
        end)
        table.insert(pattern_days, cp)
    end
    return pattern_days
end

local function get_month_delta(time_oriented)
    local offset_days = nil
    local this_year = os.date("%Y", os.time())
    local this_month = os.date("%m", os.time())
    local now_days = os.date("%d", os.time()) -- 本月第几天

    local last_month, next_month = 0, 0
    local this_day_amount = nil
    local last_day_amount = nil
    local next_day_amount = nil

    if time_oriented == "after" then
        -- 如果现在是12月份，需要向后推一年
        if this_month == 12 then
            last_month, next_month = this_month - 1, 1
        else
            last_month, next_month = this_month - 1, this_month + 1
        end

        local this_day_ymd = { year = this_year, month = this_month + 1, day = 0 }
        local next_day_ymd = { year = this_year, month = next_month + 1, day = 0 }

        this_day_amount = os.date("%d", os.time(this_day_ymd))
        next_day_amount = os.date("%d", os.time(next_day_ymd))

        -- 如果时间间隔超出了下个月的最后一天，则按最后一天算
        local temp_offset_max = tonumber(this_day_amount)
        local temp_offset_min = this_day_amount - now_days + next_day_amount
        if now_days >= next_day_amount then
            offset_days = temp_offset_min
        else
            offset_days = temp_offset_max
        end
    else
        -- 如果当前是1月份，需要向前推一年
        if this_month == 1 then
            last_month, next_month = 12, this_month + 1
        else
            last_month, next_month = this_month - 1, this_month + 1
        end

        local last_day_ymd = { year = this_year, month = last_month + 1, day = 0 }
        last_day_amount = os.date("%d", os.time(last_day_ymd))

        -- 如果时间间隔超出了下个月的最后一天，则按最后一天算
        if now_days <= last_day_amount then
            offset_days = -last_day_amount
        else
            offset_days = -now_days
        end
    end

    return offset_days
end

local function get_current_time(datetime_fmt_string)
    local raw_datetime_str = datetime_fmt_string
    while true do
        local pattern = string.match(datetime_fmt_string, "%b{}")
        local replace_index = nil
        local replace_value = ""
        local flag = false -- 处理链，以flag基准，判断是否处理下去

        if pattern then
            if string.match(pattern, "^{year.*~}$") then
                local offset = tonumber(raw_datetime_str:match("{day[^}]-([-+]?%d+)}"))
                local calculated_datetime = os.date("%Y%m%d", os.time() + offset * 86400) -- [+-]N日
                replace_index = tostring(calculated_datetime):sub(1, 4)
            elseif string.match(pattern, "^{month.*~}$") then
                local offset = tonumber(raw_datetime_str:match("{day[^}]-([-+]?%d+)}"))
                local calculated_datetime = os.date("%Y%m%d", os.time() + offset * 86400) -- [+-]N日
                replace_index = tostring(calculated_datetime):sub(5, 6)
            elseif string.match(pattern, "^{day[^}]-([-+]?%d+)}") then
                local offset = tonumber(pattern:match("%-?%d+"))
                local calculated_datetime = os.date("%Y%m%d", os.time() + offset * 86400) -- [+-]N日
                replace_index = tostring(calculated_datetime):sub(7, 8)
            elseif string.find(pattern, "^{year") then
                replace_index = os.date("%Y")     -- 年
            elseif string.find(pattern, "^{month") then
                replace_index = os.date("%m")     -- 月
            elseif string.find(pattern, "^{day") then
                replace_index = os.date("%d")     -- 日
            elseif string.find(pattern, "^{week") then
                replace_index = os.date("%w") + 1 -- 周
            elseif string.find(pattern, "^{hour") then
                replace_index = os.date("%H")     -- 时
            elseif string.find(pattern, "^{min") then
                replace_index = os.date("%M")     -- 分
            elseif string.find(pattern, "^{sec") then
                replace_index = os.date("%S")     -- 秒
            end

            local date_time_val = tonumber(replace_index)
            if date_time_val and (date_time_val > 0) then
                -- 值：转换为中文，e.g. 0=>〇，1=>一，...
                local pattern_trim = string.match(pattern, "{(.+)}"):gsub("[~%+%-]?%d?$", "")
                if (not flag) and string.find(pattern_trim, ".number_cn$") then
                    if string.find(pattern_trim, ".arith.number_cn$") then
                        -- 21 => 二十一
                        replace_value = number_to_cn.convert_arab_to_chinese(date_time_val)
                    else
                        -- 21 => 二一
                        local _nis = tostring(date_time_val)
                        for i = 1, _nis:len() do
                            local _ni_digit = tonumber(_nis:sub(i, i))
                            replace_value = replace_value .. number_to_cn.convert_arab_to_chinese(_ni_digit)
                        end
                    end
                    replace_value = string.gsub(replace_value, "零", "〇")
                    flag = true
                end

                -- 值：根据conf的prop转换
                if (not flag) then
                    local prop_name = string.match(pattern, "{(.+)}"):gsub("[~%+%-]?%d?$", "")
                    local prop_tbl = conf[prop_name]
                    if prop_tbl and (#prop_tbl > 0) then
                        replace_value = prop_tbl[date_time_val]
                        flag = true
                    end
                end
            end

            -- 默认值
            if not flag then replace_value = tostring(replace_index) end
            local new_pattern = pattern:gsub("+", "%%+"):gsub("-", "%%-")
            datetime_fmt_string = replace_value and string.gsub(datetime_fmt_string, new_pattern, replace_value)
        else
            break
        end
    end
    return datetime_fmt_string
end

local function list_2_table(list)
    if (not list) or (list.size == 0) then return false end
    local ret = {}
    for i = 1, list.size do
        local item = list:get_at(i - 1)
        if not item then goto continue end
        local value = item:get_value():get_string()
        if not value then goto continue end
        value = value:gsub("{(.-)}", function(capture)
            if capture:match("_cn") then
                if capture:match("^year") then
                    capture = capture:gsub("_cn", ".number_cn")
                elseif capture:match("^month") or capture:match("^day") then
                    capture = capture:gsub("_cn", ".arith.number_cn")
                end
            end
            return "{" .. capture .. "}"
        end)
        table.insert(ret, value)
        ::continue::
    end
    return ret
end

local T = {}
local input_prefixs = {
    ["/wqt"] = { -2, "前天" },
    ["/wzt"] = { -1, "昨天" },
    ["/now"] = { 0, "此刻" },
    ["/wjt"] = { 0, "今天" },
    ["/wmt"] = { 1, "明天" },
    ["/wht"] = { 2, "后天" },
    ["/wxz"] = { 7, "下周" },
    ["/wnk"] = { 7, "下周" },
    ["/wuz"] = { -7, "上周" },
    ["/wlk"] = { -7, "上周" },
    ["/wxy"] = { get_month_delta("after"), "下个月今天" },
    ["/wnm"] = { get_month_delta("after"), "下个月今天" },
    ["/wuy"] = { get_month_delta("before"), "上个月今天" },
    ["/wlm"] = { get_month_delta("before"), "上个月今天" },
}

function T.init(env)
    local config = env.engine.schema.config
    local date_format_list = config:get_list("date_time/date_format")
    local time_format_list = config:get_list("date_time/time_format")
    local enable_time_prefix = config:get_bool("date_time/enable_time_prefix")
    env.date_format_tbl = date_format_list and list_2_table(date_format_list) or conf.pattern_date
    env.time_format_tbl = time_format_list and list_2_table(time_format_list) or conf.pattern_time
    env.enable_time_prefix = enable_time_prefix or false
end

function T.func(input, seg, env)
    local composition = env.engine.context.composition
    if composition:empty() then return end
    local segment = composition:back()
    if seg:has_tag("easy_en") then return end

    -- 日期
    if seg:has_tag("date") or seg:has_tag("date_time") then
        local tip = "〔日期〕"
        segment.prompt = tip
        segment.tags = segment.tags - Set({ "abc" })
        local date_fmt_tbl = env.date_format_tbl or conf.pattern_date
        if input:match("[%+%-]?%d+") then
            local time_delta = input:match("([%+%-]%d+)$")
            date_fmt_tbl = gen_day_pattern(time_delta, date_fmt_tbl)
        end
        for _, v in ipairs(date_fmt_tbl) do
            local cand_text = get_current_time(v)
            local cand = Candidate("date", seg.start, seg._end, cand_text, "")
            cand.preedit = string.sub(input, seg._start + 1, seg._end)
            cand.quality = 999
            yield(cand)
        end
    end

    -- 星期
    if seg:has_tag("week") then
        local tip = "〔星期〕"
        segment.prompt = tip
        for _, v in ipairs(conf.pattern_week) do
            local cand_text = get_current_time(v)
            local cand = Candidate("week", seg.start, seg._end, cand_text, "")
            cand.preedit = string.sub(input, seg._start + 1, seg._end)
            cand.quality = 999
            yield(cand)
        end
    end

    -- 时间
    if seg:has_tag("time") then
        local tip = "〔时间〕"
        segment.prompt = tip
        local hour = tonumber(os.date("%H"))
        local minute = tonumber(os.date("%M"))
        local total_minutes = hour * 60 + minute
        local time_prefix = ""
        local enable_time_prefix = input:match("[a-z]$") and env.enable_time_prefix or false
        if total_minutes >= 1 and total_minutes <= 480 then
            time_prefix = "凌晨 "
        elseif total_minutes >= 481 and total_minutes <= 720 then
            time_prefix = "上午 "
        elseif total_minutes >= 721 and total_minutes <= 1080 then
            time_prefix = "下午 "
        else
            time_prefix = "夜晚 "
        end
        for _, v in ipairs(env.time_format_tbl or conf.pattern_time) do
            local cand_text = get_current_time(v)
            if enable_time_prefix then
                cand_text = time_prefix .. cand_text
                cand_text = cand_text:gsub("(%d%d):(%d%d):?(%d*)", function(h, m, s)
                    local hour_12 = tonumber(h)
                    if hour_12 > 12 then
                        hour_12 = hour_12 - 12
                    end
                    if s and s ~= "" then
                        return string.format("%d:%s:%s", hour_12, m, s)
                    else
                        return string.format("%d:%s", hour_12, m)
                    end
                end)
            end
            local cand = Candidate("time", seg.start, seg._end, cand_text, "")
            cand.preedit = string.sub(input, seg._start + 1, seg._end)
            cand.quality = 999
            yield(cand)
        end
    end

    -- 时间戳
    if seg:has_tag("timestamp") then
        local tip = "〔时间戳〕"
        segment.prompt = tip
        local text = string.format("%d", os.time())
        local cand = Candidate("timestamp", seg.start, seg._end, text, "")
        cand.preedit = string.sub(input, seg._start + 1, seg._end)
        cand.quality = 999
        yield(cand)
    end

    -- 最近几天/周/月日期
    if input_prefixs[input] or seg:has_tag("week_before_after")
        or seg:has_tag("date_before_after") or seg:has_tag("month_before_after")
    then
        local _delta = input_prefixs[input][1]
        local time_delta = tostring(_delta):match("^[%+%-]") and _delta or "+" .. _delta
        local new_pattern_days = gen_day_pattern(time_delta, env.date_format_tbl)
        segment.prompt = "〔" .. input_prefixs[input][2] .. "〕"
        for _, v in ipairs(new_pattern_days) do
            local datetime_val = get_current_time(v)
            local cand = Candidate("date", seg.start, seg._end, datetime_val, "")
            cand.preedit = string.sub(input, seg._start + 1, seg._end)
            cand.quality = 999
            yield(cand)
        end
    end
end

return T
