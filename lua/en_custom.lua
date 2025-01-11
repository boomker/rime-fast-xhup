require("lib/rime_helper")

local T = {}

local function user_dict_exist(word_record, path)
	local file = assert(io.open(path, "r")) --打开
	for line in file:lines() do
		if line == word_record then
			file:close()
			return true
		end
	end
	file:close()
	return false
end

function T.init(env)
	local user_data_dir = rime_api:get_user_data_dir()
	local dict_name = "en_dicts/en_custom.dict.yaml"
	if detect_os():lower() == "windows" then
		env.dict_path = string.format("%s/%s", user_data_dir, dict_name):gsub("/", "\\")
	elseif detect_os():lower() == "ios" then
		user_data_dir =
			"/private/var/mobile/Library/Mobile Documents/iCloud~dev~fuxiao~app~hamsterapp/Documents/RIME/Rime"
		env.dict_path = string.format("%s/%s", user_data_dir, dict_name)
	else
		env.dict_path = string.format("%s/%s", user_data_dir, dict_name)
	end
end

function T.func(input, seg, env)
	if input:match("^%a[%a%p]+\\$") then -- 输入末尾必须是 `\`
		local inp = input:sub(1, -2):gsub(" ", "")
		local record = inp .. "\t" .. inp:gsub("]+", "") .. "\t100000"
		if not user_dict_exist(record, env.dict_path) then
			yield(Candidate("en_custom", seg.start, seg._end, inp, "✅"))
			local file = assert(io.open(env.dict_path, "a"))
			file:write(record .. "\n"):close()
		end
	end
end

return T
