// Headless test of the web transport's JavaScript (web/saucer_net.js) under
// node: offer/answer codes, the host/join handshake over a fake
// RTCPeerConnection pair, and datagrams both ways through the bridge.
// Run: node tests/web/net_web.test.js   SPDX-License-Identifier: MIT
'use strict';
const assert = require('assert');
const N = require('../../web/saucer_net.js');

// ---- a fake WebRTC: two peer connections meet through their SDP text ----
const registry = {};
let nextId = 1;
class FakeChannel {
  constructor(label, opts) { this.label = label; this.opts = opts; this.readyState = 'connecting'; this.sent = 0; }
  send(u8) {
    if (this.readyState !== 'open') throw new Error('not open');
    if (this.fail) throw new Error('boom');
    this.sent++;
    const copy = new Uint8Array(u8).buffer;
    setImmediate(() => this.other.onmessage && this.other.onmessage({ data: copy }));
  }
  open() { this.readyState = 'open'; if (this.onopen) this.onopen(); }
}
class FakePC {
  constructor(cfg) {
    this.cfg = cfg; this.id = nextId++; registry[this.id] = this;
    this.iceGatheringState = 'new'; this.listeners = [];
  }
  addEventListener(name, fn) { if (name === 'icegatheringstatechange') this.listeners.push(fn); }
  gather() { setImmediate(() => { this.iceGatheringState = 'complete'; this.listeners.forEach((f) => f()); }); }
  createDataChannel(label, opts) { this.channel = new FakeChannel(label, opts); return this.channel; }
  async createOffer() { return { type: 'offer', sdp: 'v=0 fake-offer pc=' + this.id }; }
  async createAnswer() { return { type: 'answer', sdp: 'v=0 fake-answer pc=' + this.id }; }
  async setLocalDescription(d) { this.localDescription = d; this.gather(); }
  async setRemoteDescription(d) {
    this.remoteDescription = d;
    const other = registry[Number(d.sdp.split('pc=')[1])];
    if (d.type === 'answer') {
      // the host learns the answer: the channel opens on both sides
      const mine = this.channel, theirs = new FakeChannel(mine.label, mine.opts);
      mine.other = theirs; theirs.other = mine;
      setImmediate(() => {
        other.ondatachannel({ channel: theirs });
        theirs.open();
        mine.open();
      });
    }
  }
}

async function main() {
  // codes
  const code = N.encode('O', { sdp: 'v=0 ünïcode', seed: '42', players: 2 });
  assert.ok(code.startsWith('SXO1.'));
  assert.deepStrictEqual(N.decode('  ' + code.slice(0, 20) + '\n' + code.slice(20) + ' ', 'O'),
    { sdp: 'v=0 ünïcode', seed: '42', players: 2 });
  assert.throws(() => N.decode(code, 'A'), /offer code, not an answer/);
  assert.throws(() => N.decode(N.encode('A', { sdp: 'x' }), 'O'), /answer code, not an offer/);
  assert.throws(() => N.decode('SXO9.abc', 'O'), /another version/);
  assert.throws(() => N.decode('hello', 'O'), /not a Saucer code/);
  assert.throws(() => N.decode('SXO1.%%%%', 'O'), /damaged/);
  assert.throws(() => N.decode(N.encode('O', { nope: 1 }), 'O'), /no connection data/);
  assert.throws(() => N.encode('X', {}), /kind/);
  assert.throws(() => N.decode(undefined, 'O'), /not a Saucer code/);
  assert.deepStrictEqual(N.args('guest', 7), ['--net-web', 'guest', '--seed', '7']);
  assert.throws(() => N.host({ seed: 1 }), /no WebRTC/);

  // host and guest swap codes
  const host = N.host({ seed: 1234, players: 2 }, FakePC);
  assert.deepStrictEqual(host.channel.opts, { ordered: false, maxRetransmits: 0 });
  const offer = await host.offer;
  assert.ok(offer.startsWith('SXO1.'));
  const guest = N.join(offer, FakePC);
  assert.strictEqual(guest.info.seed, '1234');
  assert.strictEqual(guest.info.players, 2);
  const answer = await guest.answer;
  assert.ok(answer.startsWith('SXA1.'));
  assert.throws(() => host.accept(offer), /offer code, not an answer/);
  await host.accept(answer);
  const [hc, gc] = await Promise.all([host.open, guest.open]);
  assert.strictEqual(hc.readyState, 'open');
  assert.strictEqual(gc.readyState, 'open');

  // datagrams both ways through the bridge (what the engine's queue sees)
  const atHost = [], atGuest = [];
  const hostSend = N.bridge(hc, (u8) => atHost.push(Array.from(u8)));
  const guestSend = N.bridge(gc, (u8) => atGuest.push(Array.from(u8)));
  assert.strictEqual(hc.binaryType, 'arraybuffer');
  for (let i = 0; i < 50; i++) {
    assert.strictEqual(hostSend(new Uint8Array([0x53, 0x58, 0x4e, 0x31, 4, i])), 6);
    assert.strictEqual(guestSend(new Uint8Array([0x53, 0x58, 0x4e, 0x31, 4, 100 + i, 9])), 7);
  }
  await new Promise((r) => setImmediate(r));
  await new Promise((r) => setImmediate(r));
  assert.strictEqual(atGuest.length, 50);
  assert.strictEqual(atHost.length, 50);
  assert.deepStrictEqual(atGuest[7], [0x53, 0x58, 0x4e, 0x31, 4, 7]);
  assert.deepStrictEqual(atHost[49], [0x53, 0x58, 0x4e, 0x31, 4, 149, 9]);
  // text messages are not ours; a closed or failing channel reports -1
  gc.onmessage({ data: 'hello' });
  assert.strictEqual(atGuest.length, 50);
  hc.fail = true;
  assert.strictEqual(hostSend(new Uint8Array([1])), -1);
  hc.readyState = 'closed';
  assert.strictEqual(hostSend(new Uint8Array([1])), -1);

  // ICE gathering that never completes still resolves (timeout)
  const slow = new FakePC({});
  const t0 = Date.now();
  await N.gathered(slow, 50);
  assert.ok(Date.now() - t0 >= 40);
  slow.iceGatheringState = 'complete';
  await N.gathered(slow, 10000);
  console.log('net_web: all checks passed');
}

main().catch((e) => { console.error(e); process.exit(1); });
