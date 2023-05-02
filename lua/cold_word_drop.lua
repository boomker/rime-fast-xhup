require('tools/string')
require("tools/metatable")
-- local puts = require("tools/debugtool")
local drop_list = require("drop_words")
local hide_list = require("hide_words")
local turndown_freq_list = require("turndown_freq_words")
local tbls = {
    ['drop_list'] = drop_list,
    ['hide_list'] = hide_list,
    ['turndown_freq_list'] = turndown_freq_list
}
local cold_word_drop = {}

local function write_word_to_file(record_type)
    local filename = string.format("%s/Library/Rime/lua/%s_words.lua", os.getenv('HOME'), record_type)
    local record_header = string.format("local %s_words =\n", record_type)
    local record_tailer = string.format("\nreturn %s_words", record_type)
    local fd = assert(io.open(filename, "w")) --打开
    fd:setvbuf("line")
    fd:write(record_header)                   --写入
    -- df:flush() --刷新
    local x = string.format("%s_list", record_type)
    local record = table.serialize(tbls[x])
    fd:write(record)        --写入
    fd:write(record_tailer) --写入
    fd:close()              --关闭
end

local function check_encode_matched(cand_code, word, input_code_tbl, reversedb)
    if #cand_code < 1 and utf8.len(word) > 1 then
        local word_cand_code = string.split(word, "")
        for i, v in ipairs(word_cand_code) do
            local char_code = string.gsub(reversedb:lookup(v), '%[%l%l', '')
            local char_preedit_code = input_code_tbl[i] or " "
            if not string.match(char_code, char_preedit_code) then
                return false
            end
        end
    end
    return true
end

local function append_word_to_droplist(ctx, action_type, reversedb)
    local word = ctx.word
    local input_code = ctx.code
    if action_type == 'drop' then
        table.insert(drop_list, word)
        return true
    end
    local input_code_tbl = string.split(input_code, " ")
    local cand_code = reversedb:lookup(word) or "" -- 待自动上屏的候选项编码
    local match_result = check_encode_matched(cand_code, word, input_code_tbl, reversedb)
    local ccand_code = string.gsub(cand_code, '%[%l%l', '')
    local input_code_str = table.concat(input_code_tbl, '')
    if string.match(ccand_code, input_code) or match_result then
        turndown_freq_list[word] = { input_code_str }
        return 'turndown_freq'
    end
    if not hide_list[word] then
        hide_list[word] = { input_code_str }
        return true
    else
        if not table.find_index(hide_list[word], input_code_str) then
            table.insert(hide_list[word], input_code_str)
            return true
        else
            return false
        end
    end
end

function cold_word_drop.processor(key, env)
    local engine            = env.engine
    local config            = engine.schema.config
    local context           = engine.context
    -- local top_cand_text = context:get_commit_text()
    -- local preedit_code  = context.input
    local preedit_code      = context:get_script_text()
    local turndown_cand_key = config:get_string("key_binder/turn_down_cand") or "Control+j"
    local drop_cand_key     = config:get_string("key_binder/drop_cand") or "Control+d"
    local action_map        = {
        [turndown_cand_key] = 'hide',
        [drop_cand_key] = 'drop'
    }

    local schema_id         = config:get_string("schema/schema_id")
    local reversedb         = ReverseLookup(schema_id)
    if key:repr() == turndown_cand_key or key:repr() == drop_cand_key then
        local cand = context:get_selected_candidate()
        local action_type = action_map[key:repr()]
        local ctx_map = {
            ['word'] = cand.text,
            ['code'] = preedit_code
        }
        local res = append_word_to_droplist(ctx_map, action_type, reversedb)

        context:refresh_non_confirmed_composition()
        if type(res) == "boolean" then
            write_word_to_file(action_type)
        else
            write_word_to_file(res)
        end
        return 1 -- processor_return_kNoop
    end
    return 2     -- kNoop
end

function cold_word_drop.filter(input, env)
    -- local preedit_code = env.engine.context:get_commit_text()
    local context = env.engine.context
    local preedit_code = context.input
    local idx = 3
    local i = 1
    local cands = {}
    for cand in input:iter() do
        if (i <= idx) then
            local tfl = turndown_freq_list[cand.text] or nil
            if not
                ((tfl and table.find_index(tfl, preedit_code)) or
                    table.find_index(drop_list, cand.text) or
                    (hide_list[cand.text] and table.find_index(hide_list[cand.text], preedit_code))
                )
            then
                i = i + 1
                yield(cand)
            end
			table.insert(cands, cand)
        else
			table.insert(cands, cand)
        end
        if (#cands > 50) then
            break
        end
    end
	for _, cand in ipairs(cands) do
        if not
            (
                table.find_index(drop_list, cand.text) or
                (hide_list[cand.text] and table.find_index(hide_list[cand.text], preedit_code))
            )
        then
            yield(cand)
        end
	end
end

return {
    processor = cold_word_drop.processor,
    -- translator = cold_word_drop.translator,
    filter = cold_word_drop.filter,
}
