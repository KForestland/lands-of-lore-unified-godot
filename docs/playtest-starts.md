# Playtest starts

At the opening screen, press **F2** or choose **Playtest starts (F2)**. The list contains11 existing Act1 points and10 Act2/3 checkpoints. F2 or Esc closes it. The scrollable list follows the UI size setting. Under the later U-06 task these starts move into debug mode; C-15 retains the current F2 entry point.

Act2/3 starts restore Luther to the existing full-health value (**30** on this foundation branch), on a detached copy of the loaded state. The pinned file is never healed or rewritten. The shared teaching table also restores the spell capabilities appropriate to that chapter on the detached F2 copy (see `g15-spell-teaching.md`). Pack, equipment, mana, fighting/magic progression and saved position otherwise remain from that checkpoint; normal gravity may settle the saved height. Plain area/slot loads retain their saved health. Among the older Act1 entries, only the previously approved end-of-Act1 darker start has its existing full-health flag.

| Act | Level | Checkpoint |
| --- | --- | --- |
| 2 | L8_SJ | Savage Jungle arrival, after the Dark Halls |
| 2 | L9_DR | Dracoid Ruins, pit arrival |
| 2 | L10_DC | Cemetery, main gate opened |
| 2 | L12_CM | Claw Mountains, Larkhon arrival |
| 2 | L13_RC | Citadel of the Ruloi, arrival |
| 2 | L14_HT | Huline Temple, arrival |
| 3 | L16_CA | City of the Ancients, arrival |
| 3 | L17_HC | Huline Caverns, arrival |
| 3 | L19_BC | Belial's Laboratory, after the beast |
| 3 | L20_BB | Birthing Chamber, after birth |

Each file is an actual game-written save from a qualified campaign/earned-route test, copied byte-for-byte and pinned by SHA256. These are **earned test checkpoints, not an unaided whole-campaign chain**. The manifest records producing test/commit, input SHA, qualification proof and inherited aids. Earlier route tests own clocks/camera and invoke production action helpers. The lead explicitly accepts disclosed test aids for these starts. Some late tests use local position/transition aids; the L20 producer supplies native first-visit index52=0 to exercise the unresolved transition and steps the birth clock. These aids are disclosed rather than relabeled as player-earned native evidence. No item, story flag or pose is synthesized. The start adapters are full health and the explicitly disclosed learned-capability backfill; original pinned bytes remain unchanged.

The first five new non-L8 saves come from the immutable Astra pack-up manifest and successful producer rows at `fc1b45c`. Late arrivals come from source-stable reports whose tracked inputs match `b3e384e` (City/Caverns/L19) or `97dce7e` (L20). L8 reuses the existing pinned end-of-Act1 packet under a distinct staged filename. Exact references/hashes live in `scripts/lol2/playtest_starts.json`; the qualification handoff preserves the source comparisons.

The gate reads the pin-checked area file through its existing validator, checks saved identities, verifies the original executable, then calls `game_save.resume_checkpoint`. This uses Plan3's normal pending apply, asset admission and failed-load rollback. Preview/exit seeds are disabled. There is no default-map preview masquerading as a checkpoint. The old files predate the whole-game native bank: their legacy limitation remains, so native puzzles on other maps may reset. C-15 does not invent missing VM history. F5 afterwards writes a normal whole-game slot with the current native state. Selecting a start never writes a manual slot or the pinned source. Ordinary eligible map-entry/timer autosaves follow the existing Plan3 policy and can replace the autosave slot.

## Staging and adding entries

- Manifest: `scripts/lol2/playtest_starts.json`, schema1. Generated saves: `assets/lol2/generated/playtest_starts/`, exported through the existing JSON include filter.
- New map entries use `resume: "map"`, a whitelisted `area_id` from `game_areas.gd`, its correct act, and `full_health: true`. Original fixed Act1 resume kinds remain supported.
- `python3 tools/prepare_playtest_starts.py --describe FILE` prints the SHA/format/template. Pin `source.test`, the full producing `source.commit`, and `source.input_sha256` (null only for a real new-game leg), plus useful saved identities. Preserve/disclose any producer aids and the exact story phase.
- Collect the original pinned bytes under their manifest filenames in a prepared donor folder. Run:

```sh
python3 tools/prepare_playtest_starts.py --from /path/to/pinned-files \
  --godot "python3 ~/AI_COMMS/sol_lane/task3_20261109/guarded_godot.py"
```

The tool validates every selected file through the game's own reader before staging anything. Wrong IDs, missing files, altered bytes, unsafe names, bad map/act/health metadata, wrong formats or wrong saved identities refuse. `--only ID` limits staging; `--dry-run` validates without staging. Unstaged/changed pins disable the corresponding F2 row.

C-15 qualification uses private profiles/displays and the sole memory/count/Dummy launcher. `playtest_map_starts_test` exercises all10 by actual F2/Enter; `playtest_map_starts_rendered_test` starts the Cemetery, City and L19 with list/scene images. The adapter test checks copy-only healing, no-heal/ordinary-slot controls and refusal cases. The private tests disable autosave and hold post-apply clocks for load comparisons; these tests do not earn new walking evidence. Existing11 Act1 starts and the old darker/full-health distinction remain affected checks. Registry counts are audited source sites, not executions. No broad campaign sweep is required.
