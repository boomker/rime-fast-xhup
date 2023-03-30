#! /usr/bin/env lua
--
-- pfilter.lua
-- Copyright (C) 2020 Shewer Lu <shewer@gmail.com>
--
-- Distributed under terms of the MIT license.

--
-- PFilter extend Filter
-- PFilter obj  PFilter:new( pattern_str ,init_status )
--        pattern_str  : string   參見 schema xlit xfrom xderive .....
--        init_status  : bool
--    return  PFilter object
--  method
--        :onn()
--        :off()
--        :toggle()
--        :status()
--        :set_status( bool)
--        :filter(string)
--
--    PFilter.Make_pattern( pattern_str)   -- class method
--    return  filter func
--        pattern_str : string
--
--    example:
--        PFilter.Make_pattern( "xlit|abcd|ABCD|" )
--
--
require 'tools/string'

local List=require 'tools/list'

local function make_xlit(str1,str2)
  local tab1=List(str1:split(""))
  local tab2=str2:split("")
  --  如果 字串長度不一 return str str
  if   #tab1 ~= #tab2 then
    return function(str)  return str,str end
  end
  local strar={}

  tab1:each_with_index(function(v,i) strar[v] = tab2[i] end  )

  --  xlit 主要轉檔程式
  local function  xlit_pattern(str)
    str= str or ""
    return List(str:split("")):map(
      function(v)
	return strar[v] or v
			    end )
      :concat() ,str   -- reterun newstr , str
  end
  return xlit_pattern ,false, nil

end
local function token(__str)
  --local str = ( __str == type(__str) and __str) or ""
  if "string" ~= type(__str)  then
    return "","",""
  end
  local word,chr,substr= __str:gsub( "[$\\]([0-9acdlpsuwxz])", "%%%1")
    :gsub("[$\\]U","%%u")
    :match("%s*(%w*)(.)(.*[^%s])%s*")
  if substr  then
    --return word,substr:match("(.*)" .. chr .."(.*)")
    local str1,str2 = table.unpack( substr:split(chr) )
    return word, str1 or "", str2 or ""
  end
  return "" ,"",""
end


local function make_pattern_func( pattern_str)
  local word,str1,str2 = token(pattern_str)
  local func
  if word == "xform" then
    func= function (str)
      return str:gsub(str1,str2) , str
    end
  elseif word == "erase" then
    func= function( str)
      return str:gsub(str1,"") ,str
    end
  elseif word == "derive" then
    func= function(str )
      return str.." "..str:gsub(str1,str2), str
    end
  elseif word == "xlit" then
    func= make_xlit(str1,str2)
  elseif word == "func" then
    -- 未完成
    --func= loadstring(func_table[str] .."()")
  end

  if  func then
    return func,false,nil
  else
    return nil ,true, string.format("(not match /xlit/xform/erase/derive/func/ ): pattern:%s ",str)
  end
end

return make_pattern_func


