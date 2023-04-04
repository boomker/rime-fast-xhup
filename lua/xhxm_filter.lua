
---@diagnostic disable: undefined-global

-- require(utf8_sub)
local utf8_sub = require("utf8_sub")
local xhxm_map = require("xhxm_map")

local function xhxm_filter(input, env)
	Cands = {}
	-- CandTwords = {}
    --[[ local map_dict={
        ['付']='rc',
        ['伯']='rb',
        ['父']='bx',
    } ]]
	local commit = env.engine.context:get_commit_text()
	for cand in input:iter() do
		local candLength = utf8.len(cand.text)
		local candText = cand.text
		if candLength == 2 and string.len(commit) == 4 and (string.find(candText, "[^x00-xff]+")) then
            local wordTailChar = utf8_sub.utf8Sub(candText, -1, -1)
            local candComment = "~" .. xhxm_map[wordTailChar]
            local candTword = Candidate("word", 0, 6, candText, candComment)
            -- CandTwords[cand_tword] = candComment
            -- table.insert(CandTwords, candTword)
            yield(candTword)

		-- elseif string.len(commit) == 6 and string.match(commit, "^[%l]+%[%l$") then
  --           for _, c in ipairs(Cands) do
  --               -- if string.sub(c.comment, 2, 2) == string.sub(commit, -1, -1) then
  --               yield(c)
  --               -- end
  --           end
		else
          yield(cand)
            -- table.insert(Cands, cand)
		end
	end
end


return { xhxmfilter = xhxm_filter }
