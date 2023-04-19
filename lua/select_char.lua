-- 以词定字
-- https://github.com/BlindingDark/rime-lua-select-character
-- 删除了默认按键，需要在 key_binder（default.custom.yaml）下设置
-- http://lua-users.org/lists/lua-l/2014-04/msg00590.html


-- local puts = require("tools/debugtool")

require("tools/metatable")
-- local code_text_tables = {}

local function utf8_sub(s, i, j)
	i = i or 1
	j = j or -1

	if i < 1 or j < 1 then
		local n = utf8.len(s)
		if not n then
			return nil
		end
		if i < 0 then
			i = n + 1 + i
		end
		if j < 0 then
			j = n + 1 + j
		end
		if i < 0 then
			i = 1
		elseif i > n then
			i = n
		end
		if j < 0 then
			j = 1
		elseif j > n then
			j = n
		end
	end

	if j < i then
		return ""
	end

	i = utf8.offset(s, i)
	j = utf8.offset(s, j + 1)

	if i and j then
		return s:sub(i, j - 1)
	elseif i then
		return s:sub(i)
	else
		return ""
	end
end

local function first_character(s)
	return utf8_sub(s, 1, 1)
end

local function last_character(s)
	return utf8_sub(s, -1, -1)
end

local function select_character(key, env)
    local reverse_dict = ReverseDb("build/flypy_xhfast.reverse.bin") -- 从编译文件中获取反查词库
	local engine = env.engine
	local config = engine.schema.config
	local context = engine.context
	local commit_text = context:get_commit_text()
	local code_text = context.input
    -- local composition = cntext.composition

	local first_cand_key = config:get_string('key_binder/select_first_cand') or 'space'
	local second_cand_key = config:get_string('key_binder/select_second_cand') or 'semicolon'
	local third_cand_key  = config:get_string('key_binder/select_third_character') or 'apostrophe'
	local first_key = config:get_string("key_binder/select_first_character")
	local last_key = config:get_string("key_binder/select_last_character")

    if key:release() or key:ctrl() or key:alt() then
        return 2
    end

    local keycode = key.keycode

    if keycode  < 0x20 or keycode  >= 0x7f then
        return 2
    end

    local key_char = string.char(keycode)
    --[[ puts(INFO, #code_text_tables, code_text, key_char)
    if #code_text_tables == 4 or #code_text_tables == 5  then
        code_text = code_text .. key_char
        puts(INFO, "--------", code_text)
    end
    table.insert(code_text_tables, code_text)
    puts(INFO, "++++++++", code_text) ]]
    if keycode and string.find(code_text, "^[%l]+%[[%l]+$") then
        -- local key_char = string.char(keycode)
        local commit_code = reverse_dict:lookup(commit_text) or "" -- 待自动上屏的候选项编码
        -- local xm = string.sub(commit_code, -2, -1)
        -- puts(INFO, "||||||||", code_text, xm, key_char, string.find(xm, key_char))
        local xm_last = string.sub(commit_code, -1)
        if  string.find(xm_last, key_char) then
            engine:commit_text(commit_text)
            context:clear()

            -- code_text_tables = {}
            return 1 -- kAccepted
        end

        --[[
        local cands = {}
        for entry in mem:iter_user() do
            table.insert(cands, entry.text)
        end
        if #cands == 1 then
            engine:commit_text(commit_text)
            context:clear()
        end ]]
    end

    if string.len(code_text) >= 5 and string.find(code_text, "^[%l]+%[[%l]+$") then
        local commit_code = reverse_dict:lookup(commit_text) or "" -- 待自动上屏的候选项编码
        local xm = string.sub(commit_code, -2, -1)
        -- puts(INFO, "||||||||", code_text, commit_code)
        if  xm  == string.sub(code_text, -2, -1) then
            engine:commit_text(commit_text)
            context:clear()

            -- code_text_tables = {}
            return 1 -- kAccepted
        end
    end


    if key:repr() == first_cand_key and string.find(code_text, "^[%w]+%[$") then
		engine:commit_text(string.sub(commit_text, 1, -2))
		context:clear()

		return 1 -- kAccepted
    elseif key:repr() == second_cand_key and string.find(code_text, "^[%w]+%[$") then
        context:select(1)

	    local second_cand_text = context:get_commit_text()
        -- puts(INFO, "-----", second_cand_text )
		engine:commit_text(utf8_sub(second_cand_text, 1, -2))
		context:clear()
		return 1 -- kAccepted
    elseif key:repr() == third_cand_key and string.find(code_text, "^[%w]+%[$") then
        context:select(2)

        local third_cand_text = context:get_commit_text()
        engine:commit_text(utf8_sub(third_cand_text , 1, -2))
        context:clear()
        return 1 -- kAccepted
    end

    if key:repr() == second_cand_key and string.find(code_text, "^%u[%u%l]+$") then
        context:select(1)

	    local second_cand_text = context:get_commit_text()
		engine:commit_text(second_cand_text)
		context:clear()
		return 1 -- kAccepted
    elseif key:repr() == third_cand_key and string.find(code_text, "^%u[%u%l]+$") then
        context:select(2)

	    local second_cand_text = context:get_commit_text()
		engine:commit_text(second_cand_text)
		context:clear()
		return 1 -- kAccepted
    end

	if key:repr() == first_key and commit_text ~= "" then
		engine:commit_text(first_character(commit_text))
		context:clear()

		return 1 -- kAccepted
	end

	if key:repr() == last_key and commit_text ~= "" then
		engine:commit_text(last_character(commit_text))
		context:clear()

		return 1 -- kAccepted
	end

	return 2 -- kNoop
end

-- 初始化
-- local function init(env)
    -- local config = env.engine.schema.config

    -- env.reverse_dict = ReverseDb("build/keydo.reverse.bin") -- 从编译文件中获取反查词库

    -- env.has_auto_select = config:get_bool("speller/auto_select") or false -- 从设置中读取自动上屏设置
    -- env.history_leader = config:get_string("repeat_history/input") -- 从设置中读取历史模式引导键
    -- env.phonetics_code = config:get_string("topup/phonetics_code") -- 从设置中读取音码集合
    -- env.stroke_code = config:get_string("topup/stroke_code") -- 从设置中读取形码集合
-- end

-- return { init = init, func =  select_character }
return select_character
