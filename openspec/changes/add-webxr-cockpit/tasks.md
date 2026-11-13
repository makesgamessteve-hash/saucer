## 1. Requirements

- [x] 1.1 Enter XR from the web build: Enter VR button + web/saucer_xr.js immersive-vr session (seated/local-floor); not yet tried on a headset
- [ ] 1.2 Player scale is constant (partial): cockpit transform drives the XR view; not yet checked on a headset
- [ ] 1.3 Controller and hand mapping (partial): controllers mapped (sticks, trigger, grip, A/B/X/Y, grip+stick size lever); hand tracking not yet
- [ ] 1.4 Comfort options (partial): saucer.xr.comfort reports snap turn / vignette; no in-game settings UI yet

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
