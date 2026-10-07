# Act 1 source and reproduction

Commit34873b5 contains the runtime scripts and scenes staged for the October 7 R3 candidate. Current source also includes the subsequently reviewed [three-spell Dawn integration](dawn-modern-spells-checks.json), which is not in the R3 binaries. [The source manifest](act1-r3-source-manifest.json) pins the published runtime, tests, numeric fixtures and selected tool entrypoints. The older files under `patches/` are historical review artifacts; do not apply them over this integrated tree.

R3 is a technical QA candidate, not an accepted Act 1 demo. [Package checks](act1-r3-package-checks.json) cover Linux movement, disk save/load, restart, Jungle resume and all16853 packed asset hashes. Linux and Windows exports have the same PCK hash; native Windows execution, representative GPU/audio review and Bob acceptance remain open. The fresh continuous campaign passed all11 linked legs with no source drift ([archive](act1-r3-campaign-checks.json)). [Current content gaps](playtest-notes-20261007.md) remain explicit.

Current R4 adds the integrated three-spell source and has passed the full256 suite, all11 fresh campaign legs and packaged Linux cave/Jungle save checks. Both R4 exports completed; [R4 package evidence](act1-r4-package-checks.json) and [campaign archive](act1-r4-campaign-checks.json) identify the exact candidate. The R3 manifest above is historical and is not a hash manifest for subsequent source changes.

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
python3 tools/verify_demo_stage.py --output /path/to/candidate --templates /path/to/templates
godot --headless --path /path/to/candidate/project --export-release Linux /path/to/candidate/Linux/LoL2-Cavern.x86_64
godot --headless --path /path/to/candidate/project --export-release Windows /path/to/candidate/Windows/LoL2-Cavern.exe
```

The verifier requires Python3.11+ and records source, asset, template, project and preset hashes in `source_asset_manifest.json`. It rejects changed/missing/extra staged inputs, incorrect raw media rules, missing original-game export gating and mismatched template paths. It refuses to replace an existing manifest; `--manifest` selects a fresh receipt path, and `--source` selects an explicit source checkout. [Verification evidence](demo-stage-verification-checks.json) covers eight targeted cases, the complete R3 inputs and rejection of mixed source revisions. This replaces the earlier machine-specific fingerprint script.

Run exports sequentially because they share the import cache. Each executable requires its adjacent PCK. The packaged launcher asks for the supported installed original `LOLG.EXE` and verifies it locally. Source/editor scenes use the same runtime with the development gate bypass.

This is a verified local export procedure, not yet a clean-machine extraction recipe or a claim of byte-reproducible exports. Several asset-generation tools still rely on external extraction workspaces. Publishing and making that preparation pipeline portable remains required release work.

## Checks and remaining portability work

The exact public checkout passed the three asset-free regressions below without original media:

```sh
python3 tools/run_regressions.py --test dawn_ai_decision_test --test dawn_player_damage_test --test dawn_combined_damage_test
```

The R3 baseline had252 registered tests; current source has256 (143core and113Hive). The complete all-suite registration, Godot test scripts and numeric fixtures are included. The complete256-test suite now passed with unchanged source ([evidence](act1-full256-checks.json)); these are local prepared-asset results, not a claim that all tests run without assets. Rendered checks require the generated media and Xvfb; some older capture/launcher tests still refer to local paths. `run_isolated_regressions.py` accepts `--xvfb`; the fresh campaign currently uses Flatpak Godot and local save-audit paths. Those portability limitations are not hidden by the asset-free results.

The eleven-leg campaign entrypoint is `tools/run_act1_fresh_chain.py --out <fresh-directory> --demo-interface`. It uses actual save handoffs and preserves per-leg logs. Its receipt auditors and numeric fixtures are published; generated receipts certify their recorded run only, and personal/earned save files are not distributed here.

The atlas reader now uses repository-local `tools/lol2_source_format.py` for MIX framing and the37 command lengths. It no longer imports the external geometry/progression readers or their Capstone dependencies. [Parity evidence](atlas-portability-checks.json) covers all15 level archives, six malformed/boundary tests and17 byte-identical atlas outputs under standard-library-only Python. Full atlas generation still requires the coverage/evidence documents and local archives; this does not make all sprite/audio extractors portable. The legacy external helper search path is retained for other preparers importing the atlas module until those callers migrate.

## Standalone creature audio preparation

The shared AUD stager can now regenerate selected original cues using only Python's standard library, FFmpeg on PATH, and the installed `LOCALLNG.MIX`. It no longer imports wax/sprite preparers or native-analysis packages. From the checkout, select a fresh isolated output root:

```sh
python3 -S tools/prepare_creature_audio_clips.py --game /path/to/original-game --output-root /path/to/audio-stage --folder cave_captain_audio --request 1031
```

Repeat `--request` to decode additional sound-bank IDs. WAVs and `audio.json` are written below `assets/lol2/generated/<folder>`; extracted AUDs remain below `tmp/<folder>`. The original bank hash is required. This standalone manifest lists clips and provenance; encounter-specific generators still supply cue/event bindings. Existing Python callers retain `stage_clips(root, folder, requests, names)` and can pass keyword `game=` or set `LOL2_GAME_ROOT`; the historical local default remains for compatibility.

[Audio portability evidence](audio-portability-checks.json) verifies58 distinct requests against69 existing WAVs, all byte-identical, with only the two repository Python files in the isolated tool directory and `python3 -S`. Five input tests cover missing/duplicate/wrong banks, request bounds and output-folder escape. Original media stays local. This closes shared AUD extraction portability, not sprite/movie extraction, the entire clean-machine build or audible playback acceptance.
