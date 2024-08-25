#! /usr/bin/env lua
--
-- list.lua
-- Copyright (C) 2021 Shewer Lu <shewer@gmail.com>
--
-- Distributed under terms of the MIT license.
--
--! List()  create object  {}
--  List( 1,2 , 3,4) create {1,2,3,4}
--  list( {1,2,3,4})
--  object:each(func, ...) return nil  function(elm,...)
--  ex:    List(1,2,3,4):each(print)
--         -- f(x) =5x^2-2x+3
--         List(1,2,3,4):each(
--         function(elm,pow2,pow1,pow0)
--           print( "f(" .. elm .. ")=" .. pow2*elm*elm*+ elm*pow1 +pow0 )
--         end, 5,-2,3)
--
--  object:each_with_index(func, ...)   function(elm,index,...)
--
--  object:map(func, ...)  return newlist  , function(elm, ...)
--  ex:    List(1,2,3,4):map(
--         function(elm) return elm*2 end )  -- return {2,4,6,8}
--
--  object:map_with_index(func, ...)   function(elm, index, ...)
--
--  object:reduce(func,org,...) return org, function(elm, org, ...)
--  ex:    List(1,2,3,4):reduce(
--         function(elm,org)  return org+elm  end , 0)  -- return 10
--
--  object:select(func,...) return newlist , function(elm,...)
--  ex     List(1,2,3,4):select(
--         function(elm)   return (elm && 1) == 0 end )  -- return {2,4}
--
--  object: push(elm)  append(elm) insert(elm)  insert_at(elm)
--          pop()   shift()  remove_at(index)
--          unshift(elm)
--
--  object: sort   <-- alise table.sort
--
--

local M = {}
M.__index = M
M.__name = "List"
function M:New(...)
    local obj = { ... }
    if #obj == 1 and type(obj[1]) == "table" then
        obj = {}
        for i, v in ipairs(...) do
            table.insert(obj, v)
        end
    end
    obj = setmetatable(obj, self)
    return obj:_init(...)
end

function M:_init(...)
    return self
end

--setmetatable(M,{__index=table, __call=init})
setmetatable(M, { __call = M.New })

-- local metatab={__index=M}


--  return org  obj:reduce( func , org)  func(elm,org) code ..... ,  return org end
--  List(1,2,3):reduce( function(elm,org) return  elm + org end , 0 ) --> return 6
--  List(1,2,3):reduce( function(elm,org) tabel.inert(org,elm) ;return org end , {} ) -> return {1,2,3}
--  List(2,3):reduce( function(elm,org) tabel.inert(org,elm) ;return org end , List(1)  ) -> return {1,2,3}(List)
function M:reduce(func, org, ...)
    for i, v in ipairs(self) do
        org = func(v, org, ...)
    end
    return org
end

function M:each(func, ...)
    for i, v in ipairs(self) do
        local res = func(v, ...)
        if res then return res end
    end
end

function M:each_with_index(func, ...) -- func   function( elm, index , ... )
    for i, v in ipairs(self) do
        func(v, i, ...)
    end
end

function M:class()
    return getmetatable(self).__index
end

local map_null_func = function(elm) return elm end
function M:map(func, ...)
    func = func or map_null_func
    local tab = self:class()() -- {}
    for i, v in ipairs(self) do
        tab:push(func(v, ...))
        --table.insert(tab, func(v, ...) )
    end
    return tab
    --return self:class()(tab)
end

function M:map_with_index(func, ...)
    func = func or map_null_func
    --local tab={}
    local tab = self:class()() -- {}
    for i, v in ipairs(self) do
        tab:push(func(v, v, ...))
        --table.insert(tab, func(v, i, ...) )
    end
    --setmetatable(tab,M)
    --return tab
    return tab
    --return self:class()(tab)
end

function M:select(func, ...)
    local tab = {}
    for i, v in ipairs(self) do
        if func(v, ...) then table.insert(tab, v) end
    end
    return self:class()(tab)
end

function M:select_delete(func, ...)
    local tab = {}
    for i, v in ipairs(self) do
        if not func(v, ...) then table.insert(tab, v) end
    end
    return self:class()(tab)
