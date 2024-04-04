require("tools/metatable")

local pin_word_records = require("pin_word_record")

local pin_word = {}

local function get_record_filername()
	local user_distribute_name = rime_api:get_distribution_name()
	if user_distribute_name == "小狼毫" then
		return string.format("%s\\Rime\\lua\\pin_word_record.lua", os.getenv("APPDATA"))
	end
	local system = io.popen("uname -s"):read("*l")
	local filename = nil
	if system == "Darwin" then
		filename = string.format("%s/Library/Rime/lua/pin_word_record.lua", os.getenv("HOME"))
	elseif system == "Linux" then
		local gtk_env = os.getenv("GTK_IM_MODULE")
		filename = string.format(
			"%s/%s/rime/lua/%pin_word_record.lua",
			os.getenv("HOME"),
			gtk_env and (string.find(gtk_env, "fcitx") and ".local/share/fcitx5" or ".config/ibus")
		)
	end
	return filename
end

local function write_word_to_file()
	local filename = get_record_filername()
	local record_header = string.format("local pin_word_records =\n")
	local record_tailer = string.format("\nreturn pin_word_records")
	if not filename then
		return false
	end
	local fd = assert(io.open(filename, "w")) --打开
	fd:setvbuf("line")
	fd:write(record_header) --写入文件头部
	-- fd:flush() --刷新
	local record = table.serialize(pin_word_records) -- lua 的 table 对象 序列化为字符串
	fd:write(record) --写入 序列化的字符串
	fd:write(record_tailer) --写入文件尾部, 结束记录
	fd:close() --关闭
end

function pin_word.processor(key, env)
	local engine = env.engine
	local config = engine.schema.config
	local context = engine.context
	local preedit_code = context:get_script_text():gsub(" ", "")

	local pin_cand_key = config:get_string("key_binder/pin_cand") or "Control+t"
	if key:repr() == pin_cand_key then
		local cand = context:get_selected_candidate()
		if not cand then
			return 2
		end

		if not pin_word_records[preedit_code] then
			pin_word_records[preedit_code] = {}
		end
		table.insert(pin_word_records[preedit_code], cand.text)

		context:refresh_non_confirmed_composition() -- 刷新当前输入法候选菜单, 实现看到实时效果
		write_word_to_file()
		return 1 -- kAccept
	end

	return 2 -- kNoop, 不做任何操作, 交给下个组件处理
end

function pin_word.filter(input, env)
	local input_code = env.engine.context:get_commit_text()
	local pin_cands = {}
	local other_cands = {}
	for cand in input:iter() do
		local pin_word_tab = pin_word_records[input_code] or nil
		if pin_word_tab and table.find_index(pin_word_tab, cand.text) then
			if #pin_cands < #pin_word_tab then
				table.insert(pin_cands, cand)
			end
			if #pin_cands == #pin_word_tab then
				for i, word in ipairs(pin_word_tab) do
					if pin_cands[i].text ~= word then
						for j, pcand in ipairs(pin_cands) do
							if pcand.text == word then
								table.insert(pin_cands, i, pcand)
								table.remove(pin_cands, j + 1)
							end
						end
					end
				end
			end
		else
			table.insert(other_cands, cand)
			if #other_cands > 50 then
				break
			end
		end
	end

	if #pin_cands > 0 then
		for _, cand in ipairs(pin_cands) do
			yield(cand)
		end
	end

	for _, cand in ipairs(other_cands) do
		yield(cand)
	end
end

return {
	processor = pin_word.processor,
	filter = pin_word.filter,
}
