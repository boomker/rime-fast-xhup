#! /usr/bin/env lua
--
-- meta_string.lua
-- Copyright (C) 2020 Shewer Lu <shewer@gmail.com>
--
-- Distributed under terms of the MIT license.
--

local Class= require 'muti_reverse'
local Filter= Class.Filter

setmetatable(string,{__index=table})
local metatable_string= metatable()

function metatable_string:filter(filter,...)
	local _filter = filter or FILTER
	if _filter then 
		local _type= type(_filter)
		if _type == "function" then 
			return _filter( self, ... )
		elseif _type == "table"  or _filter:is_a(Filter) then
			return _filter:filter(self, ...)
		end 
	end 
	return str,str
end 

function metatable_string.split( str, sp,sp1)
	if   type(sp) == "string"  then     
		if sp:len() == 0 then
			sp= "([%z\1-\127\194-\244][\128-\191]*)"
		elseif sp:len() > 1 then 
			sp1= sp1 or "^"
			_,str= pcall(string.gsub,str ,sp,sp1)
			sp=  "[^".. sp1.. "]*"

		else 
			if sp =="%" then 
				sp= "%%"
			end 
			sp=  "[^" .. sp  .. "]*"
		end 
	else 
		sp= "[^" .. " " .."]+"
	end

	local tab= setmetatable( {} , {__index=table} )
	flag,res= pcall( string.gmatch,str,sp)
	for  v  in res   do
		tab:insert(v)
	end 
	return tab 
end 

return  metatable_string
