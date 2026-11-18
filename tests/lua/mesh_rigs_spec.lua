-- SPDX-License-Identifier: MIT
-- OpenSpec add-mesh-builder, group "Meshes": hero meshes for the Watcher, the
-- Snatcher and the cockpit props (meshes/watcher.lua, snatcher.lua,
-- cockpit.lua), collision volumes and named nodes declared by recipes
-- (lib/volume.lua, lib/meshkit.lua rigs) and the build budget. The scenario
-- names of the spec are the `it` names below.
local data = require("lib.data")
local kit = require("lib.meshkit")
local volume = require("lib.volume")
local game = require("sim.game")
local sentry = require("sim.sentry")
local adv = require("sim.advsentry")
local assets = require("view.assets")
local vec = require("lib.vec")

local function new_state()
  local st = {}
  game.init(st, { seed = 42, players = 1 })
  return st
end

-- a recipe function that stands in for meshes/<id>.lua while `fn` runs
local function with_recipes(recipes, fn)
  local real = data.load
  data.load = function(path)
    local id = path:match("^meshes/(.+)%.lua$")
    if id and recipes[id] then return recipes[id] end
    return real(path)
  end
  local ok, err = pcall(fn)
  data.load = real
  if not ok then error(err, 0) end
end

-- a fake view that records every mesh drawn
local function recorder()
  local v = { drawn = {} }
  function v:mesh(id, o) self.drawn[#self.drawn + 1] = { id = id, o = o } end
  return v
end

local function free_rig(rig)
  if rig.base then saucer.mesh.free(rig.base) end
  for _, n in pairs(rig.nodes) do saucer.mesh.free(n.mesh) end
end

local function sphere_parts(n)
  local parts = {}
  for i = 1, n do parts[i] = { kind = "sphere", c = 1, r = 1, pos = { i * 0.1, 0, 0 }, color = { 1, 1, 1 } } end
  return parts
end

describe("collision volumes (lib/volume.lua)", function()
  local sph = { shape = "sphere", c = { 0, 1, 0 }, r = 1 }
  local box = { shape = "box", min = { -1, 0, -1 }, max = { 1, 2, 1 } }
  local cyl = { shape = "cylinder", c = { 0, 0, 0 }, r = 1, h = 2 }
  local at = { pos = { 0, 0, 0 }, yaw = 0 }

  it("measures the distance to a sphere, a box and a cylinder (0 inside)", function()
    expect(volume.dist(sph, at, { 0, 1, 0 })).to_be(0)
    expect(volume.dist(sph, at, { 0, 1, 3 })).to_be_near(2, 1e-9)
    expect(volume.dist(box, at, { 0, 1, 0 })).to_be(0)
    expect(volume.dist(box, at, { 4, 1, 0 })).to_be_near(3, 1e-9)
    expect(volume.dist(box, at, { 4, 6, 0 })).to_be_near(5, 1e-9)
    expect(volume.dist(cyl, at, { 0, 1, 0.5 })).to_be(0)
    expect(volume.dist(cyl, at, { 4, 1, 0 })).to_be_near(3, 1e-9)
    expect(volume.dist(cyl, at, { 0, 5, 0 })).to_be_near(3, 1e-9)
    expect(volume.dist(cyl, at, { 4, -1, 0 })).to_be_near(math.sqrt(10), 1e-9)
    expect(function() volume.dist({ shape = "torus" }, at, { 0, 0, 0 }) end).to_fail("unknown collision shape")
  end)
  it("places a volume with a position and a yaw", function()
    local xf = { pos = { 10, 0, 0 }, yaw = saucer.math.pi / 2 }
    -- yaw turns local +z toward world +x: the point 3 m along +x of the origin is 3 m along local +z
    expect(volume.dist(sph, xf, { 13, 1, 0 })).to_be_near(volume.dist(sph, at, { 0, 1, 3 }), 1e-6)
    expect(volume.dist(sph, { pos = { 0, 0, 0 } }, { 0, 1, 3 })).to_be_near(2, 1e-9)
    expect(volume.dist(sph, {}, { 0, 1, 3 })).to_be_near(2, 1e-9)
  end)
  it("finds the nearest volume of a list", function()
    local vols = { box, { shape = "sphere", c = { 9, 1, 0 }, r = 1 } }
    local d, i = volume.nearest(vols, at, { 8, 1, 0 })
    expect(i).to_be(2)
    expect(d).to_be(0)
    expect(volume.inside(vols, at, { 0, 1, 0 })).to_be(true)
    expect(volume.inside(vols, at, { 5, 1, 0 })).to_be(false)
    expect(volume.nearest({}, at, { 0, 0, 0 })).to_be(nil)
    expect(volume.nearest(nil, at, { 0, 0, 0 })).to_be(nil)
    expect(volume.inside(nil, at, { 0, 0, 0 })).to_be(false)
  end)
  it("checks that a list is well formed", function()
    expect(volume.check({ sph, box, cyl })).to_be(true)
    expect(volume.check(nil)).to_be(true)
    local ok, why = volume.check({ { shape = "cone" } })
    expect(ok).to_be(false)
    expect(why).to_contain("unknown shape")
    expect(select(2, volume.check({ { shape = "box", min = { 0, 0, 0 }, max = { 1, 0, 1 } } }))).to_contain("empty box")
    expect(select(2, volume.check({ { shape = "box" } }))).to_contain("empty box")
    expect(select(2, volume.check({ { shape = "sphere", c = { 0, 0, 0 }, r = 0 } }))).to_contain("no radius")
    expect(select(2, volume.check({ { shape = "cylinder", c = { 0, 0, 0 }, r = 1 } }))).to_contain("no height")
  end)
  it("bounds a list", function()
    local mn, mx = volume.bounds({ sph, box, cyl })
    expect(mn).to_equal({ -1, 0, -1 })
    expect(mx).to_equal({ 1, 2, 1 })
    local a, b = volume.bounds({ { shape = "sphere", c = { 5, 5, 5 }, r = 1 }, cyl })
    expect(a).to_equal({ -1, 0, -1 })
    expect(b).to_equal({ 6, 6, 6 })
    expect(volume.bounds({})).to_be(nil)
  end)
end)

describe("hero meshes from recipes: Watcher, Snatcher, cockpit props", function()
  it("builds a Watcher, a Snatcher and the cockpit props within their budgets", function()
    kit.strict = true
    local list = {
      { "watcher", {}, 1 }, { "snatcher", {}, 1 },
      { "cockpit", { kind = "console" }, 1 }, { "cockpit", { kind = "lever" }, 1 }, { "cockpit", { kind = "orb" }, 1 },
      { "sentry", { kind = "nest" }, 1 }, { "sentry", { kind = "vault" }, 1 },
      { "saucer", {}, 1 }, { "interior", {}, 1 },
    }
    local ok, err = pcall(function()
      for _, r in ipairs(list) do
        local rig = kit.rig(r[1], r[2], r[3])
        local b = kit.budget(r[1], kit.recipe(r[1], r[2], r[3]))
        expect(rig.stats.over).to_be(false)
        expect(rig.stats.triangles).to_be_greater(20)
        expect(rig.stats.triangles <= b.tris).to_be(true)
        -- a runaway guard, not the 5 ms budget (CI machines running sanitizers are slow)
        expect(rig.stats.ms).to_be_less(2000)
        free_rig(rig)
      end
    end)
    kit.strict = false
    if not ok then error(err, 0) end
  end)
  it("keeps the hero meshes of the base game at 3k triangles unless budgets.lua lists them", function()
    local listed = data.load("meshes/budgets.lua")
    for _, id in ipairs({ "watcher", "snatcher", "cockpit" }) do expect(listed[id]).to_be(nil) end
    expect(kit.budget("watcher", kit.recipe("watcher", {}, 1)).tris).to_be(1500) -- the recipe's own, below the hero 3000
    expect(kit.budget("cockpit", kit.recipe("cockpit", { kind = "lever" }, 1)).tris).to_be(500)
    expect(kit.budget("saucer", nil).tris).to_be(listed.saucer.tris)
    expect(kit.budget("whatever", nil).tris).to_be(3000)
    expect(kit.budget("whatever", nil).ms).to_be(5)
    expect(kit.budget("whatever", nil).ms_web).to_be(20)
  end)
  it("Civ variant: the Watcher's hash is committed, and another civ seed differs", function()
    local a = kit.rig("watcher", {}, 0x51)
    local b = kit.rig("watcher", {}, 0x51)
    local c = kit.rig("watcher", {}, 1)
    expect(a.hash).to_be(b.hash)
    expect(a.hash).to_be(7007463675324263414)
    expect(c.hash).to_be(7597359838634113023)
    expect(a.hash ~= c.hash).to_be(true)
    -- the head and the eye carry the civ's look too
    expect(a.nodes.head.hash).to_be(b.nodes.head.hash)
    expect(a.nodes.eye.hash ~= c.nodes.eye.hash or a.nodes.head.hash ~= c.nodes.head.hash).to_be(true)
    local s1, s2 = kit.rig("snatcher", {}, 0x51), kit.rig("snatcher", {}, 2)
    expect(s1.hash).to_be(4792954258640023144)
    expect(s1.hash ~= s2.hash).to_be(true)
    for _, r in ipairs({ a, b, c, s1, s2 }) do free_rig(r) end
  end)
  it("builds the console, the lever and the orb with their nodes", function()
    local lever = kit.rig("cockpit", { kind = "lever" }, 1)
    local orb = kit.rig("cockpit", { kind = "orb" }, 1)
    local console = kit.rig("cockpit", { kind = "console", w = 3, d = 1, h = 0.9 }, 1)
    expect(lever.nodes.handle.axis).to_be("pitch")
    expect(orb.nodes.orb.axis).to_be("pitch")
    expect(console.order).to_equal({})
    expect(console.base ~= nil).to_be(true)
    expect(#console.collision).to_be(1)
    expect(#kit.volumes("cockpit", { kind = "orb" }, 1)).to_be_greater(0)
    for _, r in ipairs({ lever, orb, console }) do free_rig(r) end
  end)
  it("No mesh files: the base game ships none", function()
    local bad = { glb = true, gltf = true, obj = true, vox = true }
    local function scan(dir, depth)
      for _, name in ipairs(saucer.vfs.list(dir)) do
        local ext = name:match("%.(%w+)$")
        expect(bad[ext or ""]).to_be(nil)
        if not ext and depth < 6 then scan(dir == "" and name or (dir .. "/" .. name), depth + 1) end
      end
    end
    scan("", 0)
    expect(table.concat(saucer.vfs.list("meshes"), ",")).to_contain("watcher.lua")
    expect(table.concat(saucer.vfs.list("meshes"), ",")).to_contain("snatcher.lua")
    expect(table.concat(saucer.vfs.list("meshes"), ",")).to_contain("cockpit.lua")
  end)
end)

describe("declared collision and named nodes", function()
  it("Animated eye: rotating node eye by 30 degrees moves only the eye, never the collision", function()
    local rig = kit.rig("watcher", {}, 1)
    local xf = { pos = { 4, 2, -3 }, yaw = 0.4 }
    local deg30 = 30 * saucer.math.pi / 180
    local before = kit.volumes("watcher", {}, 1)
    local snapshot = {}
    for i, v in ipairs(before) do snapshot[i] = { shape = v.shape, c = vec.copy(v.c), r = v.r } end
    local rest = recorder()
    local turned = recorder()
    kit.draw(rest, rig, xf, { eye = { pitch = 0 } })
    kit.draw(turned, rig, xf, { eye = { pitch = deg30 } })
    expect(#rest.drawn).to_be(1 + #rig.order)
    local moved = 0
    for i, d in ipairs(rest.drawn) do
      local t = turned.drawn[i]
      expect(t.id).to_be(d.id)
      if (t.o.pitch or 0) ~= (d.o.pitch or 0) then
        moved = moved + 1
        expect(t.id).to_be(rig.nodes.eye.mesh)
        expect(t.o.pitch - (d.o.pitch or 0)).to_be_near(deg30, 1e-9)
      else
        expect(t.o.pos).to_equal(d.o.pos)
        expect(t.o.yaw).to_be(d.o.yaw)
      end
    end
    expect(moved).to_be(1)
    -- the eye's pivot stays where it was; the collision list is the same table, unchanged
    expect(kit.node_pose(rig, "eye", xf, { eye = { pitch = deg30 } }).pos).to_equal(kit.node_pose(rig, "eye", xf, nil).pos)
    expect(kit.volumes("watcher", {}, 1)).to_be(before)
    for i, v in ipairs(before) do
      expect(v.c).to_equal(snapshot[i].c)
      expect(v.r).to_be(snapshot[i].r)
    end
    expect(volume.dist(before[1], xf, { 4, 2, -3 })).to_be(0)
    free_rig(rig)
  end)
  it("a child node follows its parent's yaw, about the parent's pivot", function()
    local rig = kit.rig("watcher", {}, 1)
    expect(rig.nodes.eye.parent).to_be("head")
    expect(rig.order[1]).to_be("head")
    expect(rig.order[2]).to_be("eye")
    local xf = { pos = { 0, 0, 0 }, yaw = 0 }
    local a = kit.node_pose(rig, "eye", xf, nil)
    local b = kit.node_pose(rig, "eye", xf, { head = { yaw = saucer.math.pi / 2 } })
    expect(a.pos[3]).to_be_near(0.95, 1e-6)
    expect(b.pos[1]).to_be_near(0.95, 1e-6)
    expect(b.pos[3]).to_be_near(0, 1e-6)
    expect(b.yaw).to_be_near(saucer.math.pi / 2, 1e-9)
    local big = kit.node_pose(rig, "eye", { pos = { 0, 0, 0 }, yaw = 0, scale = 2 }, nil)
    expect(big.pos[3]).to_be_near(1.9, 1e-6)
    expect(function() kit.node_pose(rig, "tail", xf, nil) end).to_fail("no node tail")
    -- every mesh of the rig goes to the view with the options given (a tint, a scale)
    local v = recorder()
    expect(kit.draw(v, rig, { pos = { 0, 0, 0 }, yaw = 0, scale = 2 }, nil, { tint = { 1, 0, 0, 1 } })).to_be(3)
    expect(v.drawn[1].o.scale).to_be(2)
    expect(v.drawn[3].o.tint[1]).to_be(1)
    free_rig(rig)
  end)
  it("a rig without base parts draws only its nodes", function()
    with_recipes({
      only_node = function()
        return { parts = { { kind = "box", min = { -1, -1, -1 }, max = { 1, 1, 1 }, node = "n" } },
                 nodes = { n = { pivot = { 0, 1, 0 } } } }
      end,
    }, function()
      local rig = kit.rig("only_node", {}, 1)
      expect(rig.base).to_be(nil)
      expect(rig.hash).to_be(nil)
      expect(rig.nodes.n.axis).to_be("yaw")
      expect(kit.draw(recorder(), rig, { pos = { 0, 0, 0 } }, nil)).to_be(1)
      free_rig(rig)
    end)
  end)
  it("rejects badly declared nodes and collision", function()
    local function box(node) return { kind = "box", min = { -1, -1, -1 }, max = { 1, 1, 1 }, node = node } end
    with_recipes({
      no_pivot = function() return { parts = { box("n") }, nodes = { n = {} } } end,
      no_parent = function() return { parts = { box("n") }, nodes = { n = { pivot = { 0, 0, 0 }, parent = "ghost" } } } end,
      pitch_parent = function()
        return { parts = { box("a"), box("b") },
                 nodes = { a = { pivot = { 0, 0, 0 }, axis = "pitch" }, b = { pivot = { 0, 0, 0 }, parent = "a" } } }
      end,
      unnamed = function() return { parts = { box("zzz") }, nodes = {} } end,
      bad_collision = function() return { parts = { box() }, collision = { { shape = "cone" } } } end,
      not_a_recipe = 5,
      no_parts = function() return { } end,
    }, function()
      expect(function() kit.rig("no_pivot", {}, 1) end).to_fail("has no pivot")
      expect(function() kit.rig("no_parent", {}, 1) end).to_fail("unknown parent")
      expect(function() kit.rig("pitch_parent", {}, 1) end).to_fail("must turn about the vertical axis")
      expect(function() kit.rig("unnamed", {}, 1) end).to_fail("unknown node zzz")
      expect(function() kit.rig("bad_collision", {}, 1) end).to_fail("unknown shape")
      expect(function() kit.rig("not_a_recipe", {}, 1) end).to_fail("not callable")
      expect(function() kit.rig("no_parts", {}, 1) end).to_fail("returned no parts")
    end)
  end)
  it("the view's asset cache hands out each rig once (Second request)", function()
    local A = { rigs = {} }
    local real, builds = saucer.mesh.build, 0
    saucer.mesh.build = function(...) builds = builds + 1 return real(...) end
    local ok, err = pcall(function()
      local r1 = assets.rig(A, "watcher", {}, 3)
      local mid = builds
      expect(mid).to_be_greater(0)
      local r2 = assets.rig(A, "watcher", {}, 3)
      expect(r2).to_be(r1)
      expect(builds).to_be(mid)
      expect(assets.rig(A, "watcher", {}, 4) ~= r1).to_be(true)
      expect(builds).to_be_greater(mid)
      expect(assets.rig(A, "cockpit", { kind = "lever" }, 3) ~= nil).to_be(true)
      expect(assets.rig(A, "cockpit", { kind = "orb" }, 3) ~= nil).to_be(true)
      -- the same recipe and params at another seed are another entry; the volumes are cached without a build
      local m = builds
      expect(kit.volumes("watcher", {}, 5)).to_be(kit.volumes("watcher", {}, 5))
      expect(kit.volumes("cockpit", { kind = "lever", a = { 1, 2 }, b = { x = 1 } }, 1))
        .to_be(kit.volumes("cockpit", { b = { x = 1 }, a = { 1, 2 }, kind = "lever" }, 1))
      expect(builds).to_be(m)
    end)
    saucer.mesh.build = real
    if not ok then error(err, 0) end
  end)
  it("the lever's grab volume is the radius of the hand grip (SX_XR_LEVER_REACH, 0.12 m)", function()
    local grab
    for _, v in ipairs(kit.volumes("cockpit", { kind = "lever" }, 1)) do
      if v.name == "grab" then grab = v end
    end
    expect(grab.shape).to_be("sphere")
    expect(grab.r).to_be_near(0.12, 1e-9)
    local xrv = require("view.xr")
    expect(xrv.LEVER_NEAR > 0).to_be(true)
  end)
end)

describe("build budget", function()
  local function runaway(n, extra)
    local r = { parts = sphere_parts(n) }
    for k, v in pairs(extra or {}) do r[k] = v end
    return function() return r end
  end

  it("Build time and triangles are returned and checked against the limits", function()
    local id, hash, ms = saucer.mesh.build({ parts = { { kind = "box", min = { 0, 0, 0 }, max = { 1, 1, 1 } } } })
    expect(type(hash)).to_be("number")
    expect(type(ms)).to_be("number")
    expect(ms >= 0).to_be(true)
    saucer.mesh.free(id)
    local b = { tris = 100, ms = 5, ms_web = 20 }
    expect(kit.time_ok(5, b, false)).to_be(true)
    expect(kit.time_ok(5.1, b, false)).to_be(false)
    expect(kit.time_ok(5.1, b, true)).to_be(true)
    expect(kit.time_ok(20.1, b, true)).to_be(false)
  end)
  it("fails in strict mode and falls back to a magenta box otherwise, recording the violation", function()
    with_recipes({ too_big = runaway(60, { budget = { tris = 100, ms = 1e6, ms_web = 1e6 } }) }, function()
      kit.strict = true
      expect(function() kit.build("too_big", {}, 1) end).to_fail("over budget: tris")
      expect(function() kit.rig("too_big", {}, 1) end).to_fail("over budget: tris")
      kit.strict = false
      kit.violations = {}
      local mesh, hash, stats = kit.build("too_big", {}, 1)
      expect(stats.over).to_be(true)
      expect(stats.triangles).to_be_greater(100)
      expect(saucer.mesh.info(mesh).triangles).to_be(12) -- the stand-in box
      expect(hash ~= nil).to_be(true)
      expect(kit.violations[1].id).to_be("too_big")
      expect(kit.violations[1].what).to_be("tris")
      expect(kit.violations[1].limit).to_be(100)
      saucer.mesh.free(mesh)
      local rig = kit.rig("too_big", {}, 1)
      expect(rig.stats.over).to_be(true)
      expect(saucer.mesh.info(rig.base).triangles).to_be(12)
      expect(rig.order).to_equal({})
      expect(#kit.violations).to_be(2)
      free_rig(rig)
    end)
  end)
  it("falls back for a rig whose nodes put it over budget, covering base and nodes together", function()
    with_recipes({
      nodes_big = function()
        local parts = sphere_parts(2)
        for _, p in ipairs(sphere_parts(40)) do p.node = "n"; parts[#parts + 1] = p end
        return { parts = parts, nodes = { n = { pivot = { 0, 0, 0 } }, m = { pivot = { 0, 0, 0 } } }, budget = { tris = 200 } }
      end,
    }, function()
      kit.violations = {}
      local rig = kit.rig("nodes_big", {}, 1)
      expect(rig.stats.over).to_be(true)
      expect(rig.stats.triangles).to_be_greater(200)
      expect(rig.nodes.n).to_be(nil)
      expect(kit.violations[1].what).to_be("tris")
      free_rig(rig)
    end)
  end)
  it("warns when a build takes longer than its time limit (it never changes the mesh)", function()
    with_recipes({ slow = runaway(4, { budget = { tris = 1000, ms = -1, ms_web = -1 } }) }, function()
      kit.strict = true -- strict only turns triangle overruns into errors
      kit.violations = {}
      local mesh, _, stats = kit.build("slow", {}, 1)
      local rig = kit.rig("slow", {}, 1)
      kit.strict = false
      expect(stats.over).to_be(false)
      expect(rig.stats.over).to_be(false)
      expect(#kit.violations).to_be(2)
      expect(kit.violations[1].what).to_be("ms")
      expect(kit.violations[2].what).to_be("ms")
      saucer.mesh.free(mesh)
      free_rig(rig)
    end)
  end)
end)

describe("hit volumes in the sim", function()
  it("a Watcher's and a Snatcher's reach is the distance to its declared volumes", function()
    local def = { kind = "watcher", pos = { 0, 0, 0 }, yaw = 0, glyph = 1 }
    local dyn = { yaw = 0 }
    local c = kit.volumes("watcher", {}, 1)[1]
    expect(c.name).to_be("head")
    expect(c.shape).to_be("sphere")
    expect(adv.reach(def, dyn, { 0, 0, -(c.r + 2) })).to_be_near(2, 1e-6)
    expect(adv.reach(def, dyn, { 0, 0, 0 })).to_be(0)
    -- turned by yaw: the same point is now on the head's other side
    dyn.yaw = saucer.math.pi
    expect(adv.reach(def, dyn, { 0, 0, c.r + 2 })).to_be_near(2, 1e-6)
    dyn.yaw = nil
    expect(adv.reach(def, dyn, { 0, 0, -(c.r + 2) })).to_be_near(2, 1e-6)
    dyn.pos = { 10, 0, 0 }
    expect(adv.reach(def, dyn, { 10, 0, -(c.r + 2) })).to_be_near(2, 1e-6)
    local snatch = { kind = "snatcher", pos = { 0, 0, 0 }, yaw = 0 }
    expect(adv.reach(snatch, {}, { 0, 0, 0.3 })).to_be(0)
    expect(adv.reach(snatch, {}, { 0, 0, 5 }) < 5).to_be(true)
    -- the others have no recipe: from the centre
    expect(adv.reach({ kind = "clamp", pos = { 0, 0, 0 } }, {}, { 0, 3, 4 })).to_be_near(5, 1e-9)
    expect(adv.reach({ kind = "clamp", pos = { 0, 0, 0 }, yaw = 0 }, { pos = { 0, 0, 1 } }, { 0, 0, 4 })).to_be_near(3, 1e-9)
  end)
  it("the Jammer reaches a sentry by its volume, not its centre", function()
    local st = new_state()
    local t = sentry.tune()
    local defs = { { kind = "watcher", pos = { 0, 0, 0 }, yaw = 0, glyph = 1 } }
    local function dyns() return { [1] = { { st = "dormant", t = 0, target = 0, lost = 0 } } } end
    local state = { sentries = dyns(), players = {}, tick = 1 }
    local r = kit.volumes("watcher", {}, 1)[1].r
    -- the centre is just outside the all-round pulse (near), the volume is just inside it
    local d = t.jammer.near + r - 0.2
    expect(d > t.jammer.near).to_be(true)
    expect(sentry.jam(state, 1, defs, { 0, 0, d }, { 0, 0, -1 })).to_be(1)
    expect(state.sentries[1][1].st).to_be("disabled")
    -- too far even for the volume
    state.sentries = dyns()
    expect(sentry.jam(state, 1, defs, { 0, 0, t.jammer.range + r + 1 }, { 0, 0, 1 })).to_be(0)
    expect(state.sentries[1][1].st).to_be("dormant")
    -- in range but outside the cone: no
    expect(sentry.jam(state, 1, defs, { 0, 0, t.jammer.near + r + 2 }, { 0, 0, 1 })).to_be(0)
    -- in the cone, the cone being aimed at the centre
    expect(sentry.jam(state, 1, defs, { 0, 0, t.jammer.near + r + 2 }, { 0, 0, -1 })).to_be(1)
    -- a sentry that is off stays off; standing on it still works
    state.sentries[1][1] = { st = "off" }
    expect(sentry.jam(state, 1, defs, { 0, 0, 0 }, { 0, 0, 1 })).to_be(0)
    state.sentries[1][1] = { st = "dormant", t = 0, target = 0, lost = 0 }
    expect(sentry.jam(state, 1, defs, { 0, 0, 0 }, { 0, 0, 1 })).to_be(1)
    expect(st.tick ~= nil).to_be(true)
  end)
  it("the Override spike reaches a disabled sentry by its volume", function()
    local st = new_state()
    local t = sentry.tune()
    local p = st.players[1]
    local si = 2
    local wi
    for i, d in ipairs(game.sentries(si)) do
      if d.kind == "snatcher" and not wi then wi = i end
    end
    local def, dyn = game.sentries(si)[wi], st.sentries[si][wi]
    dyn.st, dyn.yaw = "disabled", 0
    p.mode, p.site, p.excursion = "foot", si, { body = { pos = { 0, 0, 0 }, yaw = 0, pitch = 0 } }
    local saved = game.viewpoint
    local eye
    game.viewpoint = function(q, s) if q == p then return vec.copy(eye), 0, 0 end return saved(q, s) end
    -- the centre is beyond the spike's reach, the Snatcher's shell is within it
    eye = vec.add(adv.pos_of(def, dyn), { 0, 0, t.spike.reach + 0.3 })
    expect(adv.spike_target(st, p, t)).to_be(wi)
    eye = vec.add(adv.pos_of(def, dyn), { 0, 0, t.spike.reach + 6 })
    expect(adv.spike_target(st, p, t)).to_be(nil)
    game.viewpoint = saved
    p.mode, p.excursion = "helm", nil
  end)
  it("every Watcher and Snatcher of a site carries its civ's glyph into its look and its volumes", function()
    for si = 1, 4 do
      for _, d in ipairs(game.sentries(si)) do
        if d.kind == "watcher" or d.kind == "snatcher" then
          expect(type(d.glyph) == "number" or d.glyph == nil).to_be(true)
          expect(#kit.volumes(d.kind, {}, d.glyph or 1)).to_be_greater(0)
        end
      end
    end
  end)
end)

describe("the size lever in a headset", function()
  local xrv = require("view.xr")
  local function hand_at(x, y, z)
    return { wrist = { x, y, z }, thumb = { x - 0.04, y, z + 0.09 }, index = { x - 0.02, y, z + 0.17 },
             middle = { x, y, z + 0.18 }, ring = { x + 0.02, y, z + 0.17 }, pinky = { x + 0.04, y, z + 0.15 } }
  end
  local function lever_view(joints)
    saucer.test.xr({ available = 1, session = 2, head_pos = { 0, 1.6, 0 }, head_fwd = { 0, 0, 1 }, joints = joints })
    local v = recorder()
    local n = xrv.lever(v, { rigs = {} }, { pos = { 0, 0, 0 }, yaw = 0 })
    return v, n
  end
  local function off() saucer.test.xr({ available = 0, session = 0, head_pos = { 0, 0, 0 }, hands = {}, joints = { left = false, right = false } }) end

  it("draws the lever rig (base and handle), tinted when a hand is near it and when it is held", function()
    local v, n = lever_view({ right = hand_at(0.5, 1.0, 0.0) })
    expect(n).to_be(2)
    expect(#v.drawn).to_be(2)
    expect(v.drawn[1].o.tint).to_be(nil)
    expect(v.drawn[2].o.pitch).to_be(0)
    -- a hand right at the grab volume lights it
    local pos = saucer.xr.lever()
    local h = saucer.xr.hands()[1]
    local near = lever_view({ right = hand_at(pos[1] - (h.pos[1] - 0.5), pos[2] - (h.pos[2] - 1.0) + 0.05 - xrv.LEVER_KNOB, pos[3] - (h.pos[3] - 0.0)) })
    expect(near.drawn[1].o.tint).to_be_truthy()
    off()
    expect(select(2, lever_view({}))).to_be(2)
    off()
  end)
end)
