// WebXR glue for Saucer (emscripten --js-library).
// Immersive sessions run their own frame loop: every XR frame this pushes the
// eye matrices, head pose and controller state into C and calls
// _saucer_xr_frame with the XR layer framebuffer registered as a GL name.
// SPDX-License-Identifier: MIT
addToLibrary({
  saucer_web_xr_probe__deps: ['$GL'],
  saucer_web_xr_probe: function () {
    var XR = { session: null };
    Module.saucerXR = XR;
    if (!navigator.xr) return;
    navigator.xr.isSessionSupported('immersive-vr').then(function (ok) {
      if (!ok) return;
      _saucer_xr_set_available(1);
      if (Module.onXRAvailable) Module.onXRAvailable();
    }).catch(function () {});

    // indices match sx_xr_ctl in engine/src/core/sx_xr.h
    var C = { TRIGGER_R: 0, TRIGGER_L: 1, GRIP_R: 2, GRIP_L: 3, A: 4, B: 5, X: 6, Y: 7, MENU: 8,
              STICK_LX: 9, STICK_LY: 10, STICK_RX: 11, STICK_RY: 12, LEVER_UP: 13, LEVER_DOWN: 14 };
    function val(b) { return b ? (b.value || (b.pressed ? 1 : 0)) : 0; }

    function controls(session) {
      var v = new Float32Array(15);
      for (var i = 0; i < session.inputSources.length; i++) {
        var src = session.inputSources[i], gp = src.gamepad;
        if (!gp) continue;
        var bt = gp.buttons, ax = gp.axes;
        var sx = ax.length >= 4 ? ax[2] : (ax[0] || 0), sy = ax.length >= 4 ? ax[3] : (ax[1] || 0);
        if (src.handedness === 'left') {
          v[C.TRIGGER_L] = val(bt[0]); v[C.GRIP_L] = val(bt[1]);
          v[C.X] = val(bt[4]); v[C.Y] = val(bt[5]);
          v[C.STICK_LX] = sx; v[C.STICK_LY] = sy;
          v[C.MENU] = Math.max(v[C.MENU], val(bt[3]) > 0.5 && val(bt[1]) > 0.5 ? 1 : 0);
        } else {
          v[C.TRIGGER_R] = val(bt[0]); v[C.GRIP_R] = val(bt[1]);
          v[C.A] = val(bt[4]); v[C.B] = val(bt[5]);
          // size lever: hold the right grip and push the stick up (grow) or down (shrink)
          if (val(bt[1]) > 0.5) {
            v[C.LEVER_UP] = sy < -0.8 ? 1 : 0; v[C.LEVER_DOWN] = sy > 0.8 ? 1 : 0;
            v[C.STICK_RX] = 0; v[C.STICK_RY] = 0;
          } else {
            v[C.STICK_RX] = sx; v[C.STICK_RY] = sy;
          }
        }
      }
      for (var k = 0; k < 15; k++) _saucer_xr_set_control(k, v[k]);
    }

    // add-webxr-cockpit: hand tracking. The six joints the engine's gestures need
    // (wrist, thumb tip, index tip, middle, ring, pinky tips), in the order of sx_xr.h.
    var JOINTS = ['wrist', 'thumb-tip', 'index-finger-tip', 'middle-finger-tip', 'ring-finger-tip', 'pinky-finger-tip'];
    function joints(session, frame, space, buf) {
      var tracked = [0, 0];
      for (var i = 0; i < session.inputSources.length; i++) {
        var src = session.inputSources[i], h = src.handedness === 'left' ? 0 : 1;
        if (!src.hand || !frame.getJointPose) continue;
        var good = 1, o = buf >> 2;
        for (var k = 0; k < JOINTS.length && good; k++) {
          var js = src.hand.get(JOINTS[k]), jp = js && frame.getJointPose(js, space);
          if (!jp) { good = 0; break; }
          HEAPF32[o + k * 3] = jp.transform.position.x;
          HEAPF32[o + k * 3 + 1] = jp.transform.position.y;
          HEAPF32[o + k * 3 + 2] = jp.transform.position.z;
        }
        if (good) { _saucer_xr_set_joints(h, 1, buf); tracked[h] = 1; }
      }
      for (var n = 0; n < 2; n++) if (!tracked[n]) _saucer_xr_set_joints(n, 0, 0);
      return tracked;
    }

    // haptic pulses the game asked for (controllers only; tracked hands have no actuator)
    function haptics(session) {
      for (var h = 0; h < 2; h++) {
        var s = _saucer_xr_haptic_take(h);
        if (!(s > 0)) continue;
        var ms = _saucer_xr_haptic_ms(h);
        for (var i = 0; i < session.inputSources.length; i++) {
          var src = session.inputSources[i], gp = src.gamepad;
          if (!gp || (src.handedness === 'left' ? 0 : 1) !== h) continue;
          var act = gp.hapticActuators && gp.hapticActuators[0];
          try {
            if (act && act.pulse) act.pulse(s, ms);
            else if (gp.vibrationActuator && gp.vibrationActuator.playEffect)
              gp.vibrationActuator.playEffect('dual-rumble', { duration: ms, strongMagnitude: s, weakMagnitude: s });
          } catch (e) { /* a controller that cannot rumble is fine */ }
        }
      }
    }

    // grip poses for the diegetic hands / wrist panel (0 left, 1 right)
    function hands(session, frame, space, tracked) {
      var ok = [0, 0];
      for (var i = 0; i < session.inputSources.length; i++) {
        var src = session.inputSources[i], h = src.handedness === 'left' ? 0 : 1;
        if (tracked && tracked[h]) { ok[h] = 1; continue; } // the joints already gave this hand its pose
        if (!src.gripSpace) continue;
        var gp = frame.getPose(src.gripSpace, space);
        if (!gp) continue;
        var p = gp.transform.position, m = gp.transform.matrix;
        _saucer_xr_set_hand(h, 1, p.x, p.y, p.z, -m[8], -m[9], -m[10]);
        ok[h] = 1;
      }
      for (var k = 0; k < 2; k++) if (!ok[k]) _saucer_xr_set_hand(k, 0, 0, 0, 0, 0, 0, 0);
    }

    // mode 'seated' asks for the 'local' space (origin at the head, eye level
    // = cockpit eye); 'standing' (default) asks for 'local-floor' and falls
    // back to 'local' when the device has no floor.
    Module.saucerEnterVR = function (mode) {
      if (XR.session) { XR.session.end(); return; }
      // no mode given: the comfort settings' choice (comfort.txt "mode")
      if (!mode) mode = _saucer_xr_pref_mode() === 1 ? 'seated' : 'standing';
      var gl = GL.currentContext && GL.currentContext.GLctx;
      if (!gl) return;
      var seated = mode === 'seated';
      navigator.xr.requestSession('immersive-vr', { optionalFeatures: ['local-floor', 'hand-tracking'] }).then(function (session) {
        XR.session = session;
        return gl.makeXRCompatible().then(function () {
          session.updateRenderState({ baseLayer: new XRWebGLLayer(session, gl, { antialias: false }) });
          function local() { return session.requestReferenceSpace('local').then(function (s) { return [s, 1]; }); }
          if (seated) return local();
          return session.requestReferenceSpace('local-floor').then(function (s) { return [s, 2]; }, local);
        }).then(function (res) {
          var space = res[0], viewBuf = _malloc(64), projBuf = _malloc(64), jointBuf = _malloc(72), lastFb = null, fbId = 0, last = 0;
          _saucer_xr_begin(res[1]);
          function onFrame(t, frame) {
            if (!XR.session) return;
            session.requestAnimationFrame(onFrame);
            var pose = frame.getViewerPose(space);
            if (!pose) return;
            var layer = session.renderState.baseLayer, fb = layer.framebuffer;
            if (fb !== lastFb) {
              fbId = GL.getNewId(GL.framebuffers);
              fb.name = fbId;
              GL.framebuffers[fbId] = fb;
              lastFb = fb;
            }
            var n = Math.min(2, pose.views.length);
            for (var i = 0; i < n; i++) {
              var view = pose.views[i], vp = layer.getViewport(view);
              HEAPF32.set(view.transform.inverse.matrix, viewBuf >> 2);
              HEAPF32.set(view.projectionMatrix, projBuf >> 2);
              _saucer_xr_set_view(i, viewBuf, projBuf, vp.x, vp.y, vp.width, vp.height);
            }
            var p = pose.transform.position, m = pose.transform.matrix;
            _saucer_xr_set_head(p.x, p.y, p.z, -m[8], -m[9], -m[10]);
            controls(session);
            hands(session, frame, space, joints(session, frame, space, jointBuf));
            haptics(session);
            var dt = last ? t - last : 1000 / 72;
            last = t;
            _saucer_xr_frame(fbId, n, dt);
          }
          session.addEventListener('end', function () {
            XR.session = null;
            _saucer_xr_end();
            _free(viewBuf); _free(projBuf); _free(jointBuf);
            if (Module.onXREnd) Module.onXREnd();
          });
          session.requestAnimationFrame(onFrame);
          if (Module.onXRStart) Module.onXRStart();
        });
      }).catch(function (e) { console.warn('WebXR session failed', e); XR.session = null; });
    };
  },
});
