# Cave waterfall room CFALL, FLOOD movie, lever 67 / gate 71

Audit: `AI_COMMS/act1_completion_20261017/audit_20261028/CAVE_OVERVIEW_20261028.md` §2.1–2.3. Build report:
`AI_COMMS/act1_completion_20261017/CAVE_CFALL_BUILD_20261028.md`.

## CFALL (room 32)

`tools/prepare_cave_cfall_room.py` pins the contract in `scripts/lol2/cave_cfall_source.json` and stages local media in
`assets/lol2/generated/cave_cfall/` (background `cfall_.ogv`, cues `cue_2_20/26/55.wav`).

- **Entry.** L1 stream 0: regions 1815/1817/1818 event 2 (grounded entry), groups 2040/2070/2100 =
  `0c03ca002000` (op12 → ED6D0(0x20), the room loader; indices ≥ 46 are refused) and an op18 player placement, flags
  0x0885: (536, 11154), (531, 11157), (527, 11158), heading 20753. Room 32 is `cfall_` (LOLG.DAT room-name list,
  anchors chut_ 14 and text_ 44).
- **Room DLL `CFALL_.WOM`** (callbacks as in the Thieves' Den decode):
  - 1 setup: hotspot 0 (334,301)-(639,399), hotspot 1 (158,350)-(349,399): the pool;
  - 9 first update: ambient_start(344, 130); while flag 5 is clear: set flag 5, cue movie(2, 26, 24);
  - 4 click on either hotspot: host slot 0x58(5) = D6A08(player, 5) (heal 5, capped; nothing when dead), cues
    movie(2, 55, 24) and movie(2, 20, 24), set flag 6. Every click, no latch;
  - 8 leave: exit_room (the region group's op18 then places the player);
  - 2 teardown: remove hotspots, stop ambient 344; 10: cancel_timer; others nothing.
  - Flags 5 and 6 are used by no other room DLL (47 scanned).
- **Port.** `cave_cfall.gd` (effects per callback, saved state `cave_cfall` = flags 5/6) and `cave_cfall_room.gd`
  (CanvasLayer on the Cave host: pauses the world, takes the host's `video_overlay` gate, loops the background, plays the
  cues in order, Back/Escape between cues, op18 return). Correction: `cave-side-chamber.md` read op12 as audio; it is the
  room loader.

## FLOOD (prop83 chain)

`tools/prepare_cave_flood_movie.py` → `scripts/lol2/cave_flood_source.json`, `assets/lol2/generated/cave_flood/flood.ogv`.
g146 (prop83 kind-8 value 956) command 2 is `150366021d00`: op21 on prop614, movie 29 = `flood`, L1_DCI entry 14
(200 frames, 640×400). `cave_prop83_lift.gd` plays it through `cave_flood_movie.gd` at the chain transition.

## Lever 67 → gate 71

`tools/stage_cave_lever67_gate71.py` adds movables 67/71 (native constructor fields from the placement bytes, checked
against the committed eight and the native replay) and groups 12490/12514 (lever kind-4 use, as 64–66) and
12556/12562 (gate 71 kind-6 value 15/16: op197 sub5/sub4 on region 1143) to the guard encounter. Saves made before
r12m (eight movables) gain the two at rest. Not run: lever 67's kind-6 value-20 record (see DEVIATIONS).

## Tests

`cave_lever67_gate71_test`, `cave_flood_movie_test`, `cave_cfall_room_test` (headless); `cave_cfall_live_test`,
`cave_prop83_lift_live_test`, `cave_stalactites_prop83_test` (rendered; the last two now skip FLOOD after the chain).
