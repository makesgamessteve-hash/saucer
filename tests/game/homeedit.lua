-- SPDX-License-Identifier: MIT
-- add-home-layout: walk the Villa, enter edit mode, move a stool, confirm
-- the kitchen is still reachable, then undo.
local T = saucer.test
local ap = require("sim.autopilot")
local avatar = require("sim.avatar")
local layout = require("sim.layout")
local homeedit = require("sim.homeedit")
local L = avatar.layout()
local get = function() return T.state().players[1] end
local function said(s)
  for _, m in ipairs(get().msgs or {}) do if m.text:find(s, 1, true) then return true end end
  return false
end
local function use()
  T.press(1, "use")
  T.wait(1)
end

T.assert(get().mode == "wake" and get().panel.kind == "title", "wakes up to the title card")
T.assert(ap.pick(T, 1, get, "Get up"), "picked Get up")
T.assert(get().mode == "walk" and not get().panel, "standing beside the bed")

-- walk up to the galley (stool_a lives by the island)
T.assert(ap.walk_to(T, 1, get, "kitchen"), "walked to the kitchen")
T.assert(avatar.room(L, get().body) == "Kitchen", "in the kitchen")

T.press(1, "edit")
T.wait(1)
T.assert(homeedit.on(get()), "edit mode on")

-- stand by the stool and pick it up
local pose = layout.home_pose("stool_a")
-- go around the kitchen island; a straight walk from the stove hits it
T.assert(ap.walk_path(T, 1, get, {
  { 6.2, 0.6, -2.4 },
  { pose.x - 0.8, 0.6, -2.4 },
  { pose.x - 0.8, 0.6, pose.z },
}, 0.45, 700), "walked to stool_a")
use()
T.assert(homeedit.holding(get()) and homeedit.holding(get()).id == "stool_a", "picked up stool_a")

-- place it a little aft of the stools
T.assert(ap.walk(T, 1, get, { pose.x - 0.8, 0.6, pose.z - 1.4 }, 0.45, 600), "walked to a new spot")
use()
T.assert(not homeedit.holding(get()), "placed the stool")
T.assert(layout.has_moves(get()), "the layout has an override")

-- the kitchen station is still in reach
T.assert(ap.walk_to(T, 1, get, "kitchen"), "walked back to the kitchen station")
-- leave edit so Use opens the kitchen
T.press(1, "edit")
T.wait(1)
T.assert(not homeedit.on(get()), "left edit mode")
use()
T.assert(get().panel and get().panel.kind == "kitchen", "opened the kitchen")
T.press(1, "menu")
T.wait(1)
get().panel = false

-- undo puts the stool back
T.press(1, "undo")
T.wait(1)
T.assert(not layout.has_moves(get()), "undo cleared the override")

T.assert(true, "home edit path finished")
