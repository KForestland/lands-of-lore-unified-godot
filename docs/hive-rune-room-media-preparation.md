# Hive rune-room media preparation

From the source checkout:

```sh
python3 tools/prepare_hive_rune_media.py \
  --game /path/to/original-game \
  --re-root /path/to/re-helpers \
  --recipe scripts/lol2/hive_rune_rooms_source.json \
  --output-root /path/to/fresh-output
```

Use a new output directory separate from inputs. Python 3, Pillow, ffmpeg/ffprobe, the published monastery media helpers and the pinned RE `tools/convert_cave_video_review.py` are required. The explicit path does not load native audits or historical generated assets. Use ordinary Python without optimization because input checks include assertions.

The compact recipe supplies the recorded RUNES/RUNECL archive hashes, DLL bindings and hotspot calls. Provenance identifies the historical static-disassembly source and producer. Archive/DLL bindings and every clip entry are checked against originals. Hotspot values are trusted recorded selections, checked for shape and protected by the recipe hash; they are not independently re-derived. Changing the code's recipe pin could permit different same-shaped hotspot values.

Outputs are the existing 18 files under `assets/lol2/generated/hive_rune_rooms` and intermediate source media under `tmp/hive_rune_source`. There is no separate `hive_rune_media` asset pack. Five backgrounds are video-only OGVs with first-frame stills and converter reports; RUNES2_ uses two transparent patch atlases. Keep generated media local. Existing destinations, missing originals and incorrect recipes are refused. Later decoder failures may leave partial output; preserve it and use a fresh directory for another run.

The legacy no-argument entry point retains historical input/output audit documents and its imports. Its staging body is unchanged after extracting the clip-list constant; the explicit command does not write the legacy audit report.

Independent reconstruction verified all 18 files: eight byte-identical, five OGVs equal in decoded RGB frames and encoded packets, and five converter reports differing only in paths and diagnostic pointer addresses. Video frame counts are 30/30/55/30/30, with no audio streams. All 16 manifest references resolve. Recipe provenance hashes and retained values match the historical audit. Existing output, missing game and wrong-recipe controls pass. This verifies media preparation, not native admission/effect execution or complete Act 1 acceptance. R18 is unchanged.
