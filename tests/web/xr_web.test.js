// Headless test of the WebXR glue (web/saucer_xr.js) under node: the
// "Enter VR" probe on browsers with and without WebXR, the session start in
// the comfort settings' space, controller values, the hand-tracking joints,
// haptic pulses and the session end, all on a fake XRSession (no headset).
// Run: node tests/web/xr_web.test.js   SPDX-License-Identifier: MIT
'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

// ---- the emscripten side the glue talks to ----
let lib = null;
const calls = [];
const heap = new Float32Array(4096);
let prefMode = 2;
let nextAlloc = 64;
const haptic = [{ s: 0, ms: 0 }, { s: 0, ms: 0 }];
const fns = {
  _saucer_xr_set_available: (a) => calls.push(['available', a]),
  _saucer_xr_begin: (m) => calls.push(['begin', m]),
  _saucer_xr_end: () => calls.push(['end']),
  _saucer_xr_frame: (fb, n, dt) => calls.push(['frame', fb, n, dt]),
  _saucer_xr_set_view: (i, v, p, x, y, w, h) => calls.push(['view', i, x, y, w, h]),
  _saucer_xr_set_head: (px, py, pz, fx, fy, fz) => calls.push(['head', px, py, pz, fx, fy, fz]),
  _saucer_xr_set_control: (k, v) => calls.push(['control', k, v]),
  _saucer_xr_set_hand: (i, ok, px, py, pz) => calls.push(['hand', i, ok, px, py, pz]),
  _saucer_xr_set_joints: (hand, ok, ptr) => {
    const j = ok ? Array.from(heap.slice(ptr >> 2, (ptr >> 2) + 18)) : null;
    calls.push(['joints', hand, ok, j]);
  },
  _saucer_xr_haptic_take: (h) => { const s = haptic[h].s; haptic[h].s = 0; return s; },
  _saucer_xr_haptic_ms: (h) => haptic[h].ms,
  _saucer_xr_pref_mode: () => prefMode,
  _malloc: (n) => { const p = nextAlloc; nextAlloc += n; calls.push(['malloc', n]); return p; },
  _free: (p) => calls.push(['free', p]),
};
Object.assign(global, fns);
global.HEAPF32 = heap;
global.addToLibrary = (o) => { lib = o; };
const fb = {};
global.GL = { currentContext: { GLctx: { makeXRCompatible: () => Promise.resolve() } }, framebuffers: {}, getNewId: () => 7 };
global.XRWebGLLayer = class { constructor() { this.framebuffer = fb; } getViewport(v) { return v.vp; } };
vm.runInThisContext(fs.readFileSync(path.join(__dirname, '../../web/saucer_xr.js'), 'utf8'), { filename: 'saucer_xr.js' });
assert.ok(lib && typeof lib.saucer_web_xr_probe === 'function', 'the library registers saucer_web_xr_probe');
const setNav = (n) => Object.defineProperty(global, 'navigator', { value: n, configurable: true, writable: true });
const tick = () => new Promise((r) => setImmediate(r));
const count = (name) => calls.filter((c) => c[0] === name).length;
const last = (name) => calls.filter((c) => c[0] === name).pop();

// ---- fakes of a headset session ----
const ident = () => { const m = new Float32Array(16); m[0] = m[5] = m[10] = m[15] = 1; return m; };
function makeSession(sources, spaces) {
  const s = {
    inputSources: sources, renderState: {}, raf: null, listeners: {}, ended: false,
    requestReferenceSpace(kind) { spaces.push(kind); return Promise.resolve({ kind }); },
    updateRenderState(st) { Object.assign(this.renderState, st); },
    requestAnimationFrame(cb) { this.raf = cb; },
    addEventListener(n, f) { this.listeners[n] = f; },
    end() { this.ended = true; if (this.listeners.end) this.listeners.end(); },
  };
  return s;
}
function makeFrame(joints) {
  const view = (x) => ({ transform: { inverse: { matrix: ident() }, position: { x, y: 1.6, z: 0 }, matrix: ident() },
                         projectionMatrix: ident(), vp: { x: x < 0 ? 0 : 960, y: 0, width: 960, height: 1080 } });
  return {
    getViewerPose: () => ({ views: [view(-0.032), view(0.032)], transform: { position: { x: 0, y: 1.6, z: 0 }, matrix: ident() } }),
    getPose: (space) => (space && space.pose) ? { transform: { position: space.pose, matrix: ident() } } : null,
    getJointPose: joints === undefined ? undefined : (js) => joints(js),
  };
}
function gamepad(handed, buttons, axes, actuators) {
  return { handedness: handed, gripSpace: { pose: { x: handed === 'left' ? -0.2 : 0.2, y: 1, z: -0.3 } },
           gamepad: { buttons: buttons.map((v) => ({ value: v, pressed: v > 0.5 })), axes, ...actuators } };
}
async function start(nav, session, spaces, mode) {
  setNav(nav);
  global.Module = {};
  calls.length = 0;
  lib.saucer_web_xr_probe();
  await tick();
  nav.xr && (nav.xr.requestSession = () => Promise.resolve(session));
  Module.saucerEnterVR(mode);
  await tick(); await tick(); await tick();
}

