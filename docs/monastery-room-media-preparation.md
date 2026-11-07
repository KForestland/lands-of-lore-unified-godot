# Monastery room and tavern media preparation

The explicit monastery path rebuilds the first visits and MOFF rune/refusal/orb plus MLIB attack/exit-runes media. It uses the compact tracked recipe and three recorded contracts already published with the project:

```sh
python3 tools/prepare_monastery_rooms.py \
  --game /path/to/original/game \
  --re-root /path/to/lands-of-lore-2-re \
  --recipe scripts/lol2/monastery_rooms_source.json \
  --offer-source docs/monastery-offer-responses-source.json \
  --attack-source docs/mlib-dawn-attack-checks.json \
  --dawn-runes-source docs/monastery-dawn-runes-source.json \
  --output-root /path/to/fresh/monastery
python3 tools/prepare_tavern_return_media.py \
  --game /path/to/original/game \
  --source scripts/lol2/tavern_return_source.json \
  --output-root /path/to/fresh/tavern
```

Dependencies are Pillow and ffmpeg/ffprobe with Theora/Vorbis, VQA, PNG and PCM support. The monastery command uses only `tools/convert_cave_video_review.py` from companion RE commit `2791eb11e453ad5cbccdce5d5d29efc1850a2d3c`, pinned to SHA256 `fd8a40bdd50b9394ac4a21574907562247cddd32ccded2491731c28922dde77d`. Other decoding is local through `monastery_media.py` and the pinned `decode_monastery_vectors.py`. Tavern needs no companion converter. The explicit paths import neither Capstone nor Unicorn nor the old room audit.

Outputs are `assets/lol2/generated/monastery_rooms` and `assets/lol2/generated/bacatta_revisit` beneath their respective fresh roots. Independent regeneration verified:

- 343 monastery PNG/WAV files byte for byte.
- Three video-only room backgrounds, each with all 30 decoded RGB frames and encoded video packets equal; Ogg container serials differ.
- `rooms.json` parsed equal. Its first-visit duration keys have a different insertion order from the historical file.
- Three converter reports equal except run-specific source/output paths and ffmpeg pointer addresses.
- All 64 tavern files byte for byte.

The monastery output has 350 files. Historical `MLIB/0375007E.ogv` is an unused leftover from an older writer: current room patches use PNG atlases/WAVs, and video loading uses only the three background paths. It is excluded only from the fresh expected set. Baseline and candidate files were not deleted. Godot import/UID sidecars are separate from these extraction outputs.

The compact recipe preserves consumed room/rune records and recorded-audit/producer hashes. Room selections came from static DLL call arguments, not native execution; rune selections came from one replayed handler case with mocked host queries. Preparation rechecks the named archive entries, DLL bindings and movie headers against the originals; it does not rederive those selections or rerun the native audits. The recipe carries those limits, and quoted historical audit scope is not a statement of current gameplay coverage. Unused disassembly, case dumps and historical Jungle geometry were omitted.

Four independent negative controls rejected existing output, a missing converter, a wrong recipe and a re-pinned recipe with a changed movie frame count, preserving previous output. Use ordinary Python without `-O` so original-record assertions stay enabled. Writes after preflight are sequential and may leave partial fresh output on failure. Original movies, caches and generated assets remain private.

No-argument/imported legacy entry points retain their audit/decode behavior. The reusable helper lets additional preparers adopt explicit paths individually; other legacy room preparers are not made portable merely by this change. Audible playback, rendered behavior and the entire clean Act 1 assembly remain separate checks.
