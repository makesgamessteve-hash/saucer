## 1. Engine

- [x] 1.1 Widget groups (core, context, tray), the MORE button and the tray rect inside the safe area at every size, open or closed (`touch_layout_resolutions`, `touch_declutter` in `tests/c/test_core.c`)
- [x] 1.2 `sx_touch_context` / `sx_touch_settle`: a change waits while a finger holds or rests on the slot; frame stamps for the fade (`touch_declutter`)
- [x] 1.3 Tray toggle, pick closes it, tap outside closes it; hidden widgets are not hit (`touch_declutter`)

## 2. Lua

- [x] 2.1 `hud.touch_context`: beam, grapple, jam/decoy and size conditions (`tests/lua/touch_declutter_spec.lua`: "shows the beam only when…", "shows the grapple only on foot…", "shows the jammer and a decoy only when…", "shows a size button only where…")
- [x] 2.2 Nothing asked for under a menu; the HUD hands the context to the engine every frame ("asks for nothing while a menu is open…")
- [x] 2.3 Fade-in and pulse, nothing under a pressing finger ("never shows a button under a finger that is pressing, and fades it in")
- [x] 2.4 The tray holds every action and closes after a pick ("holds every action, opens from its button and closes after a pick")
- [x] 2.5 Slots and the open tray in the safe area at the eight reference sizes ("fits the slots and the open tray in the safe area at WxH")
- [x] 2.6 Beam scope placed clear of the controls and text on touch, skipped when there is no room

## 3. Evidence

- [x] 3.1 Screenshots before/after at 320x568 and 568x320, context buttons and tray open (`tools/shots/declutter.lua`)
