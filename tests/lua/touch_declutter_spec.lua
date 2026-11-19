-- SPDX-License-Identifier: MIT
-- declutter-touch-controls: fewer buttons on a touch screen. Use and Boost
-- (with the stick and the lift) always show; the beam, the grapple, the
-- jammer and decoy, and the size buttons show only in context, in fixed
-- slots, never under a pressing finger; everything is in the tray.
local game = require("sim.game")
local hud = require("view.hud")
local avatar = require("sim.avatar")

local SIZES = { { 320, 568 }, { 568, 320 }, { 360, 640 }, { 640, 360 }, { 390, 844 }, { 844, 390 },
                { 768, 1024 }, { 1024, 768 } }
local ACTIONS = { "shrink", "grow", "tractor", "scan", "use", "boost", "jam", "map", "decoy", "grapple" }
local ALL = {}
for _, n in ipairs(ACTIONS) do ALL[n] = true end

local function reset()
  saucer.input.touch_tray(false)
  saucer.input.touch_context(ALL)
  saucer.test.touch_metrics({ w = 640, h = 360 })
end

local function slot(name, group)
  for _, w in ipairs(saucer.input.touch_layout()) do
    if w.name == name and (w.group == "tray") == (group == "tray") then return w end
  end
end

local function fresh()
  local st = {}
  game.init(st, { seed = 42, players = 1 })
  local p = st.players[1]
  p.panel = false
  p.mode = "helm"
  st.tick = 100
  return st, p
end

local function overlap(a, b)
  local e = 1e-5
  return a.x + e < b.x + b.w and b.x + e < a.x + a.w and a.y + e < b.y + b.h and b.y + e < a.y + a.h
end

local function inside(a, b)
  local e = 1e-4
  return a.x >= b.x - e and a.y >= b.y - e and a.x + a.w <= b.x + b.w + e and a.y + a.h <= b.y + b.h + e
end

describe("touch context buttons", function()
  it("shows the beam only when loot is lined up, at the console or while it pulls", function()
    local st, p = fresh()
    expect(hud.touch_context(st, p, nil).tractor).to_be(nil)
    expect(hud.touch_context(st, p, { status = "near" }).tractor).to_be(nil)
    expect(hud.touch_context(st, p, { status = "lock" }).tractor).to_be(true)
    p.mode = "walk"
    expect(hud.touch_context(st, p, { status = "lock" }).tractor).to_be(nil)
    p.beam_console = true
    expect(hud.touch_context(st, p, nil).tractor).to_be(true)
    p.beam_console, p.mode, p.tractor = false, "helm", { t = 0 }
    expect(hud.touch_context(st, p, nil).tractor).to_be(true)
  end)
  it("shows the grapple only on foot in a derelict", function()
    local st, p = fresh()
    expect(hud.touch_context(st, p).grapple).to_be(nil)
    p.mode, p.excursion = "foot", { body = {} }
    expect(hud.touch_context(st, p).grapple).to_be(true)
    p.excursion, p.station = nil, {}
    expect(hud.touch_context(st, p).grapple).to_be(nil)
  end)
  it("shows the jammer and a decoy only when a sentry is on you", function()
    local st, p = fresh()
    p.site, p.decoys = 1, 2
    expect(hud.touch_context(st, p).jam).to_be(nil)
    st.sentries = { [1] = { { target = p.index, st = "alert" } } }
    local w = hud.touch_context(st, p)
    expect(w.jam).to_be(true)
    expect(w.decoy).to_be(true)
    p.decoys = 0
    expect(hud.touch_context(st, p).decoy).to_be(nil)
    st.sentries = nil
    p.clamped_by = 3 -- a Clamp: Jam shakes it off
    expect(hud.touch_context(st, p).jam).to_be(true)
  end)
  it("shows a size button only where the size change would go through", function()
    local st, p = fresh()
    local w = hud.touch_context(st, p)
    expect(w.shrink).to_be(game.can_resize(st, p, p.ship.size + 1) or nil)
    expect(w.grow).to_be(game.can_resize(st, p, p.ship.size - 1) or nil)
    expect(w.shrink or w.grow).to_be(true) -- open space: there is room one way at least
    p.ship.charge = 0
    st.tick = st.tick + 10
    w = hud.touch_context(st, p)
    expect(w.shrink == nil and w.grow == nil).to_be(true) -- no Charge
    expect(game.can_resize(st, p, 99)).to_be(false)
    p.ship.charge = 100
    p.clamped_by = 1
    expect(hud.touch_context(st, p).shrink).to_be(nil)
    expect(game.can_resize(st, p, p.ship.size + 1)).to_be(false)
    p.clamped_by = nil
    p.tv = true
    expect(hud.touch_context(st, p).shrink).to_be(nil)
  end)
  it("asks for nothing while a menu is open, and the HUD hands the context to the engine", function()
    local st, p = fresh()
    p.panel = { kind = "map", sel = 1 }
    expect(next(hud.touch_context(st, p, { status = "lock" }))).to_be(nil)
    expect(next(hud.touch_context(nil, nil))).to_be(nil)
    p.panel = false
    local dm, beam = saucer.input.device_mode, hud.beam
    saucer.input.device_mode = function() return "touch" end
    hud.beam = function() end -- (the scope itself is not under test)
    local ok, err = pcall(function()
      local v = { width = 480, height = 270, player = 1, index = 1 }
      for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "image", "vignette", "rect", "text" }) do
        v[m] = function() return 0 end
      end
      hud.draw(v, saucer.util.readonly(st), p, nil)
      expect(slot("tractor").shown).to_be(false) -- nothing lined up
      expect(slot("use").shown).to_be(true)
      expect(slot("boost").shown).to_be(true)
      hud.draw(v, saucer.util.readonly(st), p, { status = "lock" })
      expect(slot("tractor").shown).to_be(true)
    end)
    saucer.input.device_mode, hud.beam = dm, beam
    reset()
    if not ok then error(err, 0) end
  end)
