# Whole-game saving (foundation Plan 3, F-06/F-07)

This stack follows FOUNDATION_PLAN.md revision 2 on Plan 2 `4cfd4f8`. It is held for the foundation phase after Thursday r19.

`GameSession` owns the native bank, exit-seed option, play time, selected slot and pending resume. `game_save.gd` is the static file/slot API. `game_areas.gd` pairs the fifteen existing playable areas with their existing validators and scenes. Jungle and the Act 2 return to Jungle keep their actual scene variant.

F5 saves to the last selected manual slot (initially 1). F9 loads it. Tab → Character → Save/Load opens the shared list; saving over an existing primary asks once. Opening Continue selects the newest valid primary, falling back to a verified backup when its primary is unusable. Opening Load uses the same list and includes old saves. The list uses the existing Atlas place names and coalesces an identical automatic label and area name. Remembering the executable path cannot auto-start over a slot or backup. Original executable verification still runs before opening-screen loading.

## Files and versions

`user://saves/slot_01.json` through `slot_10.json`, plus `autosave.json`; each has a `.bak` containing its previous verified bytes. New saves have outer format `lol2-game`, version 2:

```json
{
  "format": "lol2-game", "version": 2,
  "written_unix": 1794300000, "play_seconds": 5321,
  "label": "Dracoid Cemetery", "area": "L10_DC",
  "scene": "res://scenes/lol2/maps/L10_DC.tscn",
  "area_save": { "format": "the area's existing format", "version": 1 },
  "native_bank": {},
  "session": { "options": { "adapter_exit_seeds": false }, "last_slot": 1 }
}
```

The illustrative `area_save` and bank are abbreviated. Each area packet is the dictionary its legacy writer produces. The generic shared packer runs the existing checkpoint and population synchronizers before capture for both slots and legacy files; fresh-scene parity observes the slot packet before the old writer can mask an omitted synchronization. The Cave keeps inner version 2 and its existing version-1 migration; other current areas keep inner version 1. The outer validator delegates those decisions to the area's own validator. Creature attack indices keep the old accepted 0–2 aliases and additionally accept every index already generated from the source clip table (four HIVEW variants in L14/L17); combat rotation and packet fields are unchanged. A generic-progression area must include its current native bank row. Each bank row has `state`, `locals`, `locals_e58`, `record_state`, and `struck_durability`.

The total cap is 8 MiB, with 4 MiB each for the area packet and native bank. Write a temporary file, flush and re-read/validate it; preserve verified previous bytes in the backup before atomically replacing the primary. A damaged primary does not overwrite a good backup. Higher outer versions are refused clearly.

The ordered 1→2 migration moves `session.adapter_exit_seeds` into `session.options`. `tests/fixtures/game_save_v1.json` is an actual version-1 writer output, pinned by SHA-256 in the migration test. Future saved-shape changes require a migration step and an immutable fixture of the old shape. The fifteen actual d5da60a writer fixtures and separate frozen legacy roundtrips remain under `tests/fixtures/saves_d5da60a/`.

The fifteen legacy files, explicit path APIs and original validators remain available. Loading one through the list starts without a native bank, with the existing other-map reset limitation shown in the row. The first F5 writes the new format. Legacy APIs retain developer-flight/movie packet compatibility; new slot admission refuses those unsafe states.

## Restore order

Validate the complete document and scene whitelist before changing the active scene. Install the bank and options before progression builds geometry. Apply the area packet at the most-specific host's resume boundary, before late area owners attach. The Cave waits for `walkthrough_ready` and its deferred StartingMagic owner. Native restore validates atomically, normalizes JSON string keys back to VM integer indices, deep-copies the maps and emits no effects.

A full bank takes precedence over the old partial `act2_struck` packet; legacy-only restoration remains. The live generic progression currently covers ten Act 2/3 areas. Act 1 retains its existing complete area packets and quest transports. VM setup globals, bindings and event context remain outside the existing five-field bank. The 41 previously uncalled area-owner restores remain disabled.

Explicit loading clears stale arrival/resume requests and the Museum checkpoint cache. The outgoing Museum suppresses its cache write during replacement. An applied Cave→Museum packet is consumed on arrival; later Museum revisits use the complete checkpoint cache. Pre-replacement errors preserve the active game/session. Hive slot resume leaves review mode through the same setter as its legacy resume.

## Autosave

Owner D3 sets ten minutes (600 seconds) of unpaused active play and settled map entry. Entry waits for the handoff/resume and a physics frame. A blocked attempt retries after five seconds. Admission rejects loading/transfers, pause, flight, health zero, air, liquid, movies and active conversation; idle room pages remain saveable.

A measured synchronous write took about 165 ms. Autosave therefore captures a detached packet on the game thread and uses one writer thread for validation/JSON/file operations. The rendered test measured about 3 ms for capture separately from background work. Completion posts one HUD line; the game continues. Manual save/load waits for the writer, and shutdown joins it. Snapshot and completion stay on the game thread; the worker touches only detached data, pure validators and files.

Ordinary regressions pass `--no-autosave`. The dedicated rendered autosave case advances the production `advance_play` clock, retaining live admission and physics. Its substitutions and clock calls are test scope.

## Qualification scope

New restart cases run in private projects and user-data directories, in separate processes. They exercise real E/click/F5/Continue controls and physical rebuilt state. The native door case supplies one unlocked standing start and uses explicit native handoff legs. The whole-game case starts at a pinned BJ14 checkpoint, walks to the tomb and pickup, uses one supplied rail-segment pose and explicit handoff legs, then verifies the pack and physical tomb/rail after Continue. The Cave case supplies a captain-grant packet and two local standing starts, then uses real combat/chain/save/load input. These are local integration tests with declared setup, rather than unaided campaign walks.

All new and affected registry rows carry K82 audited source-site counts and audit digests, explicitly labelled as source sites, not execution counts. `game_save_source_test` guards conventional new host writers and raw session-meta access; the exact existing Cave `view.json` capture line is retained as an audit-output exception. Test artifacts derived from slot inner packets remain explicit, and failed first phases clear old restart receipts.
