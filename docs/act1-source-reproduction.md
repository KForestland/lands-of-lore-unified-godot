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

## Movie lookup and extraction from existing placement reports

`tools/lol2/map_video_inventory.py` now uses only repository-local MIX, name-hash and VQHD metadata helpers. It accepts explicit paths:

```sh
python3 -S tools/lol2/map_video_inventory.py --game /path/to/original-game --props /path/to/area-reports --resources /path/to/extracted-movies --inventory /path/to/movie-inventory.json
```

The props root must already contain the area placement reports. Only unique area/sphere movie matches are extracted; ambiguous matches remain candidates. [Verification](movie-lookup-portability-checks.json) covers all30 current placements, exact old/new inventory equality,23 extracted movies with matching hashes, seven existing tests and shared media-preparer imports. The clean isolated CLI used only three local Python files and the standard library. Movie decoding and generating the prerequisite geometry/placement reports remain separate portability work. Historical no-argument paths remain for existing callers; use explicit paths elsewhere.

## Standalone raw movie decoding

The shared frame/audio helpers now live in `tools/lol2_movie_media.py`. They require NumPy, Pillow and FFmpeg; the recorded test versions are in [decode evidence](movie-decode-portability-checks.json). Given an extracted supported VQA, choose a fresh output directory:

```sh
python3 tools/lol2_movie_media.py --input /path/to/movie.vqa --output /path/to/decoded-movie
```

This writes raw numbered PNGs, mono `voice.wav` when SND2 audio is present, and `media.json` with input/output hashes, frame/header values and audio sample counts. It refuses an existing output directory. Non-SND2 audio is rejected. Transparency keys, atlas packing, segment metadata and encounter binding remain the consuming preparer's responsibility.

Verification covers101 frames across a partial-codebook movie with audio, a FFmpeg-decoded movie with audio, and a silent partial-codebook movie. Every output PNG/WAV matches the prior helpers; eight decoder tests and existing exit/Bacatta/Dawn consumer imports pass. The isolated CLI contains only the shared helper and VQA decoder, plus installed dependencies. This preserves existing decoder support: for example, partial-codebook4x2 blocks are rejected, not silently claimed as supported. Full media preparation is still incomplete.

## Shared creature sprite preparation

The shared creature preparer now uses repository-local readers for entity/state/view partitions, frame events, LCW/block/row sprites, descriptor groups and palettes. It needs Python and Pillow plus the original area MIX and an already extracted texture blob:

```sh
python3 tools/prepare_museum_creature_sprites.py --game /path/to/original-game --archive DAT/L3_DH.MIX --texture /path/to/museum_texture_blob.bin --definition 0 --definition 1 --definition 2 --output /path/to/fresh-museum-sprites
```

Explicit output directories must be fresh. Existing Python `stage(...)` calls are preserved; keyword `game=` can supply a different installation. The no-argument Museum command and `GAME` export retain historical defaults for compatibility. Older importing preparers still receive the historical RE helper search path for their own dependencies; the standalone command does not import those helpers.

[Sprite evidence](sprite-portability-checks.json) records1397 regenerated indexed frames and1403 byte-identical files (including palettes and complete manifests) across Museum definitions0/1/2, Jungle Bacatta5 and guard9. Six asset-free boundary tests and five existing consumer imports pass. The isolated command used only three repository tools plus Pillow. This does not yet extract texture blobs or make the whole asset-generation pipeline portable.

## Extract Act1 texture blobs from original archives

Texture extraction now needs only three repository Python tools, the original area MIX and system `liblzo2`. The supported hash-pinned profiles are `L1_DC`, `L3_DH`, `L4_HJ` and `L5_HC`:

```sh
python3 -S tools/decode_level_texture.py --game /path/to/original-game --area L1_DC --output /path/to/fresh-cave-texture
python3 tools/prepare_museum_creature_sprites.py --game /path/to/original-game --archive DAT/L1_DC.MIX --texture /path/to/fresh-cave-texture/texture.bin --definition 4 --definition 5 --output /path/to/fresh-roach-sprites
```

The texture command requires a fresh directory and writes `texture.bin` plus block/hash provenance in `texture_decode.json`. It validates the original archive hash, block extents, decoded lengths and trailer. No runtime-generated CDCACHE files are required. The library `decode(name, game=...)` retains the prior return structure. Unlike the historical script, direct CLI execution now requires explicit arguments.

[Texture evidence](texture-portability-checks.json) verifies all four outputs against current texture inputs (58,080,772 bytes), four malformed-container cases, and a complete original-cave-MIX → newly extracted texture →98 Roach-frame regeneration with100 byte-identical files. The shared material exporter uses the same extracted decompression function; its broader result is recorded separately in the receipt. Geometry/world mesh generation, per-encounter assembly and the complete clean-machine demo recipe remain open.

## Geometry export from original archives

The geometry exporter now uses repository-local slope/subdivision/connector readers and `docs/game-geometry-profiles.json`, a compact set of pinned archive/geometry hashes, names and dimensions:

```sh
python3 -S tools/lol2/map_geometry.py --game-root /path/to/original-game --area L1_DC --out /path/to/cave-geometry
python3 -S tools/lol2/map_geometry.py --game-root /path/to/original-game --all --out /path/to/all-area-geometry
```

Use separate output directories to preserve earlier results. `--inventory` can select an explicit compatible profile JSON. The library API is unchanged. [Geometry portability evidence](geometry-portability-checks.json) verifies all15 areas and91 byte-identical output files, including diagnostics, against the old exporter; three structural tests pass. The isolated run uses Python's standard library and repository helpers, with no RE checkout imports. Original coordinates and generated meshes remain local. Existing subdivision/connector limitations are preserved; portability does not imply new geometry fidelity. Material/scenery preparation and assembling the entire demo still need a complete portable recipe.
