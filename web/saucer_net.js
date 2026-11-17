// Networked co-op on the web (OpenSpec add-home-among-stars): a WebRTC data
// channel carries the lockstep datagrams of engine/src/core/sx_net.c.
// Signaling needs no server: the host's page shows an offer code, the guest
// pastes it and gets an answer code back to paste into the host's page
// (any chat works as the go-between). The channel is unordered with no
// retransmits - the lockstep protocol resends what was lost itself.
// Built into saucer.js with --pre-js; node loads it as a CommonJS module for
// tests/web/net_web.test.js.
// SPDX-License-Identifier: MIT
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module && module.exports) module.exports = api;
  if (typeof Module !== 'undefined') {
    Module.saucerNet = api;
    // datagrams from the page into the engine's queue
    Module.saucerNetPush = function (u8) {
      var p = _malloc(u8.length);
      HEAPU8.set(u8, p);
      var r = _saucer_net_push(p, u8.length);
      _free(p);
      return r;
    };
  } else if (root) {
    root.saucerNet = api;
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';
  var N = { PROTOCOL: 1 };
  N.ICE = [{ urls: 'stun:stun.l.google.com:19302' }];
  N.CHANNEL = { ordered: false, maxRetransmits: 0 };

  function b64encode(s) {
    if (typeof btoa === 'function') return btoa(unescape(encodeURIComponent(s)));
    return Buffer.from(s, 'utf8').toString('base64');
  }
  function b64decode(s) {
    if (typeof atob === 'function') return decodeURIComponent(escape(atob(s)));
    return Buffer.from(s, 'base64').toString('utf8');
  }

  // "SXO1." (offer) or "SXA1." (answer) + base64(JSON)
  N.encode = function (kind, obj) {
    if (kind !== 'O' && kind !== 'A') throw new Error('kind must be O or A');
    return 'SX' + kind + N.PROTOCOL + '.' + b64encode(JSON.stringify(obj)).replace(/=+$/, '');
  };
  N.decode = function (code, kind) {
    var c = String(code || '').replace(/\s+/g, '');
    var head = 'SX' + kind + N.PROTOCOL + '.';
    if (c.indexOf(head) !== 0) {
      if (/^SX[OA]\d+\./.test(c)) {
        if (c.charAt(2) !== kind) throw new Error(kind === 'O' ? 'that is an answer code, not an offer code'
                                                               : 'that is an offer code, not an answer code');
        throw new Error('that code is from another version of Saucer');
      }
      throw new Error('not a Saucer code');
    }
    var body = c.substring(head.length);
    while (body.length % 4) body += '=';
    var obj;
    try { obj = JSON.parse(b64decode(body)); } catch (e) { throw new Error('the code is cut off or damaged'); }
    if (!obj || typeof obj.sdp !== 'string') throw new Error('the code has no connection data');
    return obj;
  };

  // resolves once ICE gathering is complete (or after ms, with what we have)
  N.gathered = function (pc, ms) {
    return new Promise(function (resolve) {
      if (pc.iceGatheringState === 'complete') return resolve();
      var done = false, timer = null;
      function finish() {
        if (done) return;
        done = true;
        if (timer !== null) clearTimeout(timer);
        resolve();
      }
      pc.addEventListener('icegatheringstatechange', function () {
        if (pc.iceGatheringState === 'complete') finish();
      });
      timer = setTimeout(finish, ms || 4000);
    });
  };

  // wire a channel to an engine: push(u8) feeds it, the returned function sends
  N.bridge = function (channel, push) {
    channel.binaryType = 'arraybuffer';
    channel.onmessage = function (ev) {
      var d = ev.data;
      if (typeof d === 'string') return; // not ours
      push(new Uint8Array(d));
    };
    return function send(u8) {
      if (channel.readyState !== 'open') return -1;
      try {
        channel.send(u8);
        return u8.length;
      } catch (e) {
        return -1;
      }
    };
  };

  function newPC(RTC) {
    var P = RTC || (typeof RTCPeerConnection !== 'undefined' ? RTCPeerConnection : null);
    if (!P) throw new Error('this browser has no WebRTC');
    return new P({ iceServers: N.ICE });
  }

  // host: -> { offer: Promise<code>, accept(answerCode): Promise, open: Promise<channel>, pc }
  N.host = function (info, RTC) {
    var pc = newPC(RTC);
    var ch = pc.createDataChannel('saucer', N.CHANNEL);
    var open = new Promise(function (resolve, reject) {
      ch.onopen = function () { resolve(ch); };
      ch.onerror = function (e) { reject(e); };
    });
    var offer = pc.createOffer().then(function (o) { return pc.setLocalDescription(o); }).then(function () {
      return N.gathered(pc);
    }).then(function () {
      return N.encode('O', { sdp: pc.localDescription.sdp, seed: String(info.seed), players: info.players || 2 });
    });
    return {
      pc: pc, channel: ch, offer: offer, open: open,
      accept: function (code) {
        var a = N.decode(code, 'A');
        return pc.setRemoteDescription({ type: 'answer', sdp: a.sdp });
      },
    };
  };

  // guest: -> { info: {seed, players}, answer: Promise<code>, open: Promise<channel>, pc }
  N.join = function (offerCode, RTC) {
    var o = N.decode(offerCode, 'O');
    var pc = newPC(RTC);
    var open = new Promise(function (resolve) {
      pc.ondatachannel = function (ev) {
        var ch = ev.channel;
        if (ch.readyState === 'open') resolve(ch);
        else ch.onopen = function () { resolve(ch); };
      };
    });
    var answer = pc.setRemoteDescription({ type: 'offer', sdp: o.sdp }).then(function () {
      return pc.createAnswer();
    }).then(function (a) { return pc.setLocalDescription(a); }).then(function () {
      return N.gathered(pc);
    }).then(function () {
      return N.encode('A', { sdp: pc.localDescription.sdp });
    });
    return { pc: pc, info: { seed: o.seed, players: o.players || 2 }, answer: answer, open: open };
  };

  // the engine's arguments for a session
  N.args = function (role, seed) { return ['--net-web', role, '--seed', String(seed)]; };

  return N;
});