end)

describe("touch context timing", function()
  it("never shows a button under a finger that is pressing, and fades it in", function()
    reset()
    saucer.input.touch_context({})
    local b = slot("tractor")
    expect(b.shown).to_be(false)
    local x, y = b.x + b.w / 2, b.y + b.h / 2
    saucer.test.touch("down", 71, x, y) -- looking around, right where the beam would go
    saucer.input.touch_context({ tractor = true })
    b = slot("tractor")
    expect(b.wanted).to_be(true)
    expect(b.shown).to_be(false)
    saucer.test.touch("frame", 5)
    expect(slot("tractor").shown).to_be(false) -- still deferred
    saucer.test.touch("move", 71, 0.5, 0.15) -- off the slot
    saucer.test.touch("frame")
    b = slot("tractor")
    expect(b.shown).to_be(true)
    expect(b.age).to_be(0)
    saucer.test.touch("up", 71)
    -- drawn faint with a pulse, then solid
    local rects = {}
    local v = { width = 480, height = 270 }
    function v:rect(_, _, _, _, c) rects[#rects + 1] = c end
    function v:text() return 0 end
    hud.touch(v)
    local faint, pulse = false, false
    for _, c in ipairs(rects) do
      if c[4] and c[4] < 0.2 and c[1] == 0 then faint = true end
      if c[1] == 1 and c[2] == 1 and c[3] == 1 and c[4] > 0.5 then pulse = true end
    end
    expect(faint and pulse).to_be(true)
    saucer.test.touch("frame", hud.PULSE_FRAMES)
    expect(slot("tractor").age >= hud.PULSE_FRAMES).to_be(true)
    -- a held button whose context goes stays until the finger lifts
    b = slot("tractor")
    saucer.test.touch("down", 72, b.x + b.w / 2, b.y + b.h / 2)
    saucer.input.touch_context({})
    expect(slot("tractor").shown).to_be(true)
    expect(slot("tractor").held).to_be(true)
    saucer.test.touch("up", 72)
    expect(slot("tractor").shown).to_be(false)
    -- the slot itself never moves
    local b2 = slot("tractor")
    expect(b2.x == b.x and b2.y == b.y).to_be(true)
    reset()
  end)
end)

describe("touch tray", function()
  it("holds every action, opens from its button and closes after a pick", function()
    reset()
    local more = slot("more")
    expect(more.kind).to_be(5)
    expect(more.group).to_be("core")
    saucer.test.touch("down", 81, more.x + more.w / 2, more.y + more.h / 2)
    saucer.test.touch("up", 81)
    local lay = saucer.input.touch_layout()
    expect(lay.tray_open).to_be(true)
    for _, n in ipairs(ACTIONS) do
      local t = slot(n, "tray")
      expect(t ~= nil and t.shown).to_be(true)
      expect(inside(t, lay.tray)).to_be(true)
    end
    expect(slot("tractor").shown).to_be(false) -- the context slots make way
    expect(slot("use").shown).to_be(true)       -- Use and Boost stay
    -- the tray's open state shows on its button ("X")
    local texts = {}
    local v = { width = 480, height = 270 }
    function v:rect() end
    function v:text(_, _, t) texts[t] = true return 0 end
    hud.touch(v)
    expect(texts.X).to_be(true)
    expect(texts.MAP).to_be(true)
    local m = slot("map", "tray")
    saucer.test.touch("down", 82, m.x + m.w / 2, m.y + m.h / 2)
    expect(slot("map", "tray").value).to_be(1)
    saucer.test.touch("up", 82)
    expect(saucer.input.touch_layout().tray_open).to_be(false)
    reset()
  end)
  for _, sz in ipairs(SIZES) do
    it(string.format("fits the slots and the open tray in the safe area at %dx%d", sz[1], sz[2]), function()
      saucer.test.touch_metrics({ w = sz[1], h = sz[2], safe = { 0, 0, 0, 16 } })
      for _, open in ipairs({ false, true }) do
        saucer.input.touch_context(ALL)
        saucer.input.touch_tray(open)
        local lay = saucer.input.touch_layout()
        expect(lay.tray_open).to_be(open)
        local shown = {}
        for _, w in ipairs(lay) do
          if w.shown and w.kind ~= 3 then
            local r = w.kind == 1 and lay.home or w
            expect(inside(r, lay.safe)).to_be(true)
            expect(r.w * sz[1] >= 47.99 and r.h * sz[2] >= 47.99).to_be(true)
            for _, q in ipairs(shown) do
              if overlap(r, q) then error(string.format("%s over %s", w.name, q.name)) end
            end
            shown[#shown + 1] = { x = r.x, y = r.y, w = r.w, h = r.h, name = w.name }
          end
        end
        if open then
          local t = lay.tray
          expect(t.x >= 0 and t.y >= 0 and t.x + t.w <= 1 and t.y + t.h <= 1).to_be(true)
          expect(inside(t, lay.safe)).to_be(true)
          expect(not overlap(t, lay.home)).to_be(true)
          expect(#shown).to_be(4 + 2 + 1 + #ACTIONS) -- stick, lift x3, Use, Boost, the tray button, the tray
        else
          expect(#shown).to_be(4 + 8 + 1) -- every grid slot in context
        end
      end
      reset()
    end)
  end
end)
