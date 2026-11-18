## Why

Roadmap milestone 9, "Home among the stars (M3)": co-op leaves the single
screen and the dome becomes truly yours. Two machines (or two browsers) play
one deterministic universe in lockstep, a headset player can be one of them,
the dome fills with furniture, finds on display and a garden whose Comfort
speeds up Charge, the deepest derelicts get the Warden and the on-foot
toolkit grows a grapple and a cutter, mods can be switched on and off from
inside the game, and Hardcore raises the stakes for those who want them
(concept §3.3, §5.4, §8.2, §8.4, §9).

## What Changes

- ADDED `netplay`: Lockstep sessions
- ADDED `netplay`: Players who leave
- ADDED `netplay`: Joining and leaving
- ADDED `netplay`: Desync detection
- ADDED `netplay`: UDP on the desktop
- ADDED `netplay`: WebRTC on the web
- ADDED `netplay`: An XR player can join
- ADDED `home-decor`: Furniture
- ADDED `home-decor`: Where furniture may not go
- ADDED `home-decor`: Display slots
- ADDED `home-decor`: The garden
- ADDED `home-decor`: Comfort
- ADDED `home-decor`: Guests in a decorated dome
- ADDED `sentries-advanced`: The Warden
- ADDED `sentries-advanced`: A hunting Warden raises the alarm
- ADDED `sentries-advanced`: Stopping a Warden
- ADDED `sentries-advanced`: The grapple
- ADDED `sentries-advanced`: The cutter
- ADDED `mod-browser`: The mod browser
- ADDED `hardcore`: Hardcore mode

New data: `home/decor.lua` (furniture, seeds, Comfort), furniture at the
traders (`home/shop.lua`), display slots, garden beds and keep-clear zones in
`saucer/interior.lua`, Warden, grapple and cutter tuning in
`sentries/sentries.lua`, mod descriptions in `mod.lua`.
New scripts: `sim/decor.lua`, `sim/warden.lua`, `sim/tools.lua`,
`sim/hardcore.lua`, `sim/modbrowser.lua`.
Engine: `sx_net` (lockstep protocol, transport-agnostic), `sx_net_udp`
(desktop), a WebRTC bridge (`web/saucer_net.js`, the web shell's Online
co-op panel), `--host`, `--join`, `--net-players`, `--net-delay`,
`--net-web`, `--hardcore`, `saucer.net.status()`, `saucer.mods.available()`
and `saucer.mods.set_enabled()`, `<user-dir>/mods.txt`, compact split HUD for
two and four players.

## Impact

- New capabilities: `netplay`, `home-decor`, `mod-browser`, `hardcore`
- Extends `sentries-advanced` (add-wider-dark) with the Warden and two tools
- Builds on the co-op slots and docking of `add-wider-dark`, the deterministic
  sim and replays of `add-deterministic-sim`, the mod loader of
  `add-asset-vfs-and-mod-loading` and the WebXR cockpit of `add-webxr-cockpit`
- Old saves and replays keep their hashes: decor, Hardcore and tool state are
  created on first use
- Not in this change (see ROADMAP): rollback netcode, a browser and a desktop
  in one session, joining a running session, a download source for the mod
  browser
