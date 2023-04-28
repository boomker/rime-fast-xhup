
require("tools/metatable")
-- local puts = require("tools/debugtool")
-- local table_helper = require("tools/table_helper")
local drop_list = require("drop_words")
local drop_word_list = {}
local cold_word_drop = {}


local function write_drop_file()
    local filename = string.format("%s/Library/Rime/lua/drop_words.lua", os.getenv('HOME'))
    os.execute("/usr/local/bin/gsed -i '/}/d' " .. filename)
    os.execute("/usr/local/bin/gsed -i '/return/d' " .. filename)
    Gf = assert(io.open(filename, "a")) --打开
    Gf:setvbuf("line")
    Gf:write(string.format(
    "\t%s\n}", table.concat(drop_word_list, '\n\t'))) --写入
    Gf:write("\nreturn drop_words")
    -- Gf:flush() --刷新
    Gf:close() --关闭
    drop_word_list = {}
end


function cold_word_drop.processor(key, env)
    local engine      = env.engine
    local config      = engine.schema.config
    local context     = engine.context
    -- local commit_text = context:get_commit_text()
    -- local input_code  = context.input
    local turnDown_cand_key  = config:get_string("key_binder/turn_down_cand") or "Control+j"

    if key:repr() == turnDown_cand_key then
        local cand = context:get_selected_candidate()
        table.insert(drop_list, cand.text)
        table.insert(drop_word_list, string.format('"%s",', cand.text))
        write_drop_file()

        context:refresh_non_confirmed_composition()
        return 1 -- processor_return_kNoop
    end
    return 2 -- kNoop
end

---@diagnostic disable-next-line: unused-local
function cold_word_drop.filter(input, env)
    for cand in input:iter() do
        if not table.find_index(drop_list, cand.text) then
            yield(cand)
        end
    end
end


return {
    processor = { func = cold_word_drop.processor },
    filter = cold_word_drop.filter,
}
