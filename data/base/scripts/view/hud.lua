-- SPDX-License-Identifier: MIT
-- 2D HUD in low-res viewport pixels (8x8 font).
local configs = require("sim.config")
local loot = require("sim.loot")
local vec = require("lib.vec")
local avatar = require("sim.avatar")
local panel = require("sim.panel")
local fold = require("sim.fold")
local M = {}

local WHITE, DIM, GREEN, RED, AMBER, CYAN = { 1, 1, 1, 1 }, { 0.6, 0.65, 0.75, 1 }, { 0.4, 1, 0.5, 1 },
  { 1, 0.35, 0.3, 1 }, { 1, 0.8, 0.3, 1 }, { 0.4, 0.9, 1, 1 }
M.MSG_TICKS = 300

local HINTS = {
  kbm = "WASD walk/fly MOUSE look G use/helm Q/E fold F beam H help",
  pad = "LS move RS look X use LB/RB fold A beam LT/RT lift BACK cam",
  touch = "Stick move  drag look  USE helm  buttons fold/tractor",
  xr = "Stick walk/fly  L trigger use  lever fold  R trigger beam",
}
M.HINTS = HINTS

local HELP = {
  "SAUCER - controls",
  "Walk or fly: W A S D, look: mouse (click to capture)",
  "Use G/Enter: take the helm, or stand up from it",
  "At the helm: lift Space/Ctrl, boost Shift",
  "Fold Q (to the Seat) / unfold E, or 1-2",
  "Tractor F or left click (helm or under the dome)",
  "Camera C, mystery mode M, help H/F1",
  "Gamepad, touch and WebXR work too.",
}
M.HELP = HELP

function M.ladder(v, p, x, y)
  local ship = p.ship
  for i, c in ipairs(configs.all()) do
    local col = DIM
    if i == ship.size then col = ship.morph and AMBER or GREEN end
    v:rect(x + (i - 1) * 12, y, 10, 10, { col[1] * 0.3, col[2] * 0.3, col[3] * 0.3, 0.8 })
    v:text(x + 1 + (i - 1) * 12, y + 1, c.name:sub(1, 1), col)
  end
end

-- where the player is and what Use would do right now
function M.status(p)
  local L = avatar.layout()
  if p.mode == "wake" then return "BEDROOM", nil end
  if p.mode == "walk" then
    local room = avatar.room(L, p.body):upper()
    if avatar.near_helm(L, p.body) then return room, "USE: TAKE THE HELM" end
    local st = avatar.station(L, p.body)
    if st then return room, st.label end
    return room, nil
  end
  if configs.get(p.ship.size).interior then return "AT THE HELM", "USE: STAND UP" end
  return "SEAT", "E: UNFOLD THE VILLA"
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

-- the open menu (title, bed, lab, trade): a box with a highlighted row
function M.panel(v, state, p)
  if not p.panel then return 0 end
  local W, H = v.width, v.height
  local rows = panel.rows(state, p)
  local title = panel.title(state, p)
  local w = 8
  for _, r in ipairs(rows) do w = math.max(w, #r.text + 4) end
  w = math.min(math.max(w, #title + 4) * 8, W - 16)
  local x, y = W // 2 - w // 2, H // 2 - (#rows * 11 + 24) // 2
  local is_title = p.panel.kind == "title"
  if is_title then
    v:text(W // 2 - 6 * 8 * 3 // 2, y - 46, "SAUCER", AMBER, 3)
    v:text(W // 2 - 13 * 8 // 2, y - 18, "a cozy salvage", DIM)
  end
  local top = is_title and 0 or 12
  v:rect(x - 4, y - 4, w + 8, #rows * 11 + top + 12, { 0, 0.02, 0.06, 0.82 })
  if not is_title then v:text(x, y, title, AMBER) end
  for i, r in ipairs(rows) do
    local sel = i == p.panel.sel
    local col = r.enabled == false and DIM or (sel and GREEN or WHITE)
    if sel then v:rect(x - 2, y + top + (i - 1) * 11 - 1, w + 4, 10, { 0.2, 0.5, 0.3, 0.5 }) end
    v:text(x, y + top + (i - 1) * 11, (sel and "> " or "  ") .. r.text, col)
  end
  local mode = saucer.input.device_mode(v.player)
  local nav = mode == "pad" and "STICK UP/DOWN  X: PICK" or (mode == "touch" and "STICK UP/DOWN  USE: PICK" or
    "W/S: CHOOSE  G/ENTER: PICK")
  v:text(W // 2 - #nav * 4, y + top + 10 + #rows * 11, nav, DIM)
  return #rows
end

-- what the fold is doing right now, for the HUD (nil when idle)
function M.fold_status(p)
  local ship = p.ship
  if not ship.morph then return nil end
  local amounts, order = fold.amounts(ship)
  if not order then return nil end
  local packed, out, total, busy = 0, 0, #order, nil
  for _, g in ipairs(order) do
    local a = amounts[g.id]
    if a >= 1 then packed = packed + 1 elseif a > 0 and not busy then busy = g.name end
    if a <= 0 then out = out + 1 end
  end
  local growing = ship.size < ship.morph.from
  if growing then
    return string.format("UNFOLDING %d/%d ROOMS%s", out, total, busy and (": " .. busy:upper()) or "")
  end
  return string.format("FOLDING %d/%d ROOMS%s", packed, total, busy and (": " .. busy:upper()) or "")
end

function M.draw(v, state, p, target)
  local W, H = v.width, v.height
  local ship = p.ship
  local c = configs.get(ship.size)
  if p.mode == "wake" then
    -- waking up: just the title card over the bedroom (and the touch buttons)
    M.panel(v, state, p)
    if saucer.input.device_mode(v.player) == "touch" then M.touch(v) end
    return
  end
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
  -- crosshair, where you are and what Use does
  v:text(W // 2 - 4, H // 2 - 4, "+", p.tractor and AMBER or WHITE)
  local where, hint = M.status(p)
  v:text(8, 46, where, CYAN)
  if hint then v:text(W // 2 - #hint * 4, H // 2 + 40, hint, AMBER) end
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
  local fs = M.fold_status(p)
  if fs then v:text(W // 2 - #fs * 4, H // 2 - 30, fs, CYAN) end
  if p.slept_tick and state.tick - p.slept_tick < 120 then
    v:rect(0, 0, W, H, { 0, 0, 0.02, 1 - (state.tick - p.slept_tick) / 120 })
  end
  M.panel(v, state, p)
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
