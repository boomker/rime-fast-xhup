--[[
ecdict: 用ECDICT.dict.yaml里的text(英文单词/词组)和comment(音标+中文释义)构建字典，然后用lua_filter把text匹配到的comment显示出来
--]]

require 'tools/string'

--[[ local WordInfo = {}

function WordInfo:init(line)
  self.__index = self
  local word, code, freq, comment = table.unpack(line:split("\t"))
  if word:len() < 1 then return end
  local T = setmetatable({}, self)
  T.word = word
  T.code = code
  T.freq = freq and freq or 0
  T.comment = comment and comment or ""
  return T
end

local EcdictParser = {}

function EcdictParser:init(dict_file)
  self.__index = self
  local T = setmetatable({}, self)
  local f =  io.open(dict_file)
  if not f then return end
  T.word_info_dict = {}
  local in_data_part = false
  for line in f:lines() do
    if not in_data_part then
      if line:match("^%.%.%.$") then
        in_data_part = true
      end
    else
      if not line:match("^#") then
        local word_info = WordInfo:init(line)
        if word_info ~= nil then
          T.word_info_dict[word_info.word] = word_info
        end
      end
    end
  end
  f:close()
  return T
end

function EcdictParser:get_comment(word)
  local word_info = self.word_info_dict[word]
  if word_info ~= nil then
    return word_info.comment
  else
    return ""
  end
end ]]

local ECDICT_OPTION="ecdict"
local ASCII_PUNCT_OPTION="ascii_punct"

local Processor={}

function Processor.init(env)
  env.ecdict_switch_keyrepr= __ecdict_switch_keyrepr and __ecdict_switch_keyrepr or "Shift+Shift_R"
end

function Processor.func(key,env)
  local Rejected,Accepted,Noop=0,1,2
  local keyrepr = key:repr()
  local context=env.engine.context
  local has_menu = context:has_menu()
  local is_composing = context:is_composing()
  if not context:get_option("ascii_mode") then
    if keyrepr == env.ecdict_switch_keyrepr then
      if context:get_option(ECDICT_OPTION) then
        context:set_option(ECDICT_OPTION, false)
        context:set_option(ASCII_PUNCT_OPTION, false)
      else
        context:set_option(ECDICT_OPTION, true)
        context:set_option(ASCII_PUNCT_OPTION, true)
      end
      context:refresh_non_confirmed_composition()
      return Accepted
    end
    if not is_composing or not context:get_option(ECDICT_OPTION) then return Noop end
    local key_char=  key.modifier <=1  and key.keycode <128 and string.char(key.keycode) or ""
    if has_menu then
      if key_char == " " then
        context:commit()
        env.engine:commit_text(key_char)
        return Accepted
      end
    end
  end
  return Noop
end

local function truncate_comment(comment)
  local MAX_LENGTH = 80
  local MAX_UTF8_LENGTH = 40
  local result = comment:gsub("\\n", ' ')
  if #result > MAX_LENGTH then
    result = result:utf8_sub(1, MAX_UTF8_LENGTH)
  end
  return result
end

local Filter={}

function Filter.func(input, env)
  local context = env.engine.context
  local separator = " "
  for cand in input:iter() do
    if cand.text:match("^[%a%d '%-]+$") then -- cand.text contains only letters/numbers/ /'/-
      cand:get_genuine().comment = truncate_comment(separator .. cand.comment)
      yield(cand)
    elseif not context:get_option(ECDICT_OPTION) then
      yield(cand)
    end
  end
end

M = {}
M.processor = { init = Processor.init, func = Processor.func }
M.filter = { init = Filter.init, func = Filter.func }

return M
