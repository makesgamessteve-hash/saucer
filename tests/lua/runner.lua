-- SPDX-License-Identifier: MIT
-- Minimal busted-style spec runner executed inside the engine
-- (saucer_headless --test-lua tests/lua [--coverage]). Returns the failure count.
local results = { pass = 0, fail = 0, failures = {} }
local stack = {}
local hooks = {}

local function fmt(v)
  if type(v) == "string" then return string.format("%q", v) end
  return tostring(v)
end

local function deep_eq(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do if not deep_eq(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

function expect(v)
  local e = {}
  local function fail(msg) error(msg, 3) end
  function e.to_be(x) if v ~= x then fail("expected " .. fmt(x) .. ", got " .. fmt(v)) end end
  function e.to_equal(x) if not deep_eq(v, x) then fail("tables/values differ: " .. fmt(v) .. " vs " .. fmt(x)) end end
  function e.to_be_truthy() if not v then fail("expected truthy, got " .. fmt(v)) end end
  function e.to_be_falsy() if v then fail("expected falsy, got " .. fmt(v)) end end
  function e.to_be_near(x, eps)
    if type(v) ~= "number" or math.abs(v - x) > (eps or 1e-9) then fail("expected ~" .. fmt(x) .. ", got " .. fmt(v)) end
  end
  function e.to_be_greater(x) if not (v > x) then fail("expected > " .. fmt(x) .. ", got " .. fmt(v)) end end
  function e.to_be_less(x) if not (v < x) then fail("expected < " .. fmt(x) .. ", got " .. fmt(v)) end end
  function e.to_contain(x)
    if type(v) == "string" then
      if not v:find(x, 1, true) then fail(fmt(v) .. " does not contain " .. fmt(x)) end
    else
      for _, y in ipairs(v) do if deep_eq(y, x) then return end end
      fail("list does not contain " .. fmt(x))
    end
  end
  function e.to_fail(pattern)
    local ok, err = pcall(v)
    if ok then fail("expected an error") end
    if pattern and not tostring(err):find(pattern, 1, true) then fail("error " .. fmt(err) .. " lacks " .. fmt(pattern)) end
  end
  return e
end

function describe(name, fn)
  stack[#stack + 1] = name
  local saved = #hooks
  fn()
  while #hooks > saved do table.remove(hooks) end
  stack[#stack] = nil
end

function before_each(fn) hooks[#hooks + 1] = fn end

function it(name, fn)
  local full = table.concat(stack, " > ") .. " > " .. name
  local ok, err = pcall(function()
    for _, h in ipairs(hooks) do h() end
    fn()
  end)
  if ok then
    results.pass = results.pass + 1
  else
    results.fail = results.fail + 1
    results.failures[#results.failures + 1] = full .. "\n    " .. tostring(err)
  end
end

for _, f in ipairs(SPEC_FILES) do
  local fh = io.open(f, "rb")
  local chunk, err
  if fh then
    chunk, err = load(fh:read("a"), "@" .. f)
    fh:close()
  else
    err = "cannot open"
  end
  if not chunk then
    results.fail = results.fail + 1
    results.failures[#results.failures + 1] = f .. ": " .. err
  else
    local ok, e2 = pcall(chunk)
    if not ok then
      results.fail = results.fail + 1
      results.failures[#results.failures + 1] = f .. ": " .. tostring(e2)
    end
  end
end

for _, f in ipairs(results.failures) do io.stdout:write("FAIL ", f, "\n") end
io.stdout:write(string.format("lua specs: %d passed, %d failed (%d files)\n", results.pass, results.fail, #SPEC_FILES))
return results.fail
