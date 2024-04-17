require("tools/string")
require("tools/metatable")

local drop_list = require("cold_word_record/drop_words")
local hide_list = require("cold_word_record/hide_words")
local turndown_freq_list = require("cold_word_record/turndown_freq_words")
local tbls = {
    ["drop_list"] = drop_list,
    ["hide_list"] = hide_list,
    ["turndown_freq_list"] = turndown_freq_list,
}
local cold_word_drop = {}

local function get_record_filername(record_type)
    local user_distribute_name = rime_api:get_distribution_name()
    if user_distribute_name == "小狼毫" then
        return string.format("%s\\Rime\\lua\\cold_word_record\\%s_words.lua", os.getenv("APPDATA"), record_type)
    end
    local system = io.popen("uname -s"):read("*l")
    local filename = nil
    -- body
    if system == "Darwin" then
        filename = string.format("%s/Library/Rime/lua/cold_word_record/%s_words.lua", os.getenv("HOME"), record_type)
    elseif system == "Linux" then
        local gtk_env = os.getenv("GTK_IM_MODULE")
        filename = string.format(
            "%s/%s/rime/lua/cold_word_drop/%s_words.lua",
            os.getenv("HOME"),
            gtk_env and (string.find(gtk_env, "fcitx") and ".local/share/fcitx5" or ".config/ibus"),
            record_type
        )
    end
    return filename
end

local function write_word_to_file(record_type)
    local filename = get_record_filername(record_type)
    local record_header = string.format("local %s_words =\n", record_type)
    local record_tailer = string.format("\nreturn %s_words", record_type)
    if not filename then
        return false
    end
    local fd = assert(io.open(filename, "w")) --打开
    fd:setvbuf("line")
    fd:write(record_header)                   --写入文件头部
    -- fd:flush() --刷新
    local x = string.format("%s_list", record_type)
    local record = table.serialize(tbls[x]) -- lua 的 table 对象 序列化为字符串
    fd:write(record)                        --写入 序列化的字符串
    fd:write(record_tailer)                 --写入文件尾部, 结束记录
    fd:close()                              --关闭
end

local function check_encode_matched(cand_code, word, input_code_tbl, reversedb)
    if #cand_code < 1 and utf8.len(word) > 1 then -- 二字词以上的词条反查, 需要逐个字去反查
        local word_cand_code = string.split(word, "")
        for i, v in ipairs(word_cand_code) do
            -- 如有 `[` 引导的辅助码情况,  去掉引导符及之后的所有形码字符
            local char_code = string.gsub(reversedb:lookup(v), "%[%l%l", "")
            local _char_preedit_code = input_code_tbl[i] or " "
            -- 如有 `[` 引导的辅助码情况,  同上, 去掉之
            local char_preedit_code = string.gsub(_char_preedit_code, "%[%l+", "")
            if not string.match(char_code, char_preedit_code) then
                -- 输入编码串和词条反查结果不匹配(考虑到多音字, 开启了模糊音, 纠错音), 返回false, 表示隐藏这个词条
                return false
            end
        end
    end
    -- 输入编码串和词条反查结果匹配, 返回true, 表示对这个词条降频
    return true
end

local function append_word_to_droplist(ctx, action_type, reversedb)
    local word = ctx.word
    local input_code = ctx.code
    local input_code_tbl = string.split(input_code, " ")
    local input_code_str = table.concat(input_code_tbl, "")
    if action_type == "drop" then
        table.insert(drop_list, word) -- 高亮选中的词条插入到 drop_list
        return true
    end

    if action_type == "hide" then
        -- 单字和二字词 如果不匹配 就隐藏
        if not hide_list[word] then
            hide_list[word] = { input_code_str }
            return true
        else
            -- 隐藏的词条如果已经在 hide_list 中, 则将输入串追加到 值表中, 如: ['藏'] = {'chang', 'zhang'}
            if not table.find_index(hide_list[word], input_code_str) then
                table.insert(hide_list[word], input_code_str)
                return true
            else
                return false
            end
        end
    end

    local cand_code = reversedb:lookup(word) or "" -- 反查候选字编码
    -- 二字词 的匹配检查, 匹配返回true, 不匹配返回false
    local match_result = check_encode_matched(cand_code, word, input_code_tbl, reversedb)
    local ccand_code = string.gsub(cand_code, "%[%l%l", "")
    -- 如有 `[` 引导的辅助码情况,  去掉引导符及之后的所有形码字符
    local input_str = string.gsub(input_code, "%[%l+", "")
    -- 单字和二字词 的匹配检查, 如果匹配, 降频
    if string.match(ccand_code, input_str) or match_result then
        if turndown_freq_list[word] then
            table.insert(turndown_freq_list[word], input_code_str)
        else
            turndown_freq_list[word] = { input_code_str }
        end
        return "turndown_freq"
    else
        if append_word_to_droplist(ctx, "hide", reversedb) then
            return "hide"
        end
    end
