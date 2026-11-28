-- SPDX-License-Identifier: MIT
-- Default actions and bindings (concept §10). On foot, move/turn/look walk and
-- look around; at the helm the same actions fly the saucer. Use takes or
-- leaves the helm. Every local player gets the same
-- binding list; device claims decide which physical device feeds which player.
-- Syntax: device:control[:scale]. Players can rebind in game (persisted).
-- add-wider-dark: "key2:" bindings belong to the right half of a split
-- keyboard (a second player who joined with F2); while the keyboard is split
-- the left-half player ignores every key the right half uses.
return {
  axes = {
    move_x = { "key:D:1", "key:A:-1", "pad:leftx", "touch:stick_x", "xr:stick_lx", "key2:L:1", "key2:J:-1" },
    move_z = { "key:W:1", "key:S:-1", "pad:lefty:-1", "touch:stick_y:-1", "xr:stick_ly:-1", "key2:I:1", "key2:K:-1" },
    lift   = { "key:Space:1", "key:LCtrl:-1", "key:R:1", "key:Z:-1", "pad:righttrigger:1", "pad:lefttrigger:-1",
               "touch:lift", "xr:stick_ry:-1", "key2:O:1", "key2:U:-1" },
    turn   = { "mouse:dx:0.08", "key:Right:1", "key:Left:-1", "pad:rightx", "touch:look_x:2", "xr:stick_rx",
               "key2:Right:1", "key2:Left:-1" },
    look   = { "mouse:dy:-0.08", "key:Up:1", "key:Down:-1", "pad:righty:-1", "touch:look_y:-2", "key2:Up:1", "key2:Down:-1" },
  },
  buttons = {
    shrink = { "key:Q", "mouse:wheel:-1", "pad:leftshoulder", "touch:shrink", "xr:lever_down", "xr:a", "key2:Comma" },
    grow   = { "key:E", "mouse:wheel:1", "pad:rightshoulder", "touch:grow", "xr:lever_up", "xr:b", "key2:Period" },
    size1  = { "key:1", "key2:7" },
    size2  = { "key:2", "key2:8" },
    size3  = { "key:3", "key2:9" },   -- add-pocket-station-visits: the Pocket (docked only)
    tractor = { "mouse:left", "key:F", "pad:a", "touch:tractor", "xr:trigger_r", "key2:RShift" },
    scan   = { "key:V", "pad:y", "touch:scan", "xr:x", "key2:Semicolon" },
    boost  = { "key:LShift", "pad:leftstick", "touch:boost", "xr:grip_l", "key2:Slash" },
    use    = { "key:G", "key:Return", "pad:x", "touch:use", "xr:trigger_l", "key2:Return" },
    camera = { "key:C", "pad:back", "key2:End" },
    menu   = { "key:F1", "key:H", "pad:start", "xr:menu", "key2:Home" },
    jam    = { "key:T", "pad:rightstick", "touch:jam", "xr:y", "key2:Apostrophe" },
    mystery_mode = { "key:M" },   -- add-playtest-recs: the D-pad's up went to the grapple
    -- add-presentation-packaging: XR snap turns (the comfort filter derives them from the right stick)
    snap_left  = { "xr:snap_l" },
    snap_right = { "xr:snap_r" },
    -- add-webxr-cockpit: the snap angle rides along on the snap tick: none = 30 degrees, a = 45, b = 60, both = 15
    snap_a = { "xr:snap_a" },
    snap_b = { "xr:snap_b" },
    -- add-wider-dark: the sector map (fold jumps, party, Xenoarchive) and the new tools
    map    = { "key:Tab", "pad:dpright", "touch:map", "xr:grip_r", "key2:Backslash" },
    decoy  = { "key:B", "pad:dpdown", "touch:decoy", "key2:LeftBracket" },
    shroud = { "key:X", "pad:dpleft", "key2:RightBracket" },
    spike  = { "key:N", "pad:b", "key2:P" },
    -- add-playtest-recs: the grapple has its own key (it used to share X with the Shroud)
    grapple = { "key:Y", "pad:dpup", "touch:grapple", "key2:0" },
    -- add-dock-land-eva: land / lift off at the helm, the emergency teleport home and the return assist on foot
    land   = { "key:L", "pad:b" },
    home   = { "key:Backspace", "pad:back" },
    assist = { "key:Insert", "pad:rightstick" },
    -- add-realistic-lighting: the saucer's lights (sim/lights.lua). The pad's one light button
    -- taps for the headlights (cabin lamps while walking) and holds for the floods.
    headlights   = { "key:4" },
    floods       = { "key:5" },
    cabin_lights = { "key:6" },
    lights       = { "pad:misc1", "pad:touchpad", "pad:rpaddle1", "pad:lpaddle1" },
    -- add-home-layout: append-only so older command frames stay aligned until replays are re-recorded
    edit   = { "key:P" },
    undo   = { "key:Minus", "key2:Minus" },
  },
  -- stable order so action slots (and therefore replays) never depend on table order
  axis_order = { "move_x", "move_z", "lift", "turn", "look" },
  button_order = { "shrink", "grow", "size1", "size2", "tractor", "scan", "boost", "use",
                   "camera", "menu", "jam", "mystery_mode", "size3", "snap_left", "snap_right",
                   "map", "decoy", "shroud", "spike", "grapple", "snap_a", "snap_b", "land", "home", "assist",
                   "headlights", "floods", "cabin_lights", "lights", "edit", "undo" },
}
