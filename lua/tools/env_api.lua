#! /usr/bin/env lua
--
-- env_api.lua
-- Copyright (C) 2022 Shewer Lu <shewer@gmail.com>
--
-- Distributed under terms of the MIT license.
--

-- env metatable
local List = require 'tools/list'
local Config_api = require 'tools/config_api'

local E = {}
--
function E:Context()
    return self.engine.context
end

function E:Config()
    return self.engine.schema.config
end

-- 取得 librime 狀態 tab { always=true ....}
-- 須要 新舊版 差異  comp.empty() -->  comp:empty()
function E:get_status()
    local ctx = self.engine.context
    local stat = {}
    local comp = ctx.composition
    stat.always = true
    stat.composing = ctx:is_composing()
    stat.empty = not stat.composing
    stat.has_menu = ctx:has_menu()
    -- old version check ( Projection userdata)
    local ok, empty
    if rime_api.Version() < 100 then
        ok, empty = pcall(comp.empty)
        empty = ok and empty or comp:empty() --  empty=  ( ok ) ? empty : comp:empty()
    else
        empty = comp:empty()
    end
    stat.paging = not empty and comp:back():has_tag("paging")
    return stat
end

-- Config_get_obj(path[,type])  return obj , args: path , type( i
--    type( 1 : ConfigItem 2 : Config of Value or List or Map )
--    type 4 只能單向轉換
--
--  check base_type
--  conver ConfigItem of obj  to list { {path= string, value= string} ...}

local function select_capi(num_type)
    num_type = (type(num_type) == "number") and (num_type > 0) and (num_type <= 3) and num_type or 1
    local ar = { Config_api.get_obj, Config_api.get_item, Config_api.get_cdata, }
    return ar[num_type]
end

function E:Config_get(path, _type)
    local item = self.engine.schema.config:get_item(path)
    local conv_func = select_capi(_type)

    return conv_func(item)
end

function E:Config_set(path, obj)
    if obj == nil then return false end
    return self.engine.schema.config:set_item(path, Config_api.get_item(obj))
end

--  ex:
--   { 1,{a=2,b=4},2,3,4} , "test" --> { {path= "test/@0" , value = "1" } ,{path="test/@2/a", value="2" ... }

local function to_list_with_path(obj, path, tab, loopchk)
    loopchk         = loopchk or {}
    tab             = tab or {}
    path            = path or ""
    local tp        = type(obj)
    local base_type = tp == "number" or tp == "string" or tp == "boolean"
    if loopchk[obj] or base_type then
        table.insert(tab, { path = path, value = obj })
        return tab
    end
    loopchk[obj] = true
    if type(obj) == "table" then
        local is_list = #obj > 0
        local lpath = #path > 0 and path .. "/" or path
        lpath = is_list and lpath .. "@" or lpath

        for k, v in (is_list and ipairs or pairs)(obj) do
            to_list_with_path(v, lpath .. k, tab, loopchk)
        end
        return tab
    end
end

function E:Config_get_with_path(path, tpath)
    local obj = self:Config_get(path)
    tpath = tpath or path
    return to_list_with_path(obj, tpath)
end

local function chk_pdata(path, obj)
    if not obj then return false end
    path:each(function(elm)
        local ok = elm:match("^[%a_]+$") and elm:match("^@%d+$")
        if not ok then return false end
    end)
    return true
end

function E:Config_set_with_path(pdata)
    for i, v in ipairs(pdata) do
        if chk_pdata(v.path, v.obj) then
            self:Config_set(v.path, v.obj)
            -- else
            --     Log(WARN, "config set error", v.path, v.obj)
        end
    end
end

function E:config_path_to_str_list(path)
    return List(self:Config_get(path))
        :map(function(elm) return elm.path .. ": " .. elm.value end)
end

-- Get_tag  args :  ()  , (nil, "translator") ,("date")
function E:Get_tag(def_tag, ns)
    def_tag = def_tag or ""    -- default ""
    ns = ns or self.name_space -- default env.name_space
    return self.engine.schema.config:get_string(ns .. "/tag") or def_tag
end

function E:Get_tags(ns)
    ns = ns or self.name_space
    return Set(
        self:Config_get(ns .. "/tags"))
end

function E:append_value_before(path, elm, mvalue)
    local obj = self:Config_get(path)
    if type(obj) ~= "table" or #obj < 1 then return end
    local list = List(self:Config_get(path))
    if list:find(elm) then return end
    -- local index = list:find(mvalue)
    -- local dpath = index and path .. "/@before " .. index - 1 or path .. "/@next"

    -- if not self:Config_set(dpath, elm) then
    --     Log(ERROR, "config set ver error", "path", path, "value", elm)
    -- end
end

-- option function

-- context warp
local C = {}
function C.Set_option(self, name)
    self:set_option(name, true)
    return self:get_option(name)
end

function C.Unset_option(self, name)
    self:set_option(name, false)
    return self:get_option(name)
end

function C.Toggle_option(self, name)
    self:set_option(name, not self:get_option(name))
    return self:get_option(name)
end

function E:Set_option(name)
    self.engine.context:set_option(name, true)
    return true
end

function E:Unset_option(name)
    self.engine.context:set_option(name, false)
    return false
end

function E:Toggle_option(name)
    local context = self.engine.context
    context:set_option(name, not context:get_option(name))
    return context:get_option(name)
end

function E:Get_option(name)
    return self.engine.context:get_option(name)
end

-- property function
function E:Get_property(name)
    return self.engine.context:get_property(name)
end

function E:Set_property(name, str)
    self.engine.context:set_property(name, str)
    return str
end

-- processor function  config
function E:get_keybinds(path)
    path = (path or self.name_space) .. "/keybinds"
    local tab = self:Config_get(path)
    tab = type(tab) == "table" and tab or {}
    for key, name in next, tab do
        tab[key] = KeyEvent(name)
    end
    return tab
end

function E:components_str()
    return List("processors", "segmentors", "translators", "filters")
        :map(function(elm) return "engine/" .. elm end)
        :reduce(function(path, list)
            return list + self:Config_get_with_path(path)
        end, List())
        :map(function(elm) return elm.path .. ": " .. elm.value end)
end

--[[
function E:print_components(out)
    Log(out, string.format("----- %s : %s ----", self.engine.schema.schema_id, self.name_space))
    self:components_str():each(function(elm)
        Log(out, elm)
    end)
end
--]]

---  delete
function E:components(path)
    return self:Config_get(path or "engine")
end

E.__index = E

-- wrap env
-- Env(env):get_status()
-- Env(env):config() -- return config with new methods
-- Env(env):context() -- return context with new methods

local function Env(env)
    return setmetatable(env, E)
end

return Env
