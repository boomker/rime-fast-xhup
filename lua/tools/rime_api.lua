#! /usr/bin/env lua
--
-- tools/rime_api.lua
-- 補足 librime_lua 接口 不便性
-- Copyright (C) 2020 Shewer Lu <shewer@gmail.com>
--
-- Distributed under terms of the MIT license.
--
--------------------------------------------
-- add List() Env(env)   Init_projection(config,path) in  global function
-- Env(env)   wrap env table
--   env:config()  wrap config userdata
--   env:context() wrap context userdata
--   env:get_status() get_status
--
--   config: clone_configlist(path)  --return list
--           write_configlist(path, list)
--
--   context: context:Set_option(name)  set  true
--   context: context:Unset_option(name)  set false
--   context: context:Toggle_option(name)  toggle
--
--   Init_prejection(config,path) -- return projection obj
--   -- ex:
--      local projection= Init_projection(config,"preedit_format")
--      projection:apply("abcd")  -- return  preedit string
--
--   -- ex:
--     local api=require 'tools/rime_api'
--     Env(env)
--     env:get_status() -- return status of table
--

-- 2021.4
-- 2021.4 支援 ConfigList ListItem ConfigValue ConfigMap Projection Memory
--
List = require'tools/list'
local puts = require 'tools/debugtool'


local function Version()
  local ver
  if Opencc then
    ver = 147
  elseif KeySequence().repr then
    ver= 139
  elseif  ConfigMap().keys then
    ver= 127
  elseif Projection then
    ver= 102
  elseif KeyEvent then
    ver = 100
  elseif Memory then
    ver = 80
  else
    ver= 79
  end
  return ver
end


--  舊的版本 使用 lua_function  轉換  且 模擬 :apply(str) 接口
local function old_Init_projection(config,path)
  local patterns=List()
  for i=0,config:get_list_size(path)-1 do
    patterns:push( config:get_string(path .. "/@" .. i ) )
  end
  local make_pattern=require 'tools/pattern'
  local projection = patterns:map(function(pattern) return make_pattern(pattorn) end )
  -- signtone
  function projection:apply(str)
    return self:reduce(
    function(pattern_func,org) return pattern_func(org) end , str )
  end
  return projection
end
--  xform xlit ...  轉換
--  projection=Init_projection(config, "translator/preedit_format")
--  projection:apply( code )

function Init_projection( config, path)
  --  old version
  if Version() < 102 then
    return old_Init_projection(config,path)
  end
  local patterns= config:get_list( path )
  if not patterns then
    puts(WARN, __FILE__(),__FUNC__(),__LINE__(), "configlist of " .. path .. "is null" )
  elseif patterns.size <1 then
    puts(WARN, __FILE__(),__FUNC__(),__LINE__(), "configlist of " .. path .. "size is 0" )
  end
  local projection= Projection()
  if  patterns then
    projection:load(patterns)
  else
    puts(WARN, __FILE__(),__FUNC__(), __LINE__(), "ConfigList of  " .. path  ..
      " projection of comment_format could not loaded. comment_format type: " ..
      tostring(patterns) )
  end
  return projection
end



local C={}
function C.Set_option(self,name)
  self:set_option(name,true)
  return self:get_option(name)
end
function C.Unset_option(self,name)
  self:set_option(name,false)
  return self:get_option(name)
end
function C.Toggle_option(self,name)
  self:set_option(name, not self:get_option(name))
  return self:get_option(name)
end

-- Config method clone_configlist write_configlist
-- Env(env):config():clone_configlist("engine/processors") -- return list of string
-- Env(env):config():write_configlist("engine/processors",list)
--
local CN={}
-- clone ConfigList of string to List

function CN.clone_configlist(config,path)
  if not config:is_list(path) then
    log.warning( "clone_configlist: ( " .. path  ..  " ) was not a ConfigList " )
    return nil
  end

  local list=List()
  for i=0, config:get_list_size(path)-1 do
    list:push( config:get_string( path .. "/@" .. i ) )
  end
  return list
end
-- List write to Config
function CN.write_configlist(config,path,list)
  list:each_with_index(
  function(config_string,i)
    config:set_string( path .. "/@" .. i-1 , config_string)
  end )
  return #list
