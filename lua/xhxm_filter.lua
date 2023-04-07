---@diagnostic disable: undefined-global

-- require(utf8_sub)
-- local puts = require("tools/debugtool")
require("tools/metatable")
local utf8_sub = require("utf8_sub")
local xhxm_map = require("xhxm_map")
Xhxm = {}

local function xhxm_filter(input, env)
	Cands = {}
	local commit = env.engine.context:get_commit_text()
    local commitLengths = {3, 4, 5}
    local commitLength = string.len(commit)
    local commitIdx = table.find_index(commitLengths, commitLength)
	for cand in input:iter() do
		local candLength = utf8.len(cand.text)
		local candText = cand.text
		if candLength == 2 and commitIdx  and (string.find(candText, "[^x00-xff]+")) then
			local wordTailChar = utf8_sub.utf8Sub(candText, -1, -1)
			local candComment = "~" .. xhxm_map[wordTailChar]
			local candword = Candidate("custom_type", 0, 8, candText, candComment)
			yield(candword)
        elseif candLength == 2 and commitLength > 5 and (string.find(candText, "[^x00-xff]+")) then
			local candword = Candidate("custom_type", 0, 8, candText, "")
			yield(candword)
		else
			yield(cand)
		end
	end
	-- for _, cand in ipairs(Cands) do
	-- 	yield(cand)
	-- end
end

--[[ local function xhxm_translator(input, seg, env)
	-- for _, c in Cands:iter() do
		if cand:get_dynamic_type() == "Simple" and string.len(commit) == 6 and string.match(commit, "^[%l]+%[%l$") then
			puts(INFO, c.text)
			yield(c)
		end
	-- end
end ]]

Xhxm.xhxm_filter = xhxm_filter
-- Xhxm.xhxm_translator = xhxm_translator

return Xhxm
