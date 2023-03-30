--
--
--[[
-- Dict(filename) return object of dict or  nil
   dict:find_word(word) -- return table(list) or nil
   dict:reduce_find_word(word) return table(list) or nil
   dict:word_iter(word) return iter function for loop
   dict:reduce_iter(word) return iter function for loop


--
-- example
--
local Dict=require 'tools/dict'
local dict= Dict(filename)  --essay.txt
dict:find_words("一天") -- return List ; dict:select(function(word) return word:match("^一天") end )
dict:reduce_find_word("一天") -- return List ;  find_word("一天") + find_word("天")

-- dict:empty( word ) -- return bool
-- coroutine function
for word,weight in dict:reduce_iter("一天") do
  local cand= Candidate("", 1,1, word, weight)
  yield(cand)
end


--]]

List=require 'tools/list'
-- tools/string.lua
function utf8.sub(str,si,ei)
  local function index(ustr,i)
    return i>=0 and ( ustr:utf8_offset(i) or ustr:len() +1 )
    or ( ustr:utf8_offset(i) or 1 )
  end

  local u_si= index(str,si)
  ei = ei or str:utf8_len()
  ei = ei >=0 and ei +1 or ei
  local u_ei= index(str, ei ) -1
  return str:sub(u_si,u_ei)
end
string.utf8_len= utf8.len
string.utf8_offset=utf8.offset
string.utf8_sub=utf8.sub

--  line= "word\twegiht"
local function conv_line(line)
    local word,weight = line:match("^(.*)\t%s*([%d]*).*")
    local key = word:utf8_sub(1,1)
    return key,word,weight
end
local function word_weight(word)
  return tonumber(word:match("^.*-([%d]*).*") )
end

warn("@on")

local function load_essay(filename)
  local fn=io.open(filename)
  if not fn then
    (log and log.warning or warn)(filename .. " not exist in path of user_data or shared_data")
    return
  end

  local words={}
  for line in fn:lines() do

    local data = line:gsub("\t","-")
    local key= utf8.sub(data,1,1)
    words[key] = type(words[key]) == "table" and words[key] or List()
    words[key]:push( data )
  end

  fn:close()

  -- sort dicts by weight
  --[[
  local s_func=function(a,b) return word_weight(a)> word_weight(b) end
  for k,v in pairs(words) do
    --v:sort_self(s_func)
  end
  --]]
  return words
end

local M={}
function M:New(filename)
  --filename = filename or "essay.txt"
  local words =  load_essay(filename)
  if words then
    return setmetatable(words,self)
  end
end
M.__index=M
setmetatable(M,{__call=M.New})



local s_func=function(a,b) return word_weight(a)> word_weight(b) end

function M:find_word( word)
    local dict=self[word:utf8_sub(1,1)] or List()
    --- sort check
    if not dict._sorted then
      dict:sort_self(s_func)
      dict._sorted = true
    end
    --  sert end

    local res_tab= dict
    :select(function(elm) return elm:match("^" .. word .. ".+-.*" ) end )
 --   :sort_self(function(a,b) return word_weight(a) > word_weight(b) end )
    :map(function(elm) return elm:match("^" .. word .. "(.*)-.*$") end )
    return res_tab
end

function M:reduce_find_word(word)
    local res_tab= List()
    while 0 < word:utf8_len()  do
      self:find_word(word)
      :reduce(function(elm,dict) return dict:push(elm) end ,res_tab)

      word= word:utf8_sub(2)
    end
    return res_tab
end


--function M:empty(word)
  --local key=word:utf8_sub(1,1)
  --return self[key] == nil or #self[key] < 2 or false
--end
function M:empty(word)
  for w,wt in self:reduce_iter(word) do
    return false
  end
  return true
end

function M:word_iter(word)
  return coroutine.wrap(function()
    local dict=self[word:utf8_sub(1,1)] or List()
    --- sort check
    if not dict._sorted then
      dict:sort_self(s_func)
      dict._sorted = true
    end
    -- sort check
    for i,elm in ipairs(dict) do
      local w,wt = elm:match("^" .. word .. "(.+)-(%d*).*$" )
      if w then
        coroutine.yield( w,tonumber(wt))
      end
    end
  end )
end

function M:reduce_iter(word)
  return coroutine.wrap(
  function()
    repeat
      for w,wt in self:word_iter(word) do
        coroutine.yield(w,wt)
      end
      word= word:utf8_sub(2)
    until word == ""
  end)
end

return M

