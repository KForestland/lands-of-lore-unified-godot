# Bacatta and village room media preparation

From a source checkout, run:

```sh
python3 tools/prepare_bacatta_rooms.py \
  --game /path/to/original-game \
  --re-root /path/to/re-helpers \
  --recipe scripts/lol2/bacatta_rooms_source.json \
  --output-root /path/to/fresh-output
```

The output directory must not exist. Use a separate destination outside the original game and source checkouts. The command needs Python 3, Pillow, ffmpeg/ffprobe, the published monastery media helpers, and the pinned `tools/convert_cave_video_review.py` from the RE helper checkout. The converter hash is checked by `monastery_media`. The explicit path does not run native audits or require historical generated assets or audit documents.

The compact recipe retains CAN and VILLAGE room records consumed by the existing producer. Its provenance identifies the historical static-disassembly audit, producer and consumer hashes. Original archive hashes, DLL bindings, movie metadata, audio bindings and names derived from recorded calls are verified before staging. These checks validate the recorded media selection against the originals; they do not re-execute native room logic or independently derive that selection. Use ordinary Python without optimization, because input and decoder checks include assertions.

The command writes `assets/lol2/generated/bacatta_rooms` and intermediate source media under `tmp/bacatta_source`. Keep original and generated media local. A decoding failure may leave partial output; preserve it and retry in a new directory. No-argument dispatch retains the historical native audit and dependencies. The imported `stage_intro(source, target, record)` API and its implementation are unchanged, including its use by the legacy LIZ preparer.

Independent review rebuilt the complete 97-file runtime pack using committed helpers and only the pinned external converter: 91 files were byte-identical, three OGVs had equal decoded RGB frames and encoded packets, and three converter reports differed only in absolute paths and diagnostic pointer addresses. CAN and VILLAGE backgrounds each contain 30 video-only frames. TAVERN contains 148 frames; its 481 decoded audio packets and complete PCM also matched. All 92 manifest resource references resolve. Recipe provenance hashes and retained selections match the historical audit. Existing output, missing originals and wrong-recipe controls were refused before creating output. AST comparison confirms the unchanged intro API and extracted staging body.

This prepares the existing room pack. It does not establish native room execution, full Act 1 assembly, or owner content acceptance, and does not alter the verified R18 build.
