# Act One testing workflow

The published runner includes the asset-free portable test:

```sh
python3 tools/run_regressions.py --suite portable
```

The active local Act One checkout also registers rendered gameplay tests. Rendered tests start on a private Xvfb display by default; those gameplay scripts and original media are not included in this publication.

Supply `--display :0` only when deliberately testing on the desktop. Headless tests do not require Xvfb. The wrapper uses Xvfb on PATH, a supplied `--xvfb` path when invoked directly, or this workspace's locally extracted binary under ignored `tmp/virtual-display`. It owns and cleans up its display. Software rendering isolates focus/input interference; representative GPU visuals still require separate review.

Godot script errors terminate their test process group after preserving the error and backtrace. Ordinary engine errors remain in the log and fail the result without being hidden. Timeouts still terminate hung tests. Five runner checks cover success, script-error hangs, timeouts, closed-output hangs and retained ordinary-error output. An intentional Godot assertion verified the fast-failure path in0.71seconds; a real rendered Museum interaction passed under automatic isolation.

Work in observable behavior slices and reuse the shared inventory, dialogue and save owners. Use native replay when a specific unresolved behavior blocks implementation. Model assignments should identify one behavior, owned files, early findings and an explicit verification deliverable. Keep broader Act One acceptance separate from focused green checks.
