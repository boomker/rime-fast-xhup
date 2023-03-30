# librime-lua-tools
## rime_api.lua 擴充接口

## list.lua List tools
```lua
local List=require 'tools/list'
l=List(1,2)
l:push(3)
l:push(4)
l:each( function(elm) print(elm) end ) 
l:each(print)
l:map(string.upper)
l:map( tostring) 
l:map( function(elm) return elm * elm end ) 
l:reduce( function(elm,org) return elm+ org end , 0)  -- sum

```
## pattern.lua 
```lua
make_pattern_func= require'tools/pattern'
List= require 'tools/list'
conver_func= make_pattern("xit|abcd|sxyz|")
conver_func("afdc") --> "sfzy"


local projection = List( 
   "xit|abcd|sxyz|",
   "xit|efgh|ijkl|"
   "xit|zl|ZL|"
   ):map(make_pattern)  -- pattern_func of list

function projection:apply(str) 
   return self:reduce(
      function(pattern_func,org) return pattern_func(org) end , 
      str or "" ) 
end 
projection:apply("abc") 

```
## wordninja.lua -- wordninja_word
```lua
wordninja=require("wordninja")
wordninja.init('wordninja_words.txt')
wordninja.test()
wordninja.test('Ilovelua')
wordninja.split("Ilovelua')  -- return table    :concat(" ")

```
## object.lua -- class tools
class method    Word.Parse()
obj method      Word:info()
class instance  Word._name
obj instance    Word:New()._name

    ```lua
    Word= Class("Word",extend)  -- default  Object class
    Word._count=0 -- class instance

    function Word:_initialize(word,info)
    	selfr._word=word -- object instance
    	self._info=word
    	return self
    end## mfilter.lua 反查  lua_filter  以  property "multi_reverse" = name_space 
## completion.lua  未完碼 filter   option "completion"  on/off    :  排除 candidate.type == "completion" 
## multiswitch.lua   主副字典 name_space list 
## keybind_cfg.lua  keybind 設定
    function Word:info()
    	return self._info
    end
    ```
## string.lua
	string.split(str,sp,sp1)
	```lua
	local str="abczzabeuzzabezz"
	str:split("zz") -- { "abc", "abeu", "abe" }
	str="abc abc abc"
	str:split() -- {"abc","abc","abc"}
	str:split(" ") -- {"abc","abc","abc"}
	```
## 其他 copy from luarocks
* [json.lua github](https://github.com/rxi/json.lua)
* [inspect.lua github](https://github.com/kikito/inspect.lua)
* [luaunit.lua decument](https://luaunit.readthedocs.io/en/luaunit_v3_2_1/)


