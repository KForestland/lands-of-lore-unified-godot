# Development diagnostics panel

This is a development-only report of where the player is, the actual player state, a bounded quest summary and the
last save, load or transfer outcome. It reuses the `PlaytestLocation` overlay (F8 copy-location is unchanged) and the
continuity projection (`player_continuity.gd`). It adds no new state owner and no new save field.

## Use

- **Opt in:** run with the user argument `--dev-diagnostics` (`godot … -- --dev-diagnostics`) or the environment
  variable `LOL2_DEV_DIAGNOSTICS=1`. Without it, F7 does nothing and passes through to the game.
- **F7** opens the panel. The report is captured once on opening:
  - the game is paused;
  - the mouse is shown.
- **Refresh** captures the report again.
- **Copy report** puts the report on the clipboard. Nothing is copied automatically.
- **F7 or Close** restores the previous pause and mouse state exactly. A game that was already paused stays paused.

F7 was checked before choosing it: there is no project input map. Key handling is in code, which uses F, F3, F5, F8,
F9 and letters. F7 appears in no script or test.

## Report contents and exact sources

| Line | Source |
|---|---|
| Area / status | The host script or a base script: `cave_walkthrough.gd` (incl. `cave_encounter.gd`), `museum_walkthrough.gd`, `jungle_walkthrough.gd` (incl. `darker_jungle.gd`), `hive_review.gd`. Other scenes are "unsupported". The status is "loading" until the host is in the tree, ready and has a `player`; the Cave also needs `walkthrough_ready`. |
| Location | `player.position` (X/Z horizontal, H height); Cave subtracts `native_translation`, as the F8 overlay does. |
| Vitals | The observed health from the live owner, with an alive/dead/unknown status. Cave: `roach.model.player_health` ("unknown" without cave combat), dead also when `drowning.dead`. Museum/Jungle: `health`. Hive: `Warriors.health`. Unlike the Player line, this shows zero and death (the Hive travel packet omits health at 0). |
| Player | `Continuity.from_packet` over: Cave `_completion_state()`; Museum `inventory_state()` + `quest_state`; Jungle `inventory_state()` + `quest_state`; Hive `carried_inventory` + `player_form` + `curse.snapshot()` + `Warriors.health` (if > 0) + `player_magic_checkpoint` + `player_reward_checkpoint`. |
| Quests | Cave: live `chamber_arrival_state` (not `_completion_state().chamber_complete`, which is a departure constant). Museum: `introduction_state`. Jungle: `quest_state.monastery.room` and its `locals`. Hive: `wax.collected` and `monastery_checkpoint.locals`. Locals are sorted and limited to 20; `monastery.truncated` counts the rest. All: the sorted names of the quest owners (`quest_state` / Hive `carried_quest_checkpoint`), at most 40, plus their count. Values of other owners are not dumped. |
| Last operation | `dev_diagnostics.gd` `record()`, kept for the process: operation, area, outcome (ok/refused), reason, and seconds before the capture. The age uses the report's `captured_msec`, so formatting the same report always gives the same text. |
| Route refusal | `HiveRoute.last_error`, read only. HiveRoute departure and arrival refusals show no message. |

The Hive is not read through `area_handoff()`, because that call writes `curse.requests_enabled()` into
`hive_curse.checkpoint`. It also gathers about 20 world checkpoints.

`capture()` calls only the duplicate-only packers listed above:
- Cave `_completion_state()`, with `carried_items()`, `player_fighting_transport.pack()` and `curse.snapshot()`;
- Museum and Jungle `inventory_state()`.

Nothing is sampled per frame.

## Recorded operations

| Operation | Where | Includes |
|---|---|---|
| save / load | Cave `_quicksave`/`_quickload` (also reached by F5/F9 and `quicksave()`/`quickload()`); Museum, Jungle, Hive `quicksave`/`quickload`. Each is a wrapper around the unchanged `_quicksave_unrecorded`/`_quickload_unrecorded`. | Early refusals that return without a message, for example "The cavern is still loading." and "Close the current overlay before saving." |
| transfer Cave->Museum | Cave `_enter_museum` | Contract refusal, scene-load failure, leaving |
| arrival Cave->Museum | Museum `_ready`, only when a Cave packet is present | A rejected packet, which until now only logged a warning and started fresh |
| transfer Museum->Jungle | Museum `enter_mirror`, `enter_dragon`, `_finish_jungle_transition` | Validation refusal, missing dragon assets, scene-load failure, leaving |
| arrival Museum->Jungle | Jungle `_ready` handoff | Handoff refusal or ok |

Player-facing messages and all validation semantics are unchanged. Only the outcome is recorded, never a save payload
or path.

## Tests

- **`dev_diagnostics_test`** (headless, component):
  - all six changed scripts compile;
  - the no-scene and unsupported cases are handled;
  - host kinds are recognised, including subclasses;
  - `record()` returns errors unchanged;
  - vitals show zero/dead/unknown;
  - displayed locals are bounded, with a truncation count;
  - the F7 panel needs the opt-in, captures on opening and restores the prior pause state (false and true).
  - Clipboard checks are skipped under the headless display server.
- **`dev_diagnostics_hosts_test`** (rendered, `--demo-interface`, optional `LOL2_EARNED_SAVES`): on the real Cave,
  Museum, Jungle and Hive:
  - Cave reports "loading" before it is ready;
  - silent early save refusals are recorded;
  - real F7 opens the panel, and its text equals the report;
  - player fields equal `Continuity.from_host`;
  - canonical state (the host's own save packer) is byte-identical:
    - synchronously around `capture()` with the tree paused;
    - across the open panel's real Refresh click, screenshot and Copy click.

    Both snapshots are taken while paused, because world clocks advance whenever the tree runs. A probe showed
    3-frame (0.05 s) moves in the Cave eyes/scenic guard, Jungle `regen_elapsed` and Hive curse/nest/ambush clocks
    between unpaused snapshots.
  - the Copy report button copies the exact text, and opening did not copy;
  - F7 restores pause and mouse;
  - one screenshot per host.
  - the refreshed panel text equals `format(report)`;
  - with the opt-in off, F7 does nothing;
  - every save/load wrapper returns exactly what its unrecorded function returns in the same state;
  - Hive at zero health shows "Vitals: health 0, dead" after a real Refresh click on an already-paused tree, which stays
    paused after F7, while the travel projection still omits health;
  - the panel opens and closes over an open Jungle monastery room (supplied entry), leaving the room open and its mouse
    mode unchanged.

## Limits

- Successful HiveRoute travel is not recorded as an operation; only its refusals are, via `last_error`. Darker
  Jungle transfers are not instrumented.
- The quest summary is deliberately small. It names owners rather than explaining them.
- Only the Cave has a measurable "loading" phase in the host test.
- A fresh Hive scene shows no magic/fighting lines until a handoff fills its checkpoints (same as the projection).

## Lead integration verification — 2026-10-12

Integrated after independent6/6 PASS/source-stable (component, four-host rendered panel, continuity chain/restart, Cave transfer and Hive route). Lead made panel alpha fully opaque; final rendered four-host1/1 PASS/source-stable and image inspected. Full tested source matches main except isolated project name. Evidence: `lead/godot_diagnostics_review_20261012/integration_receipt.json`. Earlier failed rendered reports retained. Source only: R16 binaries remain unchanged. This does not integrate pending Museum departure/doorway patches.
