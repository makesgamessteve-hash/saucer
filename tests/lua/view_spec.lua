-- SPDX-License-Identifier: MIT
-- View code against a recording fake viewport (render must not mutate state).
local game = require("sim.game")
local render = require("view.render")
local hud = require("view.hud")
local assets = require("view.assets")
local tractor = require("sim.tractor")
local shipm = require("sim.ship")

local function fake_view(opts)
  local v = { calls = {}, width = 480, height = 270, player = 1, index = 1, xr = false }
  for k, x in pairs(opts or {}) do v[k] = x end
  for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "text", "image" }) do
    v[m] = function(self, ...)
      self.calls[m] = (self.calls[m] or 0) + 1
      if m == "text" then
        local s = select(3, ...)
        self.texts = (self.texts or "") .. s .. "|"
        return #s * 8
      end
    end
  end
  return v
end

local function new_state(n, raw)
  local st = {}
  game.init(st, { seed = 42, players = n or 1 })
  if not raw then
    local avatar = require("sim.avatar")
    for _, p in ipairs(st.players) do
      p.mode, p.panel = "walk", false
      p.body = avatar.new(avatar.layout(), { -2.0, 0.6, -1.0 }, 0)
    end
  end
  return st
end

describe("render", function()
  it("draws sky, derelicts, saucers and the HUD", function()
    local st = new_state(2)
    local v = fake_view()
    local before = require("lib.meshkit").copy(st)
    render.render(v, saucer.util.readonly(st), 1)
    expect(v.calls.camera).to_be(1)
    expect(v.calls.mesh).to_be_greater(4)
    expect(v.texts).to_contain("VILLA")
    expect(st).to_equal(before)
  end)
  it("skips missing players and the HUD in XR", function()
    local st = new_state()
    local v = fake_view({ player = 3 })
    render.render(v, st, 1)
    expect(v.calls.camera).to_be(nil)
    local x = fake_view({ xr = true })
    render.render(x, st, 1)
    expect(x.calls.text).to_be(nil)
  end)
  it("looks through the player's eyes; chase sits behind and above", function()
    local st = new_state()
    local p = st.players[1]
    local eye = game.viewpoint(p)
    local c0 = render.camera(p, false)
    expect(c0.pos).to_equal(eye)
    expect(c0.pos[2]).to_be_greater(p.ship.pos[2]) -- standing on the dome deck
    p.cam = "chase"
    local c = render.camera(p, false)
    expect(c.pos[3]).to_be_less(p.ship.pos[3])
    expect(c.pos[2]).to_be_greater(p.ship.pos[2])
    expect(render.camera(p, true).pos).to_equal(eye)
    p.mode = "helm"
    expect(render.camera(p, true).pos[3]).to_be_greater(p.ship.pos[3] + 7)
  end)
  it("folds the saucer around the pilot during size changes", function()
    local s = shipm.new({ 0, 0, 0 }, 0, 1)
    expect(render.pose(s).scale).to_be(1)
    expect(render.morph_scale(s)).to_be(1)
    shipm.request(s, 2, function() return false end)
    s.t_left = s.morph.total * 0.8 -- 20% in: still the Villa at full size, rooms packing
    local a = render.pose(s)
    expect(a.size).to_be(1)
    expect(a.scale).to_be(1)
    s.t_left = s.morph.total * 0.4 -- 60% in: rooms gone, the hull shrinks about the eye
    local a2 = render.pose(s)
    expect(a2.size).to_be(1)
    expect(a2.scale).to_be_less(1)
    expect(a2.iscale).to_be_less(a2.scale)
    s.t_left = s.morph.total * 0.1 -- 90% in: the Seat, rooms gone
    local b = render.pose(s)
    expect(b.size).to_be(2)
    expect(b.iscale).to_be(0)
    shipm.update(s, 10, false)
    shipm.request(s, 1, function() return false end)
    s.t_left = s.morph.total * 0.8 -- growing, 20% in: the hull grows first (the Seat swells)
    local g = render.pose(s)
    expect(g.size).to_be(2)
    expect(g.scale).to_be_greater(1)
    s.t_left = s.morph.total * 0.25 -- 75% in: full-size Villa, rooms unpacking
    local g2 = render.pose(s)
    expect(g2.size).to_be(1)
    expect(g2.scale).to_be(1)
    expect(render.hull_t(s, 0.75)).to_be(1)
  end)
  it("plays each sound cue once", function()
    local st = new_state()
    local p = st.players[1]
    st.tick = 10
    p.fx = { { tick = 10, sound = "pickup" }, { tick = 10, sound = "nope" } }
    render.audio(st, p)
    st.tick = 11
    render.audio(st, p)
    st.tick = 2 -- after a restore to an earlier tick
    p.fx = { { tick = 2, sound = "grow" } }
    render.audio(st, p)
  end)
  it("shows loot, echoes, tractor beam, ghost hull and messages inside a derelict", function()
    local st = new_state(2)
    local p = st.players[1]
    local r = game.ruin(1)
    local c = tractor.candidates(st, p, 1, r)[1]
    p.site = 1
    p.ship.size = 2
    p.mode = "helm"
    p.ship.pos = { c.pos[1], c.pos[2] + 0.2, c.pos[3] - 2 }
    p.tractor = { key = c.key, site = 1, left = 0.25 }
    p.ghost, p.ghost_size = 10, 1
    p.help = true
    p.cam = "chase"
    st.mystery.mode = "off"
    st.players[2].ship.pos = { p.ship.pos[1] + 40, p.ship.pos[2], p.ship.pos[3] }
    local v = fake_view()
    render.render(v, st, 1)
    expect(v.calls.billboard).to_be_greater(3)
    expect(v.texts).to_contain("IN DERELICT 1")
    expect(v.texts).to_contain("SANDBOX")
    expect(v.texts).to_contain("controls")
    expect(v.texts).to_contain("SEAT")
    -- mid-fold: both the hull and the folding rooms are drawn
    p.ship.size, p.mode = 1, "helm"
    shipm.request(p.ship, 2, function() return false end)
    p.ship.t_left = p.ship.morph.total * 0.9
    local v2 = fake_view()
    render.render(v2, st, 1)
    expect(v2.calls.mesh).to_be_greater(6)
  end)
end)

