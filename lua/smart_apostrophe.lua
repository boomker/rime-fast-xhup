
-- local kReject = 0
local kAccepted = 1
local kNoop = 2

local function processor(key_event, env)
   local context = env.engine.context

   if (key_event:repr() ~= 'apostrophe') or key_event:release() then
      return kNoop
   end

   local composition = context.composition
   if composition:empty() then return kNoop end

   local segment = composition:back()
   local menu = segment.menu

   if menu:candidate_count() < 3 then
      env.engine:process_key(KeyEvent("'"))
      return kAccepted
   end

   local page_size = env.engine.schema.page_size
   local selected_index = segment.selected_index
   if selected_index >= page_size then
      env.engine:process_key(KeyEvent("3"))
      return kAccepted
   end

   env.engine:process_key(KeyEvent("3"))
   return kAccepted
end

return processor
