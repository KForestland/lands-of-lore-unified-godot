# Playtest starts

Start the game at a story checkpoint instead of replaying hours. Each start is a **real earned save** written by the automated campaign/route tests (no hand-made state), pinned by sha256. This is a dev/playtest convenience. It changes no Classic gameplay, so it has no DEVIATIONS row.

## Using it

At the opening screen (the original-game gate), press **F2** or click **Playtest starts (F2)**. A plain list of titles appears in story order. Pick one to start there. **F2** or **Esc** closes the list. The list text follows the UI size setting (150% by default).

- The game opens the save through the gate's normal area resume ("Resume museum / jungle / Hive / darker jungle / Dark Halls"). It uses the same reader, validator, resume meta and scene. The only change is that the save path for that one call is the staged `res://` file.
- Your own quicksaves are not read or changed. Pressing F5 afterwards saves to the normal area quicksave, as always.
- `--playtest-starts` (after `--`) opens the list at launch. Without it, a fresh profile with a remembered LOLG.EXE goes straight into the Cave, as before. `--playtest-start=ID` starts one entry directly.

## Files

| File | Role |
| --- | --- |
| `scripts/lol2/playtest_starts.json` | Committed manifest: ordered `{id, title, act, area, resume, save, sha256, source, identities}` |
| `scripts/lol2/playtest_starts.gd` | Manifest loader, resume kinds (`museum`, `jungle`, `hive`, `darker`, `dark_halls`), sha check, game reader per kind |
| `scripts/lol2/original_game_gate.gd` | Button, F2 list, `start_playtest(id)` |
| `assets/lol2/generated/playtest_starts/` | Staged saves (generated, git-ignored). Exported through the `assets/*.json` include filter |
| `tools/prepare_playtest_starts.py` | Producer: copy, sha check, game validation, stage |
| `tools/validate_playtest_starts.gd` | Godot side of the producer's validation |
| `tests/playtest_starts_test.gd` | Headless test: staged, pinned, valid, and every entry resumes into its scene at the saved position |

## Staging (after a fresh checkout or a new campaign)

```
python3 tools/prepare_playtest_starts.py \
  --from ~/AI_COMMS/act1_completion_20261017/r12z_qualification/campaign/userdata \
  --godot tmp/godot_host_starts.sh
```

The tool refuses, with exit 1 and nothing staged, in these cases:

- an id that is not in the manifest;
- a missing file;
- a file whose sha256 differs from its pin;
- a file the game's own validator rejects.

Rows whose file is not staged show "(not in this build)" and cannot be chosen.

## Adding entries (Act 2 after r13)

1. Run `python3 tools/prepare_playtest_starts.py --describe FILE`. It prints the sha256, the format, the resume kind and a skeleton for the fields below.
2. Append an entry to `scripts/lol2/playtest_starts.json` in story order. Every entry must pin:
   - `sha256` of the save;
   - `source.test` (the producing test) and `source.commit` (the full 40-hex commit it ran on);
   - `source.input_sha256`: the sha256 of the save that leg started from (`null` only for a new-game leg). Astra's `*_qualified_save.json` files already record their input sha; copy it;
   - `identities`: the persistent identities the save must carry at that point. `contains` and `excludes` map a dotted path (for example `inventory.collected`) to values that must or must not be in that list. `values` maps a dotted path (for example `quests.monastery.globals.GV_HAS_RUNES`) to an exact value; numbers are compared numerically.

   The manifest loader refuses an entry that is missing any of these fields. The producer and the test check `identities` against the save's contents.
3. Stage it with `--from DIR --only ID`, then run `tests/playtest_starts_test.gd`. Update its expected entry count.

Astra's Act 2 saves (`~/opus_work/lol2_astraprogression/tmp/*_qualified_save.json`) mostly have the format `lol2-restoration-map-<AREA>`. r12z has **no** gate resume branch for map saves: map packs only start at their arrival as a "Preview". `--describe` therefore reports them as UNSUPPORTED, and the manifest refuses any unknown `resume` kind. Once r13 brings the Act 2 code, add the following:

- a production map-save resume branch in the gate. For example, read with `act2_save.gd` and the area's format, then set a resume meta that `act2_map.gd` applies through its own `apply_save`/load path, the same way as the other areas;
- a `map` kind in `playtest_starts.gd` `KINDS`, which needs the scene from `act2_maps.json`, plus `KIND_BY_FORMAT` in the producer;
- the entries themselves.

Saves in an existing format (for example `l12_gulch_return_qualified_save.json`, `lol2-restoration-darker-jungle`) need only the entry, but only on a build that has the Act 2 code they were earned with.
