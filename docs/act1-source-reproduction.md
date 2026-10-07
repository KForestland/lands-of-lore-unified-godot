# Act 1 R3 source and reproduction

The runtime scripts and scenes in this checkout match the inputs staged for the October 7 R3 candidate. [The source manifest](act1-r3-source-manifest.json) pins the published runtime, tests, numeric fixtures and selected tool entrypoints. The older files under `patches/` are historical review artifacts; do not apply them over this integrated tree.

R3 is a technical QA candidate, not an accepted Act 1 demo. [Package checks](act1-r3-package-checks.json) cover Linux movement, disk save/load, restart, Jungle resume and all16853 packed asset hashes. Linux and Windows exports have the same PCK hash; native Windows execution, representative GPU/audio review and Bob acceptance remain open. The continuous campaign is still being verified. [Current content gaps](playtest-notes-20261007.md) remain explicit.

## Open the source checkout

Use Godot4.7.2. Without generated assets, opening `project.godot` displays setup information. This path was checked on the exact public source with:

```sh
godot --headless --path . -- --setup-smoke
```

The local verification used `flatpak run org.godotengine.Godot` as the Godot command. The full runtime is now published, but original game media, original executables, personal saves, generated asset packs and export templates are excluded.

## Build with already prepared local assets

This recipe requires the matching locally generated `assets/lol2/generated/` tree and Godot4.7.2 release templates. The template directory must contain `linux_release.x86_64` and `windows_release_x86_64.exe`. Choose a fresh output directory.

```sh
python3 tools/prepare_standalone_demo.py --output /path/to/candidate --templates /path/to/templates
godot --headless --path /path/to/candidate/project --export-release Linux /path/to/candidate/Linux/LoL2-Cavern.x86_64
godot --headless --path /path/to/candidate/project --export-release Windows /path/to/candidate/Windows/LoL2-Cavern.exe
```

Run exports sequentially because they share the import cache. Each executable requires its adjacent PCK. The packaged launcher asks for the supported installed original `LOLG.EXE` and verifies it locally. Source/editor scenes use the same runtime with the development gate bypass.

This is a verified local export procedure, not yet a clean-machine extraction recipe or a claim of byte-reproducible exports. Several asset-generation tools still rely on external extraction workspaces. Publishing and making that preparation pipeline portable remains required release work.

## Checks and remaining portability work

The exact public checkout passed the three asset-free regressions below without original media:

```sh
python3 tools/run_regressions.py --test dawn_ai_decision_test --test dawn_player_damage_test --test dawn_combined_damage_test
```

The complete252-test all-suite registration (139core and113Hive), Godot test scripts and numeric fixtures are included. This does not mean all252 passed on this revision or that all tests run without assets. Rendered checks require the generated media and Xvfb; some older capture/launcher tests still refer to local paths. `run_isolated_regressions.py` accepts `--xvfb`; the fresh campaign currently uses Flatpak Godot and local save-audit paths. Those portability limitations are not hidden by the asset-free results.

The eleven-leg campaign entrypoint is `tools/run_act1_fresh_chain.py --out <fresh-directory> --demo-interface`. It uses actual save handoffs and preserves per-leg logs. Its receipt auditors and numeric fixtures are published; generated receipts certify their recorded run only, and personal/earned save files are not distributed here.