end

function M:select_with_index(func, ...)
    local tab = {}
    for i, v in ipairs(self) do
        if func(v, i, ...) then table.insert(tab, v) end
    end
    return self:class()(tab)
end

local function def_find(elm, argv)
    return elm == argv
end
function M:find(func, ...)
    local argv = ...
    if type(func) ~= "function" then
        func, argv = def_find, func
    end
    for i, v in ipairs(self) do
        if func(v, argv) then
            return v, i
        end
    end
    return nil
end

function M:find_index(func, ...)
    local _, i = self:find(func, ...)
    return i
end

function M:find_match(pattern)
    return self:find(function(elm) return tostring(elm):match(pattern) end)
end

function M:select_match(pattern)
    return self:select(function(elm) return tostring(elm):match(pattern) end)
end

-- not use
local function deepcompare(t1, t2, ignore_mt)
    local ty1 = type(t1)
    local ty2 = type(t2)
    if ty1 ~= ty2 then return false end
    -- non-table types can be directly compared
    if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
    -- as well as tables which have the metamethod __eq
    local mt = getmetatable(t1)
    if not ignore_mt and mt and mt.__eq then return t1 == t2 end
    for k1, v1 in pairs(t1) do
        local v2 = t2[k1]
        if v2 == nil or not deepcompare(v1, v2) then return false end
    end
    for k2, v2 in pairs(t2) do
        local v1 = t1[k2]
        if v1 == nil or not deepcompare(v1, v2) then return false end
    end
    return true
end

function M:reverse()
    return self:reduce(function(elm, org)
        return org:unshift(elm)
    end, M())
end

function M:size()
    return #self
end

function M:empty()
    return #self == 0
end

function M:clear()
    for i = 1, #self do
        self[i] = nil
    end
    return self
end

function M:insert_check(elm)
    return nil ~= elm
end

function M:insert_at(index, elm)
    --assert(index , --and elm,
    --("args error: %s, index: %d , elm: %s"):format( "List:insert_at(index,elm) ", index,elm) )
    index = (index < 1) and 1
        or index > #self and #self + 1 or index
    table.insert(self, index, elm)
    return self
end

function M:push(elm)
    --return self:insert_at(#self+1, elm)
    table.insert(self, elm)
    return self
end

M.append = M.push
M.unpack = table.unpack
M.concat = table.concat
function M:unshift(elm)
    --return self:insert_at(1,elm)
    table.insert(self, 1, elm)
    return self
end

function M:remove_at(index)
    index = index > 0 and index or index + #self + 1
    if index < 1 then return nil, self end
    return table.remove(self, index), self
end

function M:shift()
    return table.remove(self, 1), self
end

function M:pop()
    return table.remove(self), self
end

M.concat = table.concat
function M:clone()
    return self:class()(
        self:map()
    )
end

function M:sort_self(func, ...)
    table.sort(self, func)
    return self
end

function M:sort(func, ...)
    return self:clone():sort_self()
end

local append_func = function(elm, org) return org:push(elm) end
function M:__add(...)
    return M(...):reduce(append_func, self:clone())
end

--[[
  for i,l in next , {...} do
    M(l):reduce
    return M(...):reduce( append_func, self:clone())
  end
end
--]]
function M:__shl(...)
    return M(...):reduce(append_func, self)
end

function M:__shr(num)
    local l = M()
    for i = 1, num do
        l:unshift(self:pop())
    end
    return l
end

function M:__eq(list)
    return #self == #list and
        table.concat(self, "|") == table.concat(list, "|")
end

function M:__mul(num)
    local l = M()
    for i = 1, num do l = l + self end
    return l
end

function M.Range(num1, num2, step)
    if not num2 then
        num1, num2 = 1, num1
    end
    step = (step and step or 1) * (num1 <= num2 and 1 or -1)
    local l = M()
    print(num1, num2, step)
    for i = num1, num2, step do
        l:push(i)
    end
    return l
end

function M.Parse(obj, num)
    local l = M()
    for i = 1, num do l:push(obj) end
    return l
end

return M
