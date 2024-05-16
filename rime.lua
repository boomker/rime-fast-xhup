---@diagnostic disable: lowercase-global

--[[
librime-lua 样例

调用方法：
在配方文件中作如下修改：
```
  engine:
    ...
    translators:
      ...
      - lua_translator@lua_function3
      - lua_translator@lua_function4
      ...
    filters:
      ...
      - lua_filter@lua_function1
      - lua_filter@lua_function2
      ...
```

其中各 `lua_function` 为在本文件所定义变量名。
--]]

--[[
本文件的后面是若干个例子，按照由简单到复杂的顺序示例了 librime-lua 的用法。
每个例子都被组织在 `lua` 目录下的单独文件中，打开对应文件可看到实现和注解。

各例可使用 `require` 引入。
如：
```
  foo = require("bar")
```
可认为是载入 `lua/bar.lua` 中的例子，并起名为 `foo`。
配方文件中的引用方法为：`...@foo`。

--]]

-- I. translators:
-- 本方案帮助菜单, `/oh`, `/help`
flypy_help                     = require("flypy_help_menu")
flypy_help_translator          = flypy_help.translator

-- datetime_translator: 将 `date`, `/wd`, `week`, `/wk`, `time`, `/wt`
-- 翻译为当前日期, 星期, 时间
date_time                      = require("date_time")
datetime_translator            = date_time.translator

-- lunar_translator: 将 `/nl`, 翻译成农历
lunar                          = require("lunar")
lunar_translator               = lunar.translator

-- number_translator: 将 `/cn` + 阿拉伯数字 翻译为大小写汉字
-- 详见 `lua/number.lua`
number                         = require("number")
number_translator              = number.translator

-- 英文生词造词入词库, 输入串末尾跟']'
en_custom                      = require("en_custom")
word_custom_translator         = en_custom.translator

-- LaTeX 公式输入, `/lt`触发
laTex                          = require("laTex")
laTex_translator               = laTex.translator

-- 最近输入历史, `/hs` 触发
commit_history                 = require("commit_history")
history_translator             = commit_history.translator

-- ---------------------------------------------------------------
-- II. filters:

-- charset_filter: 滤除含 CJK 扩展汉字的候选项
-- charset_comment_filter: 为候选项加上其所属字符集的注释
-- 详见 `lua/charset.lua`
local charset                  = require("charset")
charset_filter                 = charset.filter
charset_comment_filter         = charset.comment_filter

local emoji_reduce             = require("reduce_emoji")
emoji_reduce_filter            = emoji_reduce.filter

-- 适用于中文输入方案的中英文之间加空格
word_append_space              = require("word_append_space")
cn_space_en_filter             = word_append_space.filter
space_leader_word              = word_append_space.processor

-- 适用于英文输入方案的英文单词之间加空格
engword_append_space           = require("engword_append_space")
engword_append_space_processor = engword_append_space.processor

-- 英文单词支持首字母大写, 全大写等格式
engword_autocaps               = require("word_autocaps")
word_autocaps_filter           = engword_autocaps.filter
word_autocaps_translator       = engword_autocaps.translator

easy_en                        = require("easy_en")
-- easy_en_processor  = easy_en.processor
easy_en_translator             = easy_en.translator
easy_en_filter                 = easy_en.filter

-- 提升 1 个中文长词的位置到第三候选
long_word_up                   = require("long_word_up")
long_word_up_filter            = long_word_up.filter

--  单字和二字词 全码顶屏(自动上屏)
word_autocommit                = require("word_autocommit")
word_autocommit_processor      = word_autocommit.processor
word_autocommit_translator     = word_autocommit.translator
word_autocommit_filter         = word_autocommit.filter

-- 词条置顶, 支持自定义编码(效果等同于 `custom_phrase`)
pin_word                       = require("pin_word")
pin_word_filter                = pin_word.filter
pin_word_translator            = pin_word.translator
pin_word_processor             = pin_word.processor

-- 强制删词, 隐藏词组
cold_word_drop                 = require("cold_word_drop")
cold_word_drop_filter          = cold_word_drop.filter
cold_word_drop_processor       = cold_word_drop.processor

-- 音码优化 fixed
fly_fixed                      = require("fly_fixed")
fly_fixed_filter               = fly_fixed.filter

-- ---------------------------------------------------------------
-- III. processors:

-- 以词定字
select_char                    = require("select_char")
select_char_processor          = select_char.processor

-- 符号配对
pair_symbols                   = require("pair_symbols")
pair_symbols_processor         = pair_symbols.processor

-- 快捷启动/切换应用, 如 `/jj` 触发; `/fj`: 快捷指令
launcher                       = require("launcher")
launcher_processor             = launcher.processor
launcher_translator            = launcher.translator
launcher_filter                = launcher.filter

-- 成语短句优先, `/`, `0` 触发
idiom_expand                   = require("idiom_abbr_expand")
idiom_expand_processor         = idiom_expand.processor
idiom_expand_translator        = idiom_expand.translator

flypy_switcher                 = require("flypy_switcher")
flypy_switch_processor         = flypy_switcher.processor
flypy_switch_translator        = flypy_switcher.translator