describe("hud", function()
  it("bearing points toward targets", function()
    local p = { ship = { pos = { 0, 0, 0 }, yaw = 0 } }
    expect(hud.bearing(p, { 0, 0, 10 })).to_be("^")
    expect(hud.bearing(p, { 10, 0, 0 })).to_be("<")
    expect(hud.bearing(p, { -10, 0, 0 })).to_be(">")
  end)
  it("nav only outside sites", function()
    local st = new_state()
    local p = st.players[1]
    expect(hud.nav(st, p).id).to_be(1)
    p.site = 1
    expect(hud.nav(st, p)).to_be(nil)
  end)
  it("says where you are and what Use does", function()
    local st = new_state()
    local p = st.players[1]
    local L = require("sim.avatar").layout()
    local where, hint = hud.status(p)
    expect(where).to_be("DOME DECK")
    expect(hint).to_be(nil)
    p.body.pos = { L.helm.stand[1], L.helm.stand[2], L.helm.stand[3] }
    where, hint = hud.status(p)
    expect(where).to_be("HELM")
    expect(hint).to_contain("TAKE THE HELM")
    p.mode = "helm"
    expect(select(2, hud.status(p))).to_contain("STAND UP")
    p.ship.size = 2
    expect(hud.status(p)).to_be("SEAT")
  end)
  it("marks too-big targets and draws touch widgets", function()
    local st = new_state()
    local p = st.players[1]
    p.ship.size = 2
    p.ship.charge = 10
    p.hold = { { hot = true, value = 1 } }
    st.mystery.solved = true
    local v = fake_view()
    hud.draw(v, st, p, { item = { name = "Idol", size = 3 } })
    expect(v.texts).to_contain("needs a bigger saucer")
    hud.touch(v)
    expect(v.calls.rect).to_be_greater(5)
    st.tick = 10000
    p.msgs = { { tick = 1, text = "old" } }
    local v2 = fake_view()
    hud.draw(v2, st, p, nil)
    expect((v2.texts or ""):find("old", 1, true)).to_be(nil)
  end)
end)

describe("assets", function()
  it("builds once and caches derelict meshes", function()
    local A = assets.init()
    expect(assets.init()).to_be(A)
    local st = new_state()
    local m1 = assets.ruin_mesh(game.ruin(1), st.sector.sites[1].pos)
    expect(assets.ruin_mesh(game.ruin(1), st.sector.sites[1].pos)).to_be(m1)
    expect(A.tex.hull).to_be_greater(1)
  end)
end)
