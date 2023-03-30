#! /usr/bin/env lua
--
-- object_new.lua
-- Copyright (C) 2021 Shewer Lu <shewer@gmail.com>
--
-- Distributed under terms of the MIT license.
--

function __FILE__(n) n=n or 2 return debug.getinfo(n,'S').source end
function __LINE__(n) n=n or 2 return debug.getinfo(n, 'l').currentline end
function __FUNC__(n) n=n or 2 return debug.getinfo(n, 'n').name end

local Module={}

Module._name="Module" 
function Module:__assert( msg)
   return ("Error: [%s:%s]  %s:%s() : %s"):format(
     __FILE__(3),__LINE__(3) ,self:name(), __FUNC__(3), msg  )  
 end 
function Module:Superclass()
  assert( self:is_class() , self:__assert("class method can not callable") )
  local  mt = getmetatable(self) 
  return mt:is_class() and mt  or nil 
end 
function Module:New(...)
  assert(  self:is_class(), self:__assert("class method can  not callable.")) 
  local obj=setmetatable( { } ,self)
  return obj:_init(...) and obj
end
-- meta function 
function Module:__index(key)
  return Module[key]
end 
function Module:is_class()
  return  tostring( self) == tostring(self.__index) 
end 
function Module:name()
  -- wraning  : List:__eq() #{} == #{_name}  = true
  return tostring( self.__index) == tostring(self) and self._name or "#" .. self._name
end 
function Module:class()
  return self:is_class()  and  Class  or  self.__index 
	--return getmetatable(self).__index 
end 
Module.__call = Module.New 


function _Module(name,mu)
  mu = mu or Module
  --mttab=  mttab or Base 
  local MU= setmetatable({} ,mu)
  MU._name=name
  MU.__index = MU
  MU.__call= MU.New 
  return MU
end 


print("-------------Class -----------------")
Class= _Module("Class")
print("-------------Object-----------------")
Object = _Module("Object")

function Object:super(funcname,...)
  local superclass= self:class():Superclass()
  assert(superclass  , self:__assert("Can't get superclass "))
  local superfunc= superclass[funcname]
  assert( type(superfunc) == "function", self:__assert("can not find then method " .. funcname ))
  return superfunc(self,...)
end 


--[[
Object={}
setmetatable( Object , Base )
Object._name="Object"
Object.__index= Object
Object.__call= Object.New

Class={}
setmetatable(Class, Base)
Class._name="Class" 
Class.__index=Class
Class.__call=Class.New 

-- move to Base 
--function Object:__assert( msg)
   --return ("Error: [%s:%s]  %s:%s() : %s"):format(
     --__FILE__(3),__LINE__(3) ,self:name(), __FUNC__(3), msg  )  
 --end 
-- move to  Module
function Object:is_class() 
  return  tostring( self) == tostring(self.__index) 
end 
function Object:is_instance() 
  return   tostring( self) ~= tostring(self.__index) 
end 

  --assert( self.__name == nil or  self.__name:match("^[%a_]") ,
 --local i=0 ;  print( i, "__FUNC__(): ", __FUNC__(i), "debuginfo:" , debug.getinfo(i,'n').name  )
  --i=1 ; print( i, "__FUNC__(): ", __FUNC__(i), "debuginfo:" , debug.getinfo(i,'n').name  )
  --i=2 ; print( i, "__FUNC__(): ", __FUNC__(i), "debuginfo:" , debug.getinfo(i,'n').name  )
  --i=3 ; print( i, "__FUNC__(): ", __FUNC__(i), "debuginfo:" , debug.getinfo(i,'n').name  )
  --i=4 ; print( i, "__FUNC__(): ", __FUNC__(i), "debuginfo:" , debug.getinfo(i,'n').name  )
  --
function Object:name()
  -- wraning  : List:__eq() #{} == #{_name}  = true
  return tostring( self.__index) == tostring(self) and self._name or "#" .. self._name
end 
-- move to Class 
-- not ok 
function Object:super(...)
  local i=3
  local tab=debug.getinfo(i,'n')
  local name= tab and tab.name  
  print("FUNC__: ", __FUNC__(i), name  )
  return getmetatable(self)[name](... )
end 
--function Object:New(...)
  --assert(  self:is_class(), self:__assert("class method can  not callable.")) 
  --local obj=setmetatable( { } ,self)
  --return obj:_init(...) and obj
--end
function Object:class()
  return self:is_class()  and  Class  or  self.__index 
	--return getmetatable(self).__index 
end 
function Object:clone()
  __assert(  self:is_instance(), self:_errmsg(  "Class can not callable.") )

	local object={}
	for k,v in pairs(self) do
		object[k]=v
	end
  return setmetatable( object,self.__index )
end
function Object:_init(...)
  return self
end 
--function Object:name()
  --return   self == self.__index  and self._name  or "#" .. self._name
--end 


-- Object.__name= Object._name 

local function extend(self,class , superclass )
  print(self,class,superclass or Object)
  setmetatable(class,superclass or Object )
--  class.__name=class._name
  class.__call=class.__call
  return class
end   
--]]
function Class:_init(classname,superclass)
  superclass = superclass or Object 
  assert( superclass:is_class() ,superclass:__assert("isn\'t Class ") )
  setmetatable( self ,superclass  )
--  class.__name=class._name
--
  self._name=classname
  self.__index = self
  self.__call=self.New
  return self
end 
function Object:_init(...)
  return self 
end 

--Object=_Module("Object")
--[[
--]]