end

function cold_word_drop.processor(key, env)
    local engine = env.engine
    local config = engine.schema.config
    local context = engine.context
    local preedit_code = context:get_script_text()
    local drop_cand_key = config:get_string("key_binder/drop_cand") or "Control+d"
    local hide_cand_key = config:get_string("key_binder/hide_cand") or "Control+x"
    local turndown_cand_key = config:get_string("key_binder/turn_down_cand") or "Control+j"
    local action_map = {
        [drop_cand_key] = "drop",
        [hide_cand_key] = "hide",
        [turndown_cand_key] = "turn_down",
    }

    local schema_id = config:get_string("translator/dictionary") -- 多方案共用字典取主方案名称
    local reversedb = ReverseLookup(schema_id)
    if action_map[key:repr()] then
        local cand = context:get_selected_candidate()
        if not cand then
            return 2
        end
        local action_type = action_map[key:repr()]
        local ctx_map = {
            ["word"] = cand.text,
            ["code"] = preedit_code,
        }
        local res = append_word_to_droplist(ctx_map, action_type, reversedb)

        context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
        if res == nil then
            return 2
        end

        if res == "hide" then
            action_type = "hide"
        end

        if type(res) == "boolean" or res == "hide" then
            -- 期望被删的词和隐藏的词条写入文件(drop_words.lua, hide_words.lua)
            write_word_to_file(action_type)
        else
            -- 期望 要调整词频的词条写入 turndown_freq_words.lua 文件
            write_word_to_file(res)
        end

        return 1 -- kAccept
    end

    return 2 -- kNoop, 不做任何操作, 交给下个组件处理
end

function cold_word_drop.filter(input, env)
    local engine = env.engine
    local config = engine.schema.config
    local cands = {}
    local prev_cand_text = nil
    local idx = config:get_int("cold_wold_reduce_config/idx") or 4

    for cand in input:iter() do
        local cpreedit_code = cand.preedit:gsub("[^%a]", "")
        local cand_text = cand.text:gsub(" ", "")

        local tfl = turndown_freq_list[cand_text] or nil
        if idx > 1 then
            -- 前三个 候选项排除 要调整词频的词条, 要删的(实际假性删词, 彻底隐藏罢了) 和要隐藏的词条
            if tfl and table.find_index(tfl, cpreedit_code) then
                table.insert(cands, cand)
            elseif (
                    cand_text:match("^[%l][%l][%l]?$")
                    or cand_text:match("^[%u][%l][%l]%.?$")
                    or (
                        cand_text:match("^[%u][%a][%a]?$")
                        and (cand_text:lower() == cpreedit_code:lower())
                    )
                    or (
                        cand_text:match("^[%u][%a][%a]%.?") and prev_cand_text
                        and cand_text:lower():match("^" .. prev_cand_text)
                    )
                    or (
                        (cand_text:match("^[%u][%a]?[%a]?") or cand_text:match("[%a]$"))
                        and ((cand_text:match("^[%a]") and (cand_text:match("[%a]+"):len() < 4)))
                        and cand_text:find("([\228-\233][\128-\191]-)")
                    )
                )
                and not (
                    cand_text:lower():match("^ok$")
                    or cand_text:match("^Mac$")
                    or cand_text:match("^Win.")
                )
            then
                table.insert(cands, cand)
                if cand_text:match("^[%a]+$") and not prev_cand_text then
                    prev_cand_text = cand_text:lower()
                end
            elseif
                not (
                    table.find_index(drop_list, cand_text)
                    or (hide_list[cand_text] and table.find_index(hide_list[cand_text], cpreedit_code))
                    or (string.find(cand.comment, "☯")) -- cand.quality == 0.0
                )
            then
                yield(cand)
                idx = idx - 1
            end
        else
            if
                not (
                    table.find_index(drop_list, cand.text)
                    or (hide_list[cand.text] and table.find_index(hide_list[cand.text], cpreedit_code))
                )
            then
                table.insert(cands, cand)
            end
        end

        if #cands > 80 then
            break
        end
    end

    for _, cand in ipairs(cands) do
        yield(cand)
    end
end

return {
    processor = cold_word_drop.processor,
    filter = cold_word_drop.filter,
}
