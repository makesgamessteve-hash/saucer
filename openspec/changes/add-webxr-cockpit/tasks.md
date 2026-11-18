## 1. Requirements

- [x] 1.1 Enter XR from the web build: Enter VR button + web/saucer_xr.js immersive-vr session (seated/local-floor); not yet tried on a headset (`tests/web/xr_web.test.js`: probe, spaces, "Unsupported browser")
- [x] 1.2 Player scale is constant: the cockpit transform drives the XR view and the eye never moves in a fold. Verified without a headset by mocked XR poses: `tests/c/test_xr.c` `xr_scale_is_constant_across_cockpits` (IPD, unit axes, head height and horizon identical across five cockpit poses/sizes through the real `sx_camera_view`) and `tests/game/xr_hands.lua` (the pilot's eye is bit-identical through a Villa to Seat fold and back, one haptic pulse). **Manual, still open:** a physical-headset check of the felt scale (comfort, IPD on real optics) cannot be automated; do it on a Quest/PCVR headset before archiving
- [x] 1.3 Controller and hand mapping: controllers (sticks, trigger, grip, A/B/X/Y, grip+stick size lever) and now hand tracking: `hand-tracking` is requested, six joints per hand reach C (`web/saucer_xr.js` `joints()`), where a pinch is the trigger, a fist the grip, and a pinch on the lever handle plus one detent (8 cm) down/up is Shrink/Grow (`sx_xr.c`, `tests/c/test_xr.c` `xr_pinch_is_trigger_and_fist_is_grip`, `xr_grab_the_lever_by_hand`; `tests/game/xr_hands.lua`; `tests/web/xr_web.test.js`). Hands are now drawn in the frame of the eye matrices (they were mirrored before)
- [x] 1.4 Comfort options: an in-game "Comfort settings" page (title card and bed panel; shown head-locked in XR too) sets snap or smooth turning, snap angle (15/30/45/60 degrees), vignette (off/low/medium/high) and the seated/standing session mode, and is saved to `comfort.txt` in the user dir (`saucer.xr.set_comfort`, `sim/comfort.lua`, `view/xr.lua`; `tests/lua/webxr_spec.lua`, `xr_comfort_persists_in_the_user_dir`). The snap angle travels as the `snap_a`/`snap_b` buttons so replays and lockstep stay deterministic. Not done (deferred): teleport locomotion, a seated height offset, reduced flashing (the camera never shakes or rolls)

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green

## 3. Scenario to test map

| Scenario | Named test |
| --- | --- |
| Unsupported browser | `web_xr_js` (`tests/web/xr_web.test.js`, first block) |
| Enter VR in the chosen mode | `web_xr_js` (preferred, explicit and fallback spaces) |
| Same scale in every cockpit | C `xr_scale_is_constant_across_cockpits`; Lua `webxr_spec` "a standing session lowers every size's camera by the same eye height" |
| Shrink in VR | `game_xr_hands` (eye bit-identical through the fold, one pulse); Lua `webxr_spec` "shrink in VR: the pilot's eye (head height) is unchanged..." |
| Pinch and fist are trigger and grip | C `xr_pinch_is_trigger_and_fist_is_grip`; `game_xr_hands` steps 2 and 4 |
| Grab the lever by hand | C `xr_grab_the_lever_by_hand`; `game_xr_hands` steps 1 and 3 |
| Comfort settings in and out of XR | Lua `webxr_spec` "comfort options (webxr)" group; C `xr_comfort_persists_in_the_user_dir` |
| Hull hit in VR | C `xr_haptic_pulses`; Lua `webxr_spec` "never shakes or rolls the camera and gives controllers a haptic pulse on a fold and on a hull hit"; `web_xr_js` (pulses reach the controller) |
