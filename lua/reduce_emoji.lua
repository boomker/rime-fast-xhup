local F = {}

function F.init(env)
	local engine = env.engine
	local config = engine.schema.config
	env.emoji_pos = config:get_int("emoji_reduce/idx") or 6
	env.pin_mark = config:get_string("pin_word/comment_mark") or "🔝"
	--[[
    local logger = require "tools.logger"
    env.mem = Memory(engine, engine.schema)
    env.notifier_commit = env.engine.context.commit_notifier:connect(function(ctx)
        local cand = ctx:get_selected_candidate()
        if (cand:get_dynamic_type() == "Shadow") then
            local preedit = cand.preedit
            local cand_comment = cand.comment
            if env.mem.start_session then env.mem:start_session() end             -- new on librime 2024.05
            env.mem:user_lookup(preedit, true)
            for entry in env.mem:iter_user() do
                logger.writeLog("ccand: " .. cand_comment .. ", " .. entry.text .. ", " .. preedit)
                if cand_comment:match(entry.text) then
                    local commit_count = entry.commit_count - 1
                    env.mem:update_userdict(entry, commit_count, '')
                    logger.writeLog("update_userdict: " .. entry.text .. ", " .. commit_count )
                end
            end
            if env.mem.finish_session then env.mem:finish_session() end           -- new on librime 2024.05
        end
    end)
    --]]
end

function F.func(input, env)
	local top_cand_count = 0
	local emoji_cands = {}
	local other_cands = {}
	local engine = env.engine
	local preedit_code = engine.context.input:gsub(" ", "")
	local emoji_toggle = engine.context:get_option("emoji")
	local wechat_flag = engine.context:get_option("wechat_flag")

	for cand in input:iter() do
		if top_cand_count <= env.emoji_pos then
			if cand.comment:match(env.pin_mark) then
				yield(cand)
			elseif cand.text:match("^%u%a+") and preedit_code:match("^%u%a+") then
				yield(cand)
			elseif
				emoji_toggle
				and (cand:get_dynamic_type() == "Shadow")
				and (not preedit_code:match("^%l+[%[`]%l?%l?$"))
			then
				table.insert(emoji_cands, cand)
			else
				yield(cand)
			end
			top_cand_count = top_cand_count + 1
		else
			table.insert(other_cands, cand)
		end
        if #other_cands >= 120 then break end
	end

	for _, emoji_cand in ipairs(emoji_cands) do
		local cand_text = emoji_cand.text
		if wechat_flag then
			yield(emoji_cand)
		elseif not cand_text:match("^%[.*%]$") then
			yield(emoji_cand)
		end
	end

	for _, cand in ipairs(other_cands) do
		local cand_text = cand.text
		if wechat_flag then
			yield(cand)
		elseif not cand_text:match("^%[.*%]$") then
			yield(cand)
		end
	end
end

--[[
function F.fini(env)
    env.notifier_commit:disconnect()
    if env.mem then
        env.mem:disconnect()
        env.mem = nil
    end
end
--]]

return F
