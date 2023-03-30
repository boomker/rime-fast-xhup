#! /usr/bin/env lua
--
-- key_binder.lua
-- Copyright (C) 2021 Shewer Lu <shewer@gmail.com>
--
-- Distributed under terms of the MIT license.
--

-- Module
--   initialize:
--   M( actions )  return: Object of M
--      actions :   action of array
--      action :  hash table
--         when: string of status ( always, composing , has_menu , paging )
--         accept: string of Xkey ( "Control+9" "F4" "A" "z" ....)
--         one of action :
--         toggle : strine of option name
--         set_option: string of option name
--         unset_option: string of option name
--         set_property: string of data and name of property  ( "name:data" )
--         call_func: reference form function(action , env)
--      ret: 當 action 被執行時 return 值 Rejected/Accepted/Noop , 預設 Accepted
--

-- method
--   object:action(keyevent, env )  return : Reject/Accepted/Noop
--
--   object:append( action)  參考 table method
--   object:insert( index,action) 參考 table method
--   object:remove( index) 參考 table method



-- action loop 程序目前  以 each of actions ，可改善成 always composing has_menu paging 順序檢查
-- 舊版 不支援 KeyEvent 無法比對 KeyEvent , 只能使用字串比較 key:repo() == "Shift+Control+k"
-- 且有順序 "Shift+Control+Alt+keyname"
--
local function chk_newver()
  return KeyEvent or true or false
end

require 'tools/rime_api'
local Rejected, Accepted, Noop = 0,1,2

local M={}


function M:new(tab)
  tab= tab or {}
  setmetatable(tab, self)
  return tab
end
M.__index=M
M.__call=M.new
setmetatable(M,{__index=table,__call=M.new})


function M:_take_action(action,env)
  local ctx=env.engine.context
  if action.set_option then
    ctx:set_option( action.set_option,true)
    return action.ret or Accepted
  end

  if action.unset_option then
    ctx:set_option( action.set_option,false)
    return action.ret or Accepted
  end

  if action.toggle then
    ctx:set_option( action.toggle ,
      not ctx:get_option(action.toggle) )
    return action.ret or Accepted
  end
  if action.call_func then
    action.call_func( action, env)
    return action.ret or Accepted
  end


  if action.set_property then
    --  string:  "[property_name]:[data]
    --  string.match(action.set_property, "^([_%a][_%w]*):(.*)$") -- %a a-zA-Z  %w a-zA-Z0-9
    local name,data = action.set_property:match("^([_%a][_%w]*):(.*)$")
    if name and data then
      ctx:set_property(name,data)
      ctx:refresh_non_confirmed_composition()
      return action.ret or Accepted
    end
  end
  return Noop
end
local function chk_key(action,key)
  return chk_newver() and key:eq(KeyEvent(action.accept)) or key:repr() == action.accept
end
function M:action(key,env)
  local status = rime_api.get_status(env.engine.context)
  for i,action in ipairs(self) do
    if status[ action.when ] and chk_key(action,key) then
      return self:_take_action(action, env)
    end
  end
  return  Noop
end





return M
