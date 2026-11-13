-- SPDX-License-Identifier: MIT
-- 2D HUD in low-res viewport pixels (8x8 font).
local configs = require("sim.config")
local loot = require("sim.loot")
local vec = require("lib.vec")
local M = {}

local WHITE, DIM, GREEN, RED, AMBER, CYAN = { 1, 1, 1, 1 }, { 0.6, 0.65, 0.75, 1 }, { 0.4, 1, 0.5, 1 },
  { 1, 0.35, 0.3, 1 }, { 1, 0.8, 0.3, 1 }, { 0.4, 0.9, 1, 1 }
M.MSG_TICKS = 300

local HINTS = {
  kbm = "WASD move  SPACE/CTRL lift  MOUSE turn  Q/E size  F tractor  C camera  H help",
  pad = "LS move  RS look  LT/RT lift  LB/RB size  A tractor  BACK camera",
  touch = "Stick move  drag look  slider lift  buttons size/tractor",
  xr = "Sticks fly  lever size  trigger tractor",
}
M.HINTS = HINTS

local HELP = {
  "SAUCER - controls",
  "Move W A S D, lift Space/Ctrl (or R/Z)",
  "Turn/look: mouse (click to capture) or arrows",
  "Shrink Q / grow E, or 1-4 to pick a size",
  "Tractor F or left click, boost Shift",
  "Camera C, mystery mode M, help H/F1",
  "Gamepad, touch and WebXR work too.",
}
M.HELP = HELP

function M.ladder(v, p, x, y)
  local ship = p.ship
  for i, c in ipairs(configs.all()) do
    local col = DIM
    if i == ship.size then col = GREEN end
    if ship.target and i == ship.target then col = AMBER end
    v:rect(x + (i - 1) * 12, y, 10, 10, { col[1] * 0.3, col[2] * 0.3, col[3] * 0.3, 0.8 })
    v:text(x + 1 + (i - 1) * 12, y + 1, c.name:sub(1, 1), col)
  end
end

function M.bearing(p, target)
  local d = vec.sub(target, p.ship.pos)
  local a = saucer.math.wrap(saucer.math.atan2(d[1], d[3]) - p.ship.yaw)
  if a > 0.25 then return "<" elseif a < -0.25 then return ">" end
  return "^"
end

function M.nav(state, p)
  if p.site ~= 0 then return nil end
  local best, bd
  for _, s in ipairs(state.sector.sites) do
    local d = vec.dist(s.pos, p.ship.pos)
    if not bd or d < bd then best, bd = s, d end
  end
  return best, bd
end

function M.draw(v, state, p, target)
  local W, H = v.width, v.height
  local ship = p.ship
  local c = configs.get(ship.size)
  -- size + charge
  v:rect(4, 4, 120, 28, { 0, 0, 0, 0.45 })
  v:text(8, 7, c.name:upper(), WHITE)
  M.ladder(v, p, 70, 6)
  local charge = ship.charge / configs.all().max_charge
  v:rect(8, 18, 100, 5, { 0.15, 0.15, 0.2, 1 })
  v:rect(8, 18, 100 * charge, 5, charge > 0.3 and CYAN or RED)
  v:text(8, 25, string.format("CHG %d", ship.charge // 1), DIM)
  -- hold
  local hot = 0
  for _, it in ipairs(p.hold) do if it.hot then hot = hot + 1 end end
  v:text(8, 36, string.format("HOLD %d/%d HOT %d BANK %dc", #p.hold, configs.all().hold_slots, hot, p.banked_value), DIM)
  -- crosshair
  v:text(W // 2 - 4, H // 2 - 4, "+", p.tractor and AMBER or WHITE)
  -- navigation
  local site, d = M.nav(state, p)
  if site then
    v:text(W // 2 - 60, 6, string.format("%s SITE %d %dm", M.bearing(p, site.pos), site.id, d // 1), CYAN)
  elseif p.site ~= 0 then
    v:text(W // 2 - 40, 6, "IN DERELICT " .. p.site, AMBER)
  end
  -- tractor
  if target then
    local ok = target.item.size <= c.tractor_class
    local t = string.format("%s [%s]", target.item.name, loot.size_name(target.item.size))
    v:text(W // 2 - #t * 4, H // 2 + 10, t, ok and GREEN or RED)
    if not ok then v:text(W // 2 - 60, H // 2 + 20, "needs a bigger saucer", RED) end
  end
  if p.tractor then
    local f = 1 - p.tractor.left / 0.5
    v:rect(W // 2 - 20, H // 2 + 30, 40 * f, 3, AMBER)
  end
  -- mystery
  local m = state.mystery
  if m.mode == "off" then
    v:text(W - 72, 6, "SANDBOX", DIM)
  else
    local t = string.format("%s %d/%d", m.title:upper(), m.found, #m.echoes)
    v:text(W - 4 - #t * 8, 6, t, m.solved and GREEN or AMBER)
  end
  -- messages
  local y = H - 12
  for i = #p.msgs, 1, -1 do
    local msg = p.msgs[i]
    if state.tick - msg.tick < M.MSG_TICKS then
      v:text(6, y, msg.text:sub(1, (W - 12) // 8), WHITE)
      y = y - 10
    end
  end
  if p.help then
    v:rect(W // 2 - 170, 50, 340, 12 * #HELP + 8, { 0, 0, 0.05, 0.8 })
    for i, line in ipairs(HELP) do v:text(W // 2 - 164, 46 + i * 12, line, i == 1 and AMBER or WHITE) end
  end
  local mode = saucer.input.device_mode(v.player)
  if mode == "touch" then M.touch(v) end
  if state.tick < 600 then
    local h = HINTS[mode] or HINTS.kbm
    v:text(6, H - 24 - 10 * #p.msgs, h:sub(1, (W - 12) // 8), DIM)
  end
end

function M.touch(v)
  local W, H = v.width, v.height
  for _, w in ipairs(saucer.input.touch_layout()) do
    if w.name ~= "look" then
      local a = w.active and 0.55 or 0.25
      v:rect(w.x * W, w.y * H, w.w * W, w.h * H, { 0.4, 0.8, 1, a })
      v:text(w.x * W + 2, w.y * H + 2, w.name:upper():sub(1, 6), WHITE)
    end
  end
end

return M