end
--
function CN.find_index(config,path,str)
  if not config:is_list(path) or 1 > config:get_list_size(path)   then
    return
  end
  local size = config:get_list_size(path)
  for i=0,size -1 do
    local ipath= path .. "/@" .. i
    if config:is_value(ipath) and  config:get_string(ipath ):match(str) then
      return i
    end
  end
end
-- just for list of string for now
function CN.config_list_insert(config,path,obj,index)
  if config:is_null(path) then
    local clist= ConfigList()
    clist:append( ConfigValue(str).element )
    config:set( path, clist.element )
    return true
  end
  if not config:is_list(path) then return end
  local size = config:get_list_size(path)
  index = index and index <= size and index or size
  local ipath = path .. "/@before " ..index
  local ctype= type(obj)
  if type(obj) == "string" then
    config:set_string(ipath , obj )
    return true
  end
  return false
end

function CN.config_list_append(config ,path, str)

  if config:is_null(path) then
    local clist= ConfigList()
    clist:append( ConfigValue(str).element )
    config:set_item( path, clist.element )
    return true
  end
  local list = assert( config:get_list(path) , ("%s:%s: %s not a List"):format( __FUNC__(),__LINE__(), path))
  if list and not index then
      list:append( ConfigValue(str).element )
      return true
  else
      return false
  end
end

function CN.config_list_replace(config,path, target, replace )
  --local index=config:find_index( path, target)
  local size= config:is_list(path) and config:get_list_size(path)
  for i = 0,size - 1 do
    local ipath= path .. "/@" .. i
    local l_str= config:get_string( ipath )
    if l_str and l_str:match(target) then
      config:set_string(ipath, replace )
      return true
    end
  end
  return false
end
----- rime_api tools
local M=rime_api
M.Version=Version
-- Context method
-- Env(env):context():Set_option("test") -- set option "test" true
--                    Unset_option("test") -- set option "test" false
--                    Toggle_option("test")  -- toggle "test"
--  Projection api
M.Projection=Init_projection
--  filter tools
function M.load_reversedb(dict_name)
  -- loaded  ReverseDb
  local reverse_filename = "build/"  ..  dict_name .. ".reverse.bin"
  local reversedb= ReverseDb( reverse_filename )
  if not reversedb then
    log.warning( env.name_space .. ": can't load  Reversedb : " .. reverse_filename )
  end
  return reversedb
end
local function Wrap(obj,name,tab)
  local mt=getmetatable(obj)
  for k,v in next,tab do
    mt[name][k]=v
  end
  return obj
end
function M.wrap_context(env)
    local context=env.engine.context
    return Wrap(context,"methods",C)
end

function M.wrap_config(env)
    local config=env.engine.schema.config
    return Wrap(config,"methods",CN)
end

-- env metatable
local E={}
--
function E:Context()
  return rime_api.wrap_context(self)
end
function E:Config()
  return rime_api.wrap_config(self)
end
-- 取得 librime 狀態 tab { always=true ....}
-- 須要 新舊版 差異  comp.empty() -->  comp:empty()
function E:get_status()
  local ctx= self.engine.context
  local stat={}
  local comp= ctx.composition
  stat.always=true
  stat.composing= ctx:is_composing()
  stat.empty= not stat.composing
  stat.has_menu= ctx:has_menu()
  -- old version check ( Projection userdata)
  local ok,empty
  if Version() < 100 then
    ok,empty = pcall(comp.empty)
    empty=  ok  and empty or comp:empty() --  empty=  ( ok ) ? empty : comp:empty()
  else
    empty = comp:empty()
  end
  stat.paging= not empty and comp:back():has_tag("paging")
  return stat
end

function E:print_components(out)
  out = out or INFO
  local config= self:Config()
  puts(out,"-----" ..self.engine.schema.schema_id,self.name_space .. " --------")
  local function list_print(conf,path)
    puts(out,"-----" .. path .. " --------")
    for i=0, conf:get_list_size(path) -1 do
      path_i= path .. "/@" .. i
      puts(out, path_i ..":\t" .. conf:get_string(path_i) )
    end
  end
  List({"processors","segmentors","translators","filters"})
  :map(function(elm) return "engine/" .. elm end )
  :each(function(elm) list_print(config,elm) end)
end


E.__index=E


-- wrap env
-- Env(env):get_status()
-- Env(env):config() -- return config with new methods
-- Env(env):context() -- return context with new methods
function Env(env)
  return setmetatable(env,E)
end

return M
