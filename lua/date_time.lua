---@diagnostic disable: unused-local
--[[

读取系统时间

  rq => 日期、sj => 时间、xq => 星期

--
参考：
  1. https://github.com/LEOYoon-Tsaw/Rime_collections/blob/master/Rime_description.md#%E7%A4%BA%E4%BE%8B-9
  2. https://www.zhihu.com/question/268770492/answer/2190114796
  3. https://zhuanlan.zhihu.com/p/471429749
  4. https://github.com/xkinput/Rime_JD/blob/master/rime/lua/date.lua

--]]

local tool = require("tools/number_to_cn")

local conf = {
  number_en_st = {"0st", "1nd", "2rd", "3th", "4th", "5th", "6th", "7th", "8th", "9th"},
  week_cn = {"星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"},
  week_en = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"},
  week_en_st = {"Sun.", "Mon.", "Tues.", "Wed.", "Thur.", "Fri.", "Sat."},
  month_en = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"},
  month_en_st = {"Jan.", "Feb.", "Mar.", "Apr.", "May.", "Jun.", "Jul.", "Aug.", "Sept.", "Oct.", "Nov.", "Dec."},
}
conf.day_en_st = conf.number_en_st
conf.pattern_date = {
  "{year}年{month}月{day}日", -- 2022年09月05日
  "{year}{month}{day}", -- 20220905
  "{year}/{month}/{day}", -- 2022/09/05
  "{year}.{month}.{day}", -- 2022.09.05
  "{year}-{month}-{day}", -- 2022-09-05
  "{year.number_cn}年{month.arith.number_cn}月{day.arith.number_cn}日", -- 二〇二二年十一月二十五日
  "{month_en} {day_en_st},{year}", -- September 05th,2022
  "{month_en_st} {day_en_st},{year}" -- Sept.05th,2022
}
conf.pattern_today = {
  "{year}{month}{day}", -- 20220905
  "{year}{month}{day}{hour}{min}", -- 202209051836
  "{year}{month}{day}{hour}{min}{sec}", -- 20220905183658
  "{year}-{month}-{day} {hour}:{min}:{sec}", -- 2022-09-05 18:36:58
}
conf.pattern_week = {
  "{week_cn}", -- 星期一
  "{week_en}", -- Monday 
  "{week_en_st}" -- Mon.
}
conf.pattern_time = {
  "{hour}:{min}", -- 18:36
  "{hour}:{min}:{sec}", -- 18:36:58
  "{hour}点{min}分", -- 18点37分
  "{hour}点{min}分{sec}秒" -- 18点37分06秒
}

local function getTimeStr(str)
  while true do
    local pattern = string.match(str, "%b{}")
    if(pattern ~= nil) then
      local replace_index=nil
      if(string.find(pattern, "^{year") ~= nil) then
      -- 年
        replace_index = os.date("%Y")
      elseif(string.find(pattern, "^{month") ~= nil) then
      -- 月
        replace_index = os.date("%m")
      elseif(string.find(pattern, "^{day") ~= nil) then
      -- 日
        replace_index = os.date("%d")
      elseif(string.find(pattern, "^{week") ~= nil) then
      -- 星期
        replace_index = os.date("%w") + 1
      elseif(string.find(pattern, "^{hour") ~= nil) then
      -- 时
        replace_index = os.date("%H")
      elseif(string.find(pattern, "^{min") ~= nil) then
      -- 分
        replace_index = os.date("%M")
      elseif(string.find(pattern, "^{sec") ~= nil) then
      -- 秒
        replace_index = os.date("%S")
      end
      local replace_value = "undefined"
      local flag = false -- 处理链，以flag基准，判断是否处理下去
      if(replace_index ~= nil) then
        local _ni = tonumber(replace_index)
        if(flag == false and string.find(pattern, ".number_cn}$") ~= nil) -- 值：转换为中文，e.g. 0=>〇，1=>一，...
        then
          if(string.find(pattern, ".arith.number_cn}$") ~= nil) then
            -- 21 => 二十一
            replace_value = tool.convert_arab_to_chinese(_ni)
          else
            -- 21 => 二一
            replace_value = ""
            for i = 1, string.len(_ni) do
              local _ni_digit = tonumber(string.sub(_ni, i, i))
              replace_value = replace_value .. tool.convert_arab_to_chinese(_ni_digit)
            end
          end
          replace_value = string.gsub(replace_value, "零", "〇")
          flag = true
        end
        if(flag == false) -- 值：根据conf的prop转换
        then
          local prop_name = string.match(pattern, "{(.+)}")
          local prop = conf[prop_name]
          if(prop ~= nil) then
            local _np = #prop
            if(_np > _ni) then
              replace_value = prop[_ni]
              flag = true
            end
          end
        end
      end
      if(flag == false) then -- 默认值
        replace_value = replace_index
      end
      str = string.gsub(str, pattern, replace_value)
    else
      break
    end
  end
  return str
end

local translator = {}

function translator.func(input, seg, env)
  if(seg:has_tag("date") or (input == "date" or input == "rq")) then
    -- 日期
    local tip = "〔日期〕"
    for _,v in ipairs(conf.pattern_date) do
      local comment = getTimeStr(v)
      local cand = Candidate("date", seg.start, seg._end, comment, tip)
      cand.preedit = string.sub(input, seg._start+1, seg._end)
      cand.quality = 999
      yield(cand)
    end
  end
  if(seg:has_tag("week") or input == "week") then
    -- 星期
    local tip = "〔星期〕"
    for _,v in ipairs(conf.pattern_week) do
      local comment = getTimeStr(v)
      local cand = Candidate("week", seg.start, seg._end, comment, tip)
      cand.preedit = string.sub(input, seg._start+1, seg._end)
      cand.quality = 999
      yield(cand)
    end
  end
  if(seg:has_tag("time") or input == "time" or input == "wt") then
    -- 时间
    local tip = "〔时间〕"
    for _,v in ipairs(conf.pattern_time) do
      local comment = getTimeStr(v)
      local cand = Candidate("time", seg.start, seg._end, comment, tip)
      cand.preedit = string.sub(input, seg._start+1, seg._end)
      cand.quality = 999
      yield(cand)
    end
  end
  if (input == "dt" or input == "today") then
    -- 日期
    local tip = "〔日期〕"
    for _,v in ipairs(conf.pattern_today) do
      local comment = getTimeStr(v)
      local cand = Candidate("today", seg.start, seg._end, comment, tip)
      cand.preedit = string.sub(input, seg._start+1, seg._end)
      cand.quality = 1
      yield(cand)
    end
  end
end

return {
  translator = translator
}