async function main() {
  // Unsupported browser: no WebXR at all, or no immersive-vr: nothing is announced and nothing throws
  let offered = 0;
  setNav({});
  global.Module = {};
  calls.length = 0;
  lib.saucer_web_xr_probe();
  await tick();
  assert.strictEqual(count('available'), 0, 'a browser without WebXR gets no VR control');
  assert.ok(Module.saucerXR && Module.saucerXR.session === null);
  setNav({ xr: { isSessionSupported: () => Promise.resolve(false) } });
  global.Module = { onXRAvailable: () => { offered++; } };
  calls.length = 0;
  lib.saucer_web_xr_probe();
  await tick();
  assert.strictEqual(count('available'), 0);
  assert.strictEqual(offered, 0);
  setNav({ xr: { isSessionSupported: () => Promise.reject(new Error('blocked')) } });
  lib.saucer_web_xr_probe();
  await tick();
  assert.strictEqual(count('available'), 0, 'a failing probe leaves the flat game alone');
  // supported: the page is told, once
  setNav({ xr: { isSessionSupported: (m) => Promise.resolve(m === 'immersive-vr') } });
  lib.saucer_web_xr_probe();
  await tick();
  assert.deepStrictEqual(last('available'), ['available', 1]);
  assert.strictEqual(offered, 1);

  // Enter VR with no mode asks the comfort settings: seated (1) or standing (2)
  for (const [pref, space, code] of [[1, 'local', 1], [2, 'local-floor', 2]]) {
    prefMode = pref;
    const spaces = [];
    const s = makeSession([], spaces);
    await start({ xr: { isSessionSupported: () => Promise.resolve(true) } }, s, spaces);
    assert.deepStrictEqual(spaces, [space], 'preferred mode ' + pref);
    assert.deepStrictEqual(last('begin'), ['begin', code]);
    assert.ok(s.renderState.baseLayer, 'a WebGL layer');
    s.end();
  }
  // an explicit mode wins; a headset with no floor falls back to the seated space
  {
    prefMode = 2;
    const spaces = [];
    const s = makeSession([], spaces);
    await start({ xr: { isSessionSupported: () => Promise.resolve(true) } }, s, spaces, 'seated');
    assert.deepStrictEqual(spaces, ['local']);
    s.end();
    const spaces2 = [];
    const s2 = makeSession([], spaces2);
    s2.requestReferenceSpace = (k) => { spaces2.push(k); return k === 'local-floor' ? Promise.reject(new Error('none')) : Promise.resolve({ kind: k }); };
    await start({ xr: { isSessionSupported: () => Promise.resolve(true) } }, s2, spaces2, 'standing');
    assert.deepStrictEqual(spaces2, ['local-floor', 'local']);
    assert.deepStrictEqual(last('begin'), ['begin', 1]);
    s2.end();
  }

  // a session with controllers: values, the size lever, haptics
  const rumbles = [];
  const left = gamepad('left', [0.2, 0.9, 0, 0, 1, 0], [0, 0, 0.1, -0.4], {
    hapticActuators: [{ pulse: (s, ms) => rumbles.push(['left', s, ms]) }] });
  const right = gamepad('right', [0.7, 0.8, 0, 0, 0, 1], [0, 0, 0.0, 0.9], {
    vibrationActuator: { playEffect: (kind, o) => rumbles.push(['right', kind, o.strongMagnitude, o.duration]) } });
  const spaces = [];
  const s = makeSession([left, right], spaces);
  await start({ xr: { isSessionSupported: () => Promise.resolve(true) } }, s, spaces, 'standing');
  haptic[0] = { s: 0.6, ms: 80 };
  haptic[1] = { s: 1, ms: 120 };
  calls.length = 0;
  s.raf(16, makeFrame());
  const controls = {};
  calls.filter((c) => c[0] === 'control').forEach((c) => { controls[c[1]] = c[2]; });
  assert.ok(Math.abs(controls[1] - 0.2) < 1e-6 && Math.abs(controls[3] - 0.9) < 1e-6, 'left trigger and grip');
  assert.ok(Math.abs(controls[0] - 0.7) < 1e-6 && Math.abs(controls[2] - 0.8) < 1e-6, 'right trigger and grip');
  assert.strictEqual(controls[14], 1, 'right grip held + stick down = the lever pulled (shrink)');
  assert.strictEqual(controls[13], 0);
  assert.strictEqual(count('view'), 2);
  assert.deepStrictEqual(last('frame').slice(0, 3), ['frame', 7, 2]);
  assert.deepStrictEqual(rumbles[0], ['left', 0.6, 80], 'a haptic pulse reaches the left controller');
  assert.deepStrictEqual(rumbles[1], ['right', 'dual-rumble', 1, 120], 'and the right one through vibrationActuator');
  // no pending pulse: no rumble; a controller that cannot rumble (or throws) is fine
  rumbles.length = 0;
  s.raf(32, makeFrame());
  assert.strictEqual(rumbles.length, 0);
  haptic[0] = { s: 0.5, ms: 30 };
  haptic[1] = { s: 0.5, ms: 30 };
  left.gamepad.hapticActuators = [{ pulse: () => { throw new Error('lost'); } }];
  delete right.gamepad.vibrationActuator;
  s.raf(48, makeFrame());
  // hands with no gamepad of their own use the grip pose
  const poses = calls.filter((c) => c[0] === 'hand');
  assert.ok(poses.some((c) => c[1] === 0 && c[2] === 1), 'controller grip poses drive the hands');

  // hand tracking: six joints per tracked hand, in sx_xr.h order; no hand = no joints
  const names = ['wrist', 'thumb-tip', 'index-finger-tip', 'middle-finger-tip', 'ring-finger-tip', 'pinky-finger-tip'];
  const handSource = (handed, base) => {
    const map = new Map();
    names.forEach((n, i) => map.set(n, { joint: n, base, i }));
    return { handedness: handed, hand: { get: (n) => map.get(n) }, gripSpace: null, gamepad: null };
  };
  const joint = (js) => ({ transform: { position: { x: js.base + js.i * 0.01, y: 1 + js.i, z: -js.i } } });
  const hs = makeSession([handSource('left', -0.5), handSource('right', 0.5)], []);
  await start({ xr: { isSessionSupported: () => Promise.resolve(true) } }, hs, [], 'standing');
  calls.length = 0;
  hs.raf(16, makeFrame(joint));
  const jr = calls.filter((c) => c[0] === 'joints');
  assert.strictEqual(jr.length, 2);
  const rj = jr.find((c) => c[1] === 1);
  assert.strictEqual(rj[2], 1);
  assert.strictEqual(rj[3].length, 18);
  assert.ok(Math.abs(rj[3][0] - 0.5) < 1e-6 && Math.abs(rj[3][4] - 2) < 1e-6 && Math.abs(rj[3][17] + 5) < 1e-6, 'wrist x, thumb y, pinky -z');
  const lj = jr.find((c) => c[1] === 0);
  assert.ok(Math.abs(lj[3][0] + 0.5) < 1e-6);
  // tracked hands give the poses through the joints: the grip-space path is skipped
  assert.ok(!calls.some((c) => c[0] === 'hand' && c[2] === 1), 'tracked hands are posed by C from their joints');
  // a hand whose joint pose is missing is reported as lost
  calls.length = 0;
  hs.raf(32, makeFrame((js) => (js.i === 3 && js.base > 0 ? null : joint(js))));
  const lost = calls.filter((c) => c[0] === 'joints');
  assert.deepStrictEqual(lost.find((c) => c[1] === 1).slice(0, 3), ['joints', 1, 0]);
  assert.strictEqual(lost.find((c) => c[1] === 0)[2], 1);
  // a browser without getJointPose reports no hands either
  calls.length = 0;
  hs.raf(48, makeFrame());
  assert.ok(calls.filter((c) => c[0] === 'joints').every((c) => c[2] === 0));
  // the session ends: C is told, the buffers are freed, the page hook runs
  let ended = 0;
  Module.onXREnd = () => { ended++; };
  calls.length = 0;
  hs.end();
  assert.strictEqual(count('end'), 1);
  assert.strictEqual(count('free'), 3);
  assert.strictEqual(ended, 1);
  assert.strictEqual(Module.saucerXR.session, null);
  console.log('xr_web: all checks passed');
}

main().catch((e) => { console.error(e); process.exit(1); });
