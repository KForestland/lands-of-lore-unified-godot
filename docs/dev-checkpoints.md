# Named development checkpoints

A named checkpoint starts a development session from one archived, earned save. It does this through the production
resume path, in a fresh, isolated userdata, with the diagnostics panel enabled. It is not a state editor: only
catalogued saves pinned by sha256 can be used.

## Use

```
python3 tools/dev_checkpoint.py list
python3 tools/dev_checkpoint.py prepare --from <project> --to <new copy>
python3 tools/dev_checkpoint.py run jungle-from-museum --project <new copy> --prepare-from <project> --dry-run
python3 tools/dev_checkpoint.py run jungle-from-museum --project <owned copy> [--display :N] [--timeout S]
```

The tool only runs on a **disposable copy that it prepared itself**. `prepare` (or `run --prepare-from`) copies a project
to a NEW directory, without `.git`, `tmp` and `.pytest_cache`, and writes `.dev_checkpoint_owner.json` recording that
exact path. Main, candidates and owner playtests are only read; they lack the marker and are refused, so they are never
modified, not even for the duration of a run. A missing `.git` is not taken as proof of a disposable copy.

`run` does the following:
1. It refuses, before writing anything:
   - an unknown or unsafe name, an unsafe stamp, or a catalog resume path other than the area's production path
     (`user://saves/<file>.json`; absolute, traversing or nested paths are rejected);
   - a missing source, or a source whose sha256 differs;
   - a project that is not an owned copy at exactly that path, or whose path is or contains a symlink;
   - an `override.cfg` that is a symlink or not a regular file, that already has an `[application]` section, or that
     still holds an unrestored previous run;
   - an existing target userdata;
   - a second run on the same copy (lock), or any process already running with `--path <copy>`.
2. It records `override.cfg` exactly: existed or not, bytes, mode and sha256.
3. It creates a **fresh** userdata `lol2-checkpoint-<name>-<UTC>` and copies the save to the area's production resume
   path (Jungle: `user://saves/jungle_quicksave.json`). It writes `checkpoint.json` (provenance) beside it.
4. It appends `use_custom_user_dir` and that name to the copy's `override.cfg` (no symlink following).
5. It starts the production original-game gate (`res://scenes/lol2/original_game_gate.tscn`) through
   `flatpak run --die-with-parent` with `--dev-diagnostics --original-game-exe=…`. Click **Resume jungle**: the gate's
   own `read_save` → `assets_ready` → resume meta → scene change loads it, and F7 shows the diagnostics.
6. When Godot exits, after `--timeout` (exit code 124), or when the launch fails, it stops only the processes it owns:
   the launcher's descendants and processes started with `--path <copy>`. It sends SIGTERM, then SIGKILL.
7. Only when none of them is alive does it restore `override.cfg` byte-exact (an empty file stays an empty file, CRLF
   stays CRLF, and the mode is kept), or remove it if it did not exist. If an owned process survives, the isolation
   config stays in place, and the run is REFUSED with the PIDs. The next run then refuses until it is restored.
8. It checks that the source save is unchanged.

`--dry-run` prints every step and writes nothing.

## Isolation (verified with Flatpak Godot)

- Flatpak Godot ignores `XDG_DATA_HOME`: `user://` stays
  `~/.var/app/org.godotengine.Godot/data/godot/app_userdata/<config/name>`.
- A custom user dir in `override.cfg` does work: `user://` becomes `~/.var/app/org.godotengine.Godot/data/<name>`.
  Each run gets a new name.
- Owner and user saves (`app_userdata/Lands of Lore Unified Godot`, `lol2_playtests/*/userdata`) and the archived
  sources are only read.
- Exported builds use `XDG_DATA_HOME` instead (R16 `play.sh`). This tool targets source copies.

## Catalog (`tools/dev_checkpoints.json`)

Each entry records:
- the area, save format, scene, gate button and resume path;
- the absolute archive `source` and its `sha256`;
- `provenance`: kind, campaign, leg, proof, proof input hash and method;
- `supplied`: the labels of any supplied state. It is empty for earned saves; a supplied checkpoint must list them and
  be a separate entry.

The first entry is **jungle-from-museum**: R16 fresh campaign leg 2, `act1_broken_museum_jungle.json`, sha256
`125fcbc5…`. It was earned by the lead's automated route driver (steering and an accelerated clock; no position,
inventory, quest or magic injection, per the proof `museum-broken-sword-earned-checks`).

The other 10 R16 saves are inventoried with matching manifest and proof hashes and a linked chain, but are not
catalogued yet. See `classic_review_20261007/opus/dev_checkpoints_20261012/inventory.json`.

## Tests

- **`tools/test_dev_checkpoint.py`** (29 unit tests, temporary directories and the tests' own `sh`/`sleep` children
  only):
  - the fresh userdata, verified copy and receipt; dry run;
  - `override.cfg` byte-exact restore: unchanged, absent, empty, CRLF without a trailing newline, and mode;
  - symlinked `override.cfg` (live and dangling) and a symlinked project path are refused, and the target is untouched;
  - unsafe resume paths (including `user:///tmp/checkpoint-outside.json`), names and stamps are refused;
  - ownership: a non-git project without the marker is refused and left byte-identical, a copied marker is refused,
    `prepare` makes a new copy and leaves the source alone, and `run --prepare-from` works;
  - restore after a raised launch error and after a missing Godot binary;
  - a timeout (124) stops a grandchild in the same session and one in its own session, then restores. An r1-style
    `subprocess.run` timeout is kept as a negative control: it orphans the grandchild;
  - a surviving owned process keeps the isolation config, and the next run refuses;
  - concurrency: a held lock, or a process on `--path <copy>`, refuses the run;
  - refusals kept from r1, and the real catalog is pinned and labelled.
- **`tests/dev_checkpoint_resume_test.gd`** (rendered; run only through the tool with
  `--script res://tests/dev_checkpoint_resume_test.gd`):
  - it is running in the checkpoint's userdata, and the resume save hash matches;
  - a real click on the gate's "Resume jungle" reaches the Jungle;
  - `Continuity` shows no difference from `from_save(file)`. The one exception is mana, which may only rise by what the
    measured simulated time since the click (plus 2 frames), together with the save's carried `regen_elapsed`, allows
    (`Continuity.mana_allowance`). The live regeneration clock must agree with that mana. `magic.mana` and
    `magic.maximum` must both be present in the save; there is no default maximum;
  - an in-run negative control checks that a reset to full with no elapsed time is rejected by the same rule;
  - the F7 panel reports the area as ready;
  - one screenshot.

## Limits

- One checkpoint so far, the Jungle.
- jungle-from-museum is saved at mana 19/20 with 2.8 s of the 3.0 s period already carried. Any 0.2 s of play
  legitimately refills it, so for this save the rendered run cannot tell a reset to full from regeneration. The run
  prints whether a reset was distinguishable. The rule itself is covered by the zero-time negative control.
- The gate needs the original `LOLG.EXE`, which it checks by SHA, as in production.
- Each run leaves its userdata for inspection (`~/.var/app/org.godotengine.Godot/data/lol2-checkpoint-*`). Remove
  them by hand when they are no longer needed. Owned copies are not removed either.
- Process ownership is found through `/proc` (descendants are sampled while running, plus exact `--path <copy>`
  matches). A process that both leaves the tree and drops `--path` within one poll (0.25 s) would not be seen.
- Resume loads through `apply_save`, so the diagnostics "last operation" stays "none" (only quicksave/quickload are
  recorded).
