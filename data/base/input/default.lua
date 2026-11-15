-- SPDX-License-Identifier: MIT
-- Default actions and bindings (concept §10). On foot, move/turn/look walk and
-- look around; at the helm the same actions fly the saucer. Use takes or
-- leaves the helm. Every local player gets the same
-- binding list; device claims decide which physical device feeds which player.
-- Syntax: device:control[:scale]. Players can rebind in game (persisted).
return {
  axes = {
    move_x = { "key:D:1", "key:A:-1", "pad:leftx", "touch:stick_x", "xr:stick_lx" },
    move_z = { "key:W:1", "key:S:-1", "pad:lefty:-1", "touch:stick_y:-1", "xr:stick_ly:-1" },
    lift   = { "key:Space:1", "key:LCtrl:-1", "key:R:1", "key:Z:-1", "pad:righttrigger:1", "pad:lefttrigger:-1",
               "touch:lift", "xr:stick_ry:-1" },
    turn   = { "mouse:dx:0.08", "key:Right:1", "key:Left:-1", "pad:rightx", "touch:look_x:2", "xr:stick_rx" },
    look   = { "mouse:dy:-0.08", "key:Up:1", "key:Down:-1", "pad:righty:-1", "touch:look_y:-2" },
  },
  buttons = {
    shrink = { "key:Q", "mouse:wheel:-1", "pad:leftshoulder", "touch:shrink", "xr:lever_down", "xr:a" },
    grow   = { "key:E", "mouse:wheel:1", "pad:rightshoulder", "touch:grow", "xr:lever_up", "xr:b" },
    size1  = { "key:1" },
    size2  = { "key:2" },
    tractor = { "mouse:left", "key:F", "pad:a", "touch:tractor", "xr:trigger_r" },
    scan   = { "key:V", "pad:y", "touch:scan", "xr:x" },
    boost  = { "key:LShift", "pad:leftstick", "touch:boost", "xr:grip_l" },
    use    = { "key:G", "key:Return", "pad:x", "touch:use", "xr:trigger_l" },
    camera = { "key:C", "pad:back" },
    menu   = { "key:F1", "key:H", "pad:start", "xr:menu" },
    jam    = { "key:T", "pad:rightstick", "touch:jam", "xr:y" },
    mystery_mode = { "key:M", "pad:dpup" },
  },
  -- stable order so action slots (and therefore replays) never depend on table order
  axis_order = { "move_x", "move_z", "lift", "turn", "look" },
  button_order = { "shrink", "grow", "size1", "size2", "tractor", "scan", "boost", "use",
                   "camera", "menu", "jam", "mystery_mode" },
}
