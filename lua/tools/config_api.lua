#! /usr/bin/env lua
--
-- config_api.lua
-- Copyright (C) 2022 Shewer Lu <shewer@gmail.com>
--
-- Distributed under terms of the MIT license.
--
--[[
config_api.lua
提供 luadata ConfigValue ConfigList ConfigMap ConfigItem 轉換 function
包含遞迴轉換,相同型別不轉換 return 原obj

luadata boolen number string  to ConfigValue
array to ConfigList
map to ConfigMap
ConfigData to ConfigItem
ConfigItem to ConfigData

to_obj
to_item
to_cdata


--]]
--  0xff  unknown

local _type = {
    ['nil'] = 0,
    boolean = 1,
    number = 2,
    string = 3,
    table = 4,
    array = 5,
    map = 6,
    userdata = 8,
    configitem = 0x80,
    configvalue = 0x81,
    configlist = 0x82,
    configmap = 0x83,
    configdata = 0x87,
    undef = 0xff
}
-- base_type : boolen number string
local function base_type(obj)
    local ct = _type[type(obj)]
    return ct >= _type.boolen and ct < _type.table
end

local function utype(uobj)
    if uobj.get_list then
        return _type.configitem
    elseif uobj.element then
        local _configtype = { kScalar = _type.configvalue, kList = _type.configlist, kMap = _type.configmap }
        return _configtype[uobj.type]
    else
        return _type.undef
    end
end

-- return type_name of number
local function ctype(cobj)
    local luatype = _type[type(cobj)]

    if luatype < _type.table then
        return luatype
    elseif luatype == _type.table then
        return #cobj > 0 and _type.array or _type.map
    elseif luatype == _type.userdata then
        return utype(cobj)
    end
end

local function is_basetype(ct)
    return ct == _type.boolean
        or ct == _type.number
        or ct == _type.string
end

local function is_table(ct)
    return ct == _type.array
        or ct == _type.map
end

local function is_configdata(ct)
    return ct == _type.configvalue
        or ct == _type.configlist
        or ct == _type.configmap
end

local function __conv_ltype(str)
    local tp = tonumber(str)
    if tp then return tp end
    tp = str:lower()
    if tp == "false" then
        return false
    elseif tp == "true" then
        return true
    else
        return str
    end
end

local function _conv_ltype(cobj)
    local tp = cobj:get_double() or cobj:get_int() or cobj:get_bool()
    return tp == nil
        and cobj:get_string()
        or tp
end

local function item_to_obj(config_item, level)
    level = level or 99
    if level < 1 then return config_item end

    local ct = ctype(config_item)
    if ct > _type['configitem'] and ct <= _type['configmap'] then
        config_item = config_item.element
    elseif ct ~= _type['configitem'] then
        return config_item
    end

    if config_item.type == "kScalar" then
        return _conv_ltype(config_item:get_value())
    elseif config_item.type == "kList" then
        local cl = config_item:get_list()
        local tab = {}
        for k = 0, cl.size - 1 do
            table.insert(tab, item_to_obj(cl:get_at(k), level - 1))
        end
        return tab
    elseif config_item.type == "kMap" then
        local cm = config_item:get_map()
        local tab = {}
        for i, k in next, cm:keys() do
            tab[k] = item_to_obj(cm:get(k), level - 1)
        end
        return tab
    end
end

local function obj_to_item(obj)
    local ct = ctype(obj)
    if ct == _type.configitem then
        return obj
    elseif is_configdata(ct) then
        return obj.element
    elseif is_basetype(ct) then
        return ConfigValue(tostring(obj)).element
    elseif ct == _type.array then
        local cobj = ConfigList()
        for i, v in ipairs(obj) do
            local o = obj_to_item(v)
            if o then cobj:append(o) end
        end
        return cobj.element
    elseif ct == _type.map then
        local cobj = ConfigMap()
        for k, v in pairs(obj) do
            if type(k) == "string" then
                local o = obj_to_item(v)
                if o then cobj:set(k, obj_to_item(v)) end
            end
        end
        return cobj.element
    end
end

local function _cobjtype(cobj)
    local ldata, citem, cdata = 0, 1, 2
    local ct = ctype(cobj)
    if is_basetype(ct) or is_table(ct) then
        return ldata
    elseif is_configdata(ct) then
        return cdata
    elseif ct == _type.configitem then
        return citem
    end
end

local function item_to_cdata(obj)
    if obj.type == "kScalar" then
        return obj:get_value()
    elseif obj.type == "kMap" then
        return obj:get_map()
    elseif obj.type == "kList" then
        return obj:get_list()
    end
end

local function to_obj(obj)
    local ldata, citem, cdata, llist = 0, 1, 2, 3
    if obj == nil then return nil end

    local ct = _cobjtype(obj)
    if ct == ldata then
        return obj
    elseif ct == cdata then
        return to_obj(obj.element)
    elseif ct == citem then
        return item_to_obj(obj)
    end
end

local function to_item(obj)
    local ldata, citem, cdata, llist = 0, 1, 2, 3
    if obj == nil then return nil end

    local ct = _cobjtype(obj)

    if ct == citem then
        return obj
    elseif ct == cdata then
        return obj.element
    elseif ct == ldata then
        return obj_to_item(obj)
    end
end

local function to_cdata(obj)
    local ldata, citem, cdata, llist = 0, 1, 2, 3
    if obj == nil then return nil end

    local ct = _cobjtype(obj)
    if ct == cdata then
        return obj
    elseif ct == citem then
        return item_to_cdata(obj)
    elseif ct == ldata then
        return to_cdata(obj_to_item(obj))
    end
end

local M = {}
M._type = _type
M.ctype = ctype
M.get_obj = to_obj
M.get_item = to_item
M.get_cdata = to_cdata
return M
