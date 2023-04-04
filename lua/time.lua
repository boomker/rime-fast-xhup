---@diagnostic disable: undefined-global
--[[
time_translator: 将 `time` 翻译为当前时间
--]]

local function translator(input, seg)
   if (input == "time" or input == "st") then
      local canda = Candidate("time", seg.start, seg._end, os.date("%H:%M:%S"), " 时间")
      local candb = Candidate("time", seg.start, seg._end, os.date("%H/%M/%S"), " 时间")

      canda.quality = 100
      candb.quality = 100
      yield(canda)
      yield(candb)
   end
end

return translator
