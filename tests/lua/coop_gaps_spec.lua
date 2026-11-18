-- SPDX-License-Identifier: MIT
-- Co-op gaps (OpenSpec add-multiplayer-foundation 1.4 anti-blocking fold-phase, 1.6 shared-object claims,
-- and the twin-hold timeout that frees a follower waiting in vain).
local game = require("sim.game")
local claims = require("sim.claims")
local twin = require("sim.twin")
local tractor = require("sim.tractor")
local ap = require("sim.autopilot")
local vec = require("lib.vec")

local function cmd(t) return saucer.input.command(t or {}) end
local function new_state(n)
  local st = {}
  game.init(st, { seed = 42, players = n or 2 })
  for _, p in ipairs(st.players) do p.mode, p.panel = "helm", false end
  return st
end
local function step(st, n, c1)
  for _ = 1, n or 1 do
    local f = {}
    for i = 1, #st.players do f[i] = (i == 1 and c1) or cmd() end
    game.step(st, f, 1 / 60)
  end
end
local function heard(p, s)
  for _, m in ipairs(p.msgs) do if m.text:find(s, 1, true) then return true end end
  return false
end
local function ctx_of()
  return { msg = game.msg, fx = function(st, p, snd) p.fx[#p.fx + 1] = { tick = st.tick, sound = snd } end }
end
local function twin_site(st)
  for i = 1, #st.sector.sites do
    if twin.layout(game.ruin(i)) then return i, twin.layout(game.ruin(i)) end
  end
end

describe("anti-blocking fold-phase (multiplayer 1.4)", function()
  it("a friend parked in a duct: pushed for 2 s, then phased for 3 s, then solid again", function()
    local st = new_state(2)
    local a, b = st.players[1], st.players[2]
    b.ship.pos = { a.ship.pos[1], a.ship.pos[2], a.ship.pos[3] + 30 }
    local push = { axes = { move_z = 1 } }
    local solid_for = 0
    while not game.phased(st, a, b) and solid_for < 400 do
      step(st, 1, cmd(push))
      solid_for = solid_for + 1
      if not game.phased(st, a, b) then expect(a.ship.pos[3] < b.ship.pos[3]).to_be(true) end -- never through while solid
    end
    expect(solid_for).to_be_greater(2 * 60 - 1) -- at least the push time
    expect(st.phase).to_be_truthy()
    local blocked_at = a.ship.pos[3]
    step(st, 150, cmd(push))
    expect(heard(a, "pushing P2")).to_be(true)
    expect(heard(b, "P1 is stuck against you")).to_be(true)
    local e = st.phase["1:2"]
    expect(e.untl).to_be_greater(0)
    expect(a.ship.pos[3]).to_be_greater(blocked_at)
    -- the phase runs out after PHASE_SECONDS
    expect(game.phased(st, b, a)).to_be(st.tick < e.untl)
    st.tick = e.untl
    expect(game.phased(st, a, b)).to_be(false)
    expect(game.blocked(st, a, b.ship.pos, 1, 1, 0)).to_be(true)
  end)
  it("an overlapping spawn passes: nobody is pinned by a saucer they already share space with", function()
    local st = new_state(2)
    local a, b = st.players[1], st.players[2]
    b.ship.pos = vec.copy(a.ship.pos)
    local z0 = a.ship.pos[3]
    step(st, 90, cmd({ axes = { move_z = 1 } }))
    expect(math.abs(a.ship.pos[3] - z0)).to_be_greater(2)
    expect(st.phase).to_be(nil) -- nobody bumped: nothing was written
  end)
  it("a morphing saucer is not a wall", function()
    local st = new_state(2)
    local a, b = st.players[1], st.players[2]
    b.ship.pos = vec.copy(a.ship.pos)
    expect(game.blocked(st, a, b.ship.pos, 1, 1, 0)).to_be(true)
    b.ship.morph = { t = 0 }
    expect(game.phased(st, a, b)).to_be(true)
    expect(game.blocked(st, a, b.ship.pos, 1, 1, 0)).to_be(false)
  end)
  it("saucers phase through each other once the party has agreed to fold", function()
    local st = new_state(2)
    local a, b = st.players[1], st.players[2]
    b.ship.pos = vec.copy(a.ship.pos)
    st.jump = { to = 2, by = 1, yes = { ["1"] = true }, spool = -1 }
    expect(game.phased(st, a, b)).to_be(false) -- still waiting for P2's yes
    st.jump.yes["2"] = true
    expect(game.phased(st, a, b)).to_be(true)
    expect(game.blocked(st, a, b.ship.pos, 1, 1, 0)).to_be(false)
    expect(game.blocked(st, nil, b.ship.pos, 1, 1, 0)).to_be(true) -- (no self: the world's view stays solid)
  end)
  it("growing next to a friend is still refused", function()
    local st = new_state(2)
    local a, b = st.players[1], st.players[2]
    b.ship.pos = { a.ship.pos[1] + 3, a.ship.pos[2], a.ship.pos[3] }
    expect(game.blocked(st, a, b.ship.pos, 4, 2, 0.3)).to_be(true)
    a.ship.size, a.ship.charge, a.ship.pos = 2, 100, vec.copy(a.ship.pos)
    step(st, 1, cmd({ pressed = { "size1" } }))
    expect(game.phased(st, a, b)).to_be(false)
  end)
end)

describe("shared-object claims (multiplayer 1.6)", function()
  local function pull(p, c, site, kind)
    p.tractor = { key = c.key, site = site, t = 0.999, total = 1, from = vec.copy(c.pos), size = 1, kind = kind or c.kind }
  end
  it("only shared kinds are claimed", function()
    for _, k in ipairs({ "echo", "curio", "gift", "twin", "anchor" }) do expect(claims.is_shared(k)).to_be(true) end
    for _, k in ipairs({ "slot", "cache", "nest", "find" }) do expect(claims.is_shared(k)).to_be(false) end
  end)
  it("the tie rule: lowest (record index + tick) mod n wins, across ticks and player counts", function()
    local st = new_state(3)
    local ps = st.players
    -- n = 3: tick 99 -> P1 (0), P2 (1), P3 (2): P1 wins; tick 100 -> P3 wins (0+100)%3=1, (1+100)%3=2, (2+100)%3=0
    expect(claims.winner(ps, 99, 3)).to_be(ps[1])
    expect(claims.winner(ps, 100, 3)).to_be(ps[3])
    expect(claims.winner(ps, 101, 3)).to_be(ps[2])
    -- n = 2, tick 101: P1 -> 1, P2 -> 0: P2 wins
    local two = { ps[1], ps[2] }
    expect(claims.winner(two, 101, 2)).to_be(ps[2])
    expect(claims.winner(two, 100, 2)).to_be(ps[1])
    -- only the contesting players count
    expect(claims.winner({ ps[1], ps[3] }, 100, 3)).to_be(ps[3])
    expect(claims.winner({ ps[3], ps[1] }, 100, 3)).to_be(ps[3])
  end)
  it("two beams finishing on the same echo the same tick: one takes it, the other is told, the claim is recorded", function()
    local st = new_state(2)
    local a, b = st.players[1], st.players[2]
    local c = { key = "echo:7", pos = { 0, 0, 0 }, kind = "echo" }
    st.tick = 101
    pull(a, c, 3)
    pull(b, c, 3)
    claims.resolve(st, 1 / 60, ctx_of())
    expect(a.tractor).to_be(false) -- P2 wins at tick 101 with two players
    expect(b.tractor).to_be_truthy()
    expect(heard(a, "P2 got there first")).to_be(true)
    expect(heard(b, "You claimed it")).to_be(true)
    expect(st.claims["3|echo:7"].by).to_be(2)
    expect(st.claims["3|echo:7"].tick).to_be(101)
    expect(claims.claimed_by(st, 3, "echo:7")).to_be(2)
    expect(claims.claimed_by(st, 3, "echo:8")).to_be(nil)
    -- at tick 100 it is the other way round
    local st2 = new_state(2)
    st2.tick = 100
    pull(st2.players[1], c, 3)
    pull(st2.players[2], c, 3)
    claims.resolve(st2, 1 / 60, ctx_of())
    expect(st2.players[2].tractor).to_be(false)
    expect(st2.players[1].tractor).to_be_truthy()
  end)
  it("different objects, per-player loot, beams still pulling and a lone player are not contests", function()
    local st = new_state(2)
    local a, b = st.players[1], st.players[2]
    pull(a, { key = "echo:1", pos = { 0, 0, 0 }, kind = "echo" }, 3)
    pull(b, { key = "echo:2", pos = { 0, 0, 0 }, kind = "echo" }, 3)
    claims.resolve(st, 1 / 60, ctx_of())
    expect(a.tractor).to_be_truthy()
    expect(b.tractor).to_be_truthy()
    pull(a, { key = "slot:1:4", pos = { 0, 0, 0 }, kind = "slot" }, 3)
    pull(b, { key = "slot:1:4", pos = { 0, 0, 0 }, kind = "slot" }, 3)
    claims.resolve(st, 1 / 60, ctx_of())
    expect(a.tractor).to_be_truthy()
    expect(b.tractor).to_be_truthy()
    a.tractor.t, b.tractor.t = 0, 0 -- not finishing yet
    a.tractor.key, b.tractor.key, a.tractor.kind, b.tractor.kind = "echo:1", "echo:1", "echo", "echo"
    claims.resolve(st, 1 / 60, ctx_of())
    expect(a.tractor).to_be_truthy()
    expect(st.claims).to_be(nil)
    local solo = new_state(1)
    pull(solo.players[1], { key = "echo:1", pos = { 0, 0, 0 }, kind = "echo" }, 3)
    claims.resolve(solo, 1 / 60, ctx_of())
    expect(solo.players[1].tractor).to_be_truthy()
  end)
  it("on a real tick two Villas over the same twin anchor: exactly one of them latches it", function()
    local st = new_state(2)
    local a, b = st.players[1], st.players[2]
    local site = twin_site(st)
    local c
    for _, x in ipairs(tractor.candidates(st, a, site, game.ruin(site))) do if x.kind == "anchor" then c = x end end
    expect(c).to_be_truthy()
    for _, p in ipairs({ a, b }) do
      p.ship.size, p.ship.morph, p.site = 1, false, site
      p.ship.pos = ap.beam_spot(c.pos, 1)
      p.ship.yaw = ap.beam_yaw(c, 0)
      p.ship.bank, p.ship.pitch, p.ship.vel = 0, 0, { 0, 0, 0 }
      pull(p, c, site)
    end
    local tick = st.tick
    local win = claims.winner({ a, b }, tick + 1, 2) -- (the tick counter moves on before the claims are settled)
    local lose = win == a and b or a
    step(st, 1)
    expect(st.twins[twin.key(site)].by).to_be(win.index)
    expect(lose.tractor).to_be(false)
    expect(heard(lose, "got there first")).to_be(true)
    expect(st.claims[site .. "|anchor:" .. site].by).to_be(win.index)
  end)
  it("a pull that finishes on something the other player already claimed is refused", function()
    local st = new_state(2)
    local a = st.players[1]
    local site = twin_site(st)
    local c
    for _, x in ipairs(tractor.candidates(st, a, site, game.ruin(site))) do if x.kind == "anchor" then c = x end end
    a.ship.size, a.ship.morph, a.site = 1, false, site
    a.ship.pos = ap.beam_spot(c.pos, 1)
    a.ship.yaw = ap.beam_yaw(c, 0)
    a.ship.bank, a.ship.pitch, a.ship.vel = 0, 0, { 0, 0, 0 }
    pull(a, c, site)
    st.claims = { [site .. "|" .. c.key] = { by = 2, tick = 1 } }
    step(st, 1)
    expect(heard(a, "P2 already claimed that")).to_be(true)
    expect(st.twins).to_be(nil)
    -- a claim of your own does not stop you
    local st2 = new_state(2)
    local a2 = st2.players[1]
    a2.ship.size, a2.ship.morph, a2.site = 1, false, site
    a2.ship.pos, a2.ship.yaw = ap.beam_spot(c.pos, 1), ap.beam_yaw(c, 0)
    a2.ship.bank, a2.ship.pitch, a2.ship.vel = 0, 0, { 0, 0, 0 }
    pull(a2, c, site)
    st2.claims = { [site .. "|" .. c.key] = { by = 1, tick = 1 } }
    step(st2, 1)
    expect(st2.twins[twin.key(site)].by).to_be(1)
  end)
end)

describe("twin hold timeout (a follower waiting in vain)", function()
  it("a hold nobody takes up lets go after HOLD_TIME, tells both players, and can be taken again", function()
    local st = new_state(2)
    local p, q = st.players[1], st.players[2]
    local site, L = twin_site(st)
    local anchor = twin.anchor_pos(L)
    q.ship.pos = { anchor[1], anchor[2] + 8, anchor[3] }
    q.site, q.mode = site, "helm"
    local ctx = ctx_of()
    st.tick = 500
    twin.hold(st, q, site, ctx)
    expect(st.twins[twin.key(site)].at).to_be(500)
    st.tick = 500 + twin.HOLD_TIME - 1
    twin.step(st, ctx)
    expect(twin.holder(st, site)).to_be(q)
    st.tick = 500 + twin.HOLD_TIME
    twin.step(st, ctx)
    expect(twin.holder(st, site)).to_be(nil)
    expect(st.twins[twin.key(site)].waited).to_be(1)
    expect(heard(q, "Nobody took the twin vault")).to_be(true)
    expect(heard(p, "closed again: ask P2")).to_be(true)
    -- holding again starts a fresh clock; a done vault is left alone
    twin.hold(st, q, site, ctx)
    expect(st.twins[twin.key(site)].at).to_be(st.tick)
    st.twins[twin.key(site)].done = true
    st.tick = st.tick + twin.HOLD_TIME + 5
    twin.step(st, ctx)
    expect(st.twins[twin.key(site)].by).to_be(2)
  end)
  it("a hold that is taken up in time is not cut short", function()
    local st = new_state(2)
    local p, q = st.players[1], st.players[2]
    local site, L = twin_site(st)
    local anchor = twin.anchor_pos(L)
    q.ship.pos = { anchor[1], anchor[2] + 8, anchor[3] }
    q.site, q.mode = site, "helm"
    p.site = site
    local ctx = ctx_of()
    twin.hold(st, q, site, ctx)
    st.tick = st.tick + twin.HOLD_TIME - 60
    expect(twin.take(st, p, site, ctx)).to_be(true)
    twin.step(st, ctx)
    expect(st.twins[twin.key(site)].waited).to_be(nil)
  end)
end)
