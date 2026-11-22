# Prepared worktree inputs (F-03)

From a prepared checkout, stage another existing worktree in one command:

```sh
tools/stage_worktree.sh /path/to/new-worktree
# Or run from the new checkout and name the prepared donor:
tools/stage_worktree.sh /path/to/new-worktree --from /path/to/prepared-checkout
```

This copies generated media (including all four liquid packs), native script JSON,
untracked materials, chain/checkpoint and owner-save JSON, the target tests’ literal
JSON fixtures, pinned earned anchors, and the donor’s `user://tests` inputs. It does
not generate missing original data. Missing liquid packs, native exports, user test
inputs, or hash-pinned anchors fail before installation. An explicit
`--userdata /path/to/Godot-user-directory` can select the directory containing `tests/`.
Otherwise the donor’s staged directory, conventional `tmp/userdata/<project-user-dir>`,
and current XDG/default user directory are tried in that order.

Copies are independent files. Tracked destination files keep their revision;
existing differing files and destination symlinks are refused before copying. An
identical repeat succeeds. No launchers, engines, personal profiles/settings, or
non-test user saves are copied. Owner saves under the project’s prepared input
folders are copied privately; never commit these or generated original media.

The JSON manifest at `tmp/staged_inputs/manifest.json` records each source, category,
size and SHA-256. `--dry-run` previews without writes; `--check` verifies the installed
bytes. Run `--check` before tests: tests can legitimately replace chain saves and
user test outputs afterwards, so a subsequent mismatch is not evidence of staging
failure. Preserve or move such generated outputs explicitly before restaging;
the tool will never overwrite them.

The standard regression runner automatically sets its child `XDG_DATA_HOME` to
`tmp/staged_inputs/userdata`, making `user://tests` private to the new worktree.
For manual engine launches use that same XDG value. Engine paths, displays,
externally named environment fixtures and absolute paths embedded in a test remain
explicit dependencies. Staging never launches Godot or relaxes lane resource limits.
Use the lane’s single guarded Dummy-audio launcher for every subsequent run.
