-- 自动补全配对的符号，并把光标左移到符号对内部
-- ref: https://github.com/hchunhui/librime-lua/issues/84

local function moveCursorToLeft()
   local osascript = [[osascript -e '
      tell application "System Events" to tell front process
         key code 123
      end tell
   ']]
   os.execute(osascript)
end

local pairTable = {
   ['"'] = '"',
   ["“"] = "”",
   ["'"] = "'",
   ["‘"] = "’",
   ["("] = ")",
   ["（"] = "）",
   ["「"] = "」",
   ["["] = "]",
   ["【"] = "】",
   ["〔"] = "〕",
   ["［"] = "］",
   ["〚"] = "〛",
   ["〘"] = "〙",
   ["{"] = "}",
   ["｛"] = "｝",
   ["『"] = "』",
   ["〖"] = "〗",
   ["<"] = ">",
   ["《"] = "》",
   ["apostrophe"] = '“”',
   -- ["Shift+quotedbl"] = '“”'
};

local function pair_symbols(key, env)
   local engine = env.engine
   local context = engine.context
   local composition = context.composition
   local segment = composition:back()
   -- local candidate_count = segment.menu:candidate_count() -- 候选项数量
   -- local selected_candidate=segment:get_selected_candidate() -- 焦点项

   if pairTable[key:repr()] and (not context:is_composing()) then
       engine:commit_text(pairTable[key:repr()])
       context:clear()
       moveCursorToLeft()
       return 1 -- kAccepted 收下此key
   end

   if context:has_menu() or context:is_composing() then
      local keyvalue = key:repr()
      local idx = -1
      if keyvalue == 'space' or keyvalue == '1' then
         idx = 0
      elseif string.find(keyvalue, '^[2-9]$') then
         idx = tonumber(keyvalue) - 1
      elseif keyvalue == '0' then
         idx = 9
      end

      if idx >= 0 and idx < segment.menu:candidate_count() then
         local candidateText = segment:get_candidate_at(idx).text -- 获取指定项 从0起
         local pairedText = pairTable[candidateText]
         if pairedText then
            engine:commit_text(candidateText)
            engine:commit_text(pairedText)
            context:clear()

            moveCursorToLeft()

            return 1 -- kAccepted 收下此key
         end
      end
   end

   -- return 0 -- kRejected librime 不處理
   return 2 -- kNoop 此processor 不處理
end

return {processor = pair_symbols}
