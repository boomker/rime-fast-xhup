#! /usr/bin/env lua
--
-- object.lua
-- Copyright (C) 2020 Shewer Lu <shewer@gmail.com>
--
-- Distributed under terms of the MIT license.
--
require 'tools/metatable'

function __FILE__(n) n=n or 2 return debug.getinfo(n,'S').soruce end
function __LINE__(n) n=n or 2 return debug.getinfo(n, 'l').currentline end
function __FUNC__(n) n=n or 2 return debug.getinfo(n, 'n').name end
local type_org=type
function type(obj,flag)
	local t=type_org(obj)
	return (t=="table" and type(obj.name) == "function" and obj:name():match("(%a+)") ) or t
end
local _chk_type={"number","nil","string","boolean","function"}
function print_type(value,tab)

	tab = tab or ""
   

--	print("==" .. tab .. " : " .. strvalue .. " ::( " .. type(value) .. " )", "match:char: " ,vars_v,  obj, obj )
	if _chk_type[ type(value) ] then return end


	if type(value) == "table" then
		for k,v in next ,value do

			print_type(v, tab .. "."..  k )
		end
    end
	if type(value) == "userdata" then
		local meta=getmetatable(value)
		if type(meta) == "table" then
			print_type(meta, tab .. "|metatable|" )
		end
	end
	print(
		("=%s:\t%s "):format( tab, value)
	)
end
Object={}
Object.__name="Object"




function Object:clone()
	local object={}
	for k,v in pairs(self) do
		object[k]=v
	end
	--self.__name= "<#" .. tostring(self.__name) .. ">"
	--setmetatable(object,getmetatable(self))

	local object=self:class():New()
	for k,v in pairs(self) do
		object[k]=v
	end
	return object
end
function Object:New(...)
	if not (self==Object or self.__type == Class ) then error( " no method (New) in  instance ") end

	local object = {}
	object.__type=self
	object.__name= "<#" .. tostring(self.__name) .. ">"  -- instance type  <# ... >
	--object._type=self
	--local object_mt={__index=self, __name=self:name(), __call=function(self,...) return self:New(...) end  }

	local object_mt={__index=self, __name=object.__name , __call=function(self,...) return self:New(...) end  }
	setmetatable(object,object_mt)
	if object:_initialize(...) then
		return object
	else
		return
	end
	return object   --  need fix  to check _initialize return  not (false  or  nil)
end
function Object:name()
	return self.__name
end

function Object:_initialize(...)
	return true
end
function Object:_super1(...)
	local func_name= __FUNC__(3)
	local superobj= self:superclass()
	assert( superobj , " superobj is nil ")
	return superobj[func_name](self,...)

end
function Object:_super(func_name,...)
	--local func_name
--	print(" func_name: " , func_name)
	local  superobj= self:superclass()
--	print("superobj: " , superobj)

	superobj =  superobj or Object
--	print("--superobj: ",superobj,"func_name:" ,func_name)
--	assert( type(func_name) ~= "function" , tostring(func_name) .. "not a function." )


--	print( "Object super : ",__FILE__(), __LINE__()  ,func_name,"self :" ,
--	self, "self meta:", getmetatable(self).__index ,  "object_super:" , superobj )
		return superobj[func_name](self,...)

end
function Object:class()
	return getmetatable(self).__index
end
function Object:superclass()
	local cls= self:class()
	return  cls  and cls:class()
--	return self:class():class()
end
function Object:is_a(class)
	-- print(self,type(self))
	--print(" is_a test :" , self, class)
	if  not class then return false end  -- class == nil  return false
	local class_str=  ( type(class) == "string" and class ) or type(class) -- set class to class name
	if  self:name() == class_str   then
		return true
	else
		if self == Object then  return false end  -- class_name ~= class_str and class Object
		return self:class():is_a(class_str) --  nest check untl self == Object
	end

	--if  then return false end  -- check class tdype class  nil  or not class return false
	--class = ( type(class)== "string" and class ) or
	--return self == Object  and self ==
	--local type_str= type(class) == "string"
	--if self == nil   then return false end

	--local self_class = self:class()
	--local chk_class= (type_str and type(self_class) ) or self
	--if  chk_class == class then return true end
	-- print("che_class type:" , type(chk_class) ,   chk_class ,chk_class == class )
	--return self_class:is_a(class)
end
function Object:ancestors()
	local ar={}
	local c=self
	repeat
--		print(c:name())
		table.insert(ar,c)
		c=c:class()
	until c == nil
	return ar

end
function Object:__id()
	return tostring(self)
end
function Object:methods()
	local tab= setmetatable({} , {__index=table})
	for k,v in pairs( self:class() ) do
		if (type(v) == "function" and k:match("^%l[%w_]*")) then tab:isert(k) end
	end
end
function Object:to_s()
	--return tostring(self)

end
function Object:dup()
end

Class=Object:New()
Class.__type=Class
Class.__name="Class"
getmetatable(Class).__name=Class.__name




function Class:_initialize(name,extend)

	--name = name or "<#Class>"
	self.__name= name
	--self.__type=Class
	extend= extend or Object
	getmetatable(self).__index=extend
	getmetatable(self).__name=name  -- Class  override  <#class> to classname
	return true
end

return setmetatable(Object,{__index=nil,__name="Object"} )
