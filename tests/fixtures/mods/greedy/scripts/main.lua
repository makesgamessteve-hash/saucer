-- never yields: the engine must cut it off and disable it after 3 strikes
function on_tick(dt, cmds, state)
  local x = 0
  while true do x = x + 1 end
end
