## 1. Look and lights (slice 1)
- [x] 1.1 `citygen.style_of`, `citygen.tiers`: a silhouette per civ shape, stacked tier solids, inverted towers on asteroids
- [x] 1.2 `assets.styled_kit`, window/sign/ledge/greeble parts, light parts split from walls
- [x] 1.3 `cities.light`: dark, flicker, ramp; chunk, district-glow and beacon meshes drawn by it
- [x] 1.4 HUD: message backing; the control hint top-centre, faded
- [x] 1.5 `tests/lua/city2_spec.lua`; before/after restore screenshots (`tools/shots/cities.lua`)
## 2. Vast (slice 2)
- [x] 2.1 `spec.ring`: outer skyline lots (towers and blocks, own seed child), `city.skyline`, kit grids widened, sector distance by extent
- [x] 2.2 Renderer: coarse mesh and glow per skyline district, windows built near the camera (LRU of 8), planet horizon impostors
- [x] 2.3 Tests in `tests/lua/city2_spec.lua`; screenshots `09_vast_high`, `10_skyline_ring`
## 3. Transit, undercity, dynamics (slice 3)
- [x] 3.1 Mag-rails and pylons, lift shafts, drawn trains and cabins, flooded and overgrown undercity decor
- [x] 3.2 Storms and wind, falling sky-bridges, roaming dark-district Watchers, `hud.weather`
## 4. Mystery and traders (slice 4)
- [x] 4.1 Archive records (`city.clues`, `cities.clue_text`, beam kind `clue`)
- [x] 4.2 City trader outposts (`sector.traders`, render and radar, dock message)
## 5. Polish and performance (slice 5)
- [x] 5.1 Helm hint docked bottom-left, fading; H help docked likewise
- [x] 5.2 Grid-restore payoff: light wave, early beacons, `gridon` sting, HUD banner
- [x] 5.3 Per-frame cost measured native and wasm; culling, LOD and batching to a budget
