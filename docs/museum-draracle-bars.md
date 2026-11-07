# Museum Draracle-wing bars and control79 (2026-10-19)

Owner report 11:08 (R19), second half: "… and then barred". Follows docs/museum-draracle-videos.md.

```sh
python3 tools/prepare_museum_draracle_bars.py --game ~/lol2_runtime_root \
  --map ~/lol2_out/all_maps_20260922/L3_DH --output scripts/lol2/museum_draracle_bars_source.json
```

Writes the contract and `assets/lol2/generated/museum_draracle_bars/` (textures 431/433, sounds 394/312). Wrong archive
or movable export exits 1 before any output.

## Source (L3_DH)

- **Region1174** (x -3672..-3223, port z -1152..-1024, floor 0, ceiling 120): the hall east of the bar line. Event2
  (grounded entry) record `080c540596040200`, predicate45 `local17 == 0`, group1364 (19 commands, pinned).
- **Hosted g1364 commands, in order:** `012047006400`..`01204a006400` (op1 kind32 movables 71-74 → 100 percent),
  `c60000001101` (op198 local17 = 1), `01204d000000` (op1 kind32 movable77 → 0).
- **Bars 71-74** (template55, x -3789, z -1122/-1100/-1076/-1052, height -120). Constructor fields as replayed natively
  by `cave_kenneth/verify_encounter_movables.py`: byte34 mode0 (raises), byte36 travel100, byte37 speed40, byte38
  initial0. At rest they sit in the floor slots (top at y=0); at 100 percent they stand y=-20..100 across the doorway.
  No other group moves 71-74. Gate77 (template58, angular mode6) is opened only by the prop107 sword groups.
- **Control79** (template65, (-3625, 0, -372), the pedestal's east edge, no visual): kind4 mode0 (empty hand) under
  predicate55 `local19 == 2` runs g6976 `14104f008a0180000a14` (op20 sound394 "chain4.aud") and `c60000001303`
  (local19 = 3). Its event8 value394 record runs g6998 `14104f003801ff811200` (op20 sound312 "0202424e.aud").

## Port

- `museum_draracle_bars.gd`: edge-triggered region1174 entry while local17 == 0 runs the hosted commands. The bars
  reuse `cave_guard_movement.gd` / `_state.gd` (native percent target, 16.16 travel, 60 ticks/s) with this source;
  the bodies give collision. `museum_gate.close()` returns gate77 through its existing modern hinge.
- Control79: E with an empty hand, aimed within the host's `can_reach_item` cone at the placement +40, at local19 2
  plays sound394 and sets local19 3; the end of sound394 plays sound312.
- Saved as `checkpoint.museum_draracle_bars = {"version":1,"local17":0|1,"movement":…}` (optional; local17 0 requires
  untouched bars). Draracle local19 now validates 0..3.

## Adapters (disclosed)

- Grounded entry tolerance as region1220; bar speed clock from cave_guard_movement_state (native clock not replayed).
- Gate77 close uses the existing modern 1.2 s hinge.
- Control79 aim point (+40) and "event8 value394 = sound394 finished"; sound clocks are not saved.
- Saves without the field restore bars down, local17 0 (a legacy player past region1174 sees the bars rise on re-entry).

## Not hosted

g1364 op206/op210 (music), control82 op6/op8/op9 and props 136-139 op6 sub2/op9 property16; op20 trailing bytes.

## Checks

`museum_draracle_bars_test` (registered, rendered): control walk west passes the lowered bars; actual walk east into
region1174 runs g1364 once (targets 100·65536, bars at -20 after 70 ticks, gate77 closes); re-entry changes nothing;
the raised bars stop the same walk; mid-travel save/restore finishes travel; seven malformed states refused; legacy
save restores bars down; control79 refusals (local19 1, looking away, held item), 394 → 312, local19 3 save.
Negative control: `enter()` disabled fails at "Region1174 entry did not run g1364".
