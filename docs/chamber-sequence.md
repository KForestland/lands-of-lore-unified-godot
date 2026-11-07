# Automatic Draracle chamber sequence

User confirms that Kenneth's scene is followed by a video discussion, then a
move to the Draracle's museum. There are no dialogue choices to implement here.

## Source comparison

The original-game reference is [Kikoskia, The Draracle](https://www.youtube.com/watch?v=N05rwQTWKsw).
Full video/subtitle fetching failed, so this pass inspected YouTube storyboard
previews sampled about every4.95 seconds, not uninterrupted playback or audio.
They show Kenneth around312–351 seconds, the cave discussion around356–445,
then further presentation and museum introduction before museum control returns
around544 seconds. Preview timestamps are approximate.

Locally decoded, source-hashed filmstrips match these portions:

| Source | Identity | Duration | Use |
| --- | --- | --- | --- |
| DAT/L1_DCI.MIX entry6 | Kenneth arrival, already user-identified | 37.2s | First cave story clip |
| DAT/L1_DCI.MIX entry5 | Draracle/Luther discussion, matching reference after arrival | 91.8667s | Second cave story clip |
| DAT/L3_DHI.MIX entry5 | Continuation introducing museum departure | 28.6667s | Prepared for destination integration |
| DAT/L3_DHI.MIX entry6 | Museum introduction with an additional character | 46.1333s | Prepared for destination integration |

The reference includes a parchment/map presentation between the cave and museum
portions. Its implementation and exact trigger remain unverified. The two museum
clips are available in development video review; they are not attached to the
cave playlist. Entry4 in L1_DCI is a different arrival with two soldiers; no
variant-selection rule is implemented from the images alone.

## Implementation and remaining boundary

`cave_video_overlay.gd` now advances the cave playlist from Kenneth to the
Draracle discussion without resuming the world between them. Pause applies to
playback; Skip skips the whole sequence. External interruption permits retry;
completion or Skip consumes the existing in-session chamber trigger. Both story
assets must exist before starting.

The new conversions retain original audio and are checked against source frame
counts, dimensions and duration by `export_chamber_discussion.py`. Provenance is
in `assets/lol2/video_review/chamber_provenance.json`.

### Preparing the story clips

```sh
python3 tools/export_chamber_discussion.py --game-root GAME --re-root RE \
  --out FRESH/assets/lol2/video_review --evidence FRESH_EVIDENCE --include-kenneth
```

- **Inputs.** `GAME` is the installed original game. `RE` is a checkout of the companion `lands-of-lore-2-re`
  repository at a commit providing `tools/convert_cave_video_review.py` (sha256 pinned, published in 2791eb1) and
  `tools/draracle/lol2_extract_draracle_geometry.py`.
- **Requirements.** Python 3 and `ffmpeg`/`ffprobe` on PATH with libtheora, libvorbis and the `vqavideo` decoder.
- **Preflight.** The tool checks every requested original entry, the converter and ffmpeg before writing. It converts
  in a staging folder and moves the results into place only after all clips succeed. Use fresh output folders for a
  clean preparation; `EVIDENCE` receives copies of the original VQA entries and must stay private.
- **Clips.** Without `--include-kenneth` the tool prepares the three original clips (production clips 3, 4, 5).
  With it, it also prepares clip 0, the Kenneth clip that opens the Cave story.

| Output | Archive | Entry | Key | Size | Entry sha256 |
| --- | --- | --- | --- | --- | --- |
| kevin_entry6.ogv (`--include-kenneth`) | DAT/L1_DCI.MIX | 6 | 2902007471 | 14900260 | `6bd39df40b4ed2517cc959fec347f8bbd40996c226c98ef7c8f5775e2e8a9642` |
| chamber_discussion.ogv | DAT/L1_DCI.MIX | 5 | 2902003377 | 36161114 | `9f67c5abceab3f2c03dd84d6b13ce9d98bf44ee1a0ed861e9352fd47a11508a2` |
| museum_introduction_a.ogv | DAT/L3_DHI.MIX | 5 | 2902008005 | 10895686 | `d4068caad97a9ca427a8a2940c33919572540ca92cbe2c680e7d310dd49102a7` |
| museum_introduction_b.ogv | DAT/L3_DHI.MIX | 6 | 2902008517 | 18107180 | `4c06cd4be21b337c95c7b2ee4277564caa5b5b2a8a8518b5371b76b00695b757` |

The conversion is lossy (Theora/Vorbis). Ogg stream serial numbers change per run, so compare decoded frames and
audio, not container bytes.

The cave now changes to `museum_walkthrough.tscn` after completion or Skip.
The old cave scene is freed; the museum plays entries5/6 from L3_DHI automatically,
then returns control at the first saved arrival XY. Its geometry and recovered
materials are still a development reconstruction with provisional UVs and camera
heading, missing exhibits, doors and gameplay scripts. This handoff does not
make either map content-complete.

The shared overlay accepts a validated clip list and story title. The cave keeps
[0,3]; the museum uses [4,5]. A destination asset preflight occurs before the cave
sequence starts. Failed scene changes permit retry. Existing collected sample IDs
are carried in session memory; no persistent museum saves or full inventory system
are introduced. Skipping the cave sequence proceeds to the museum introduction;
skipping that introduction restores museum control.

User decision (2026-09-13): retain the original videos. The attempted AI upscale
changed the Draracle into a demon-like character, so it will not be used. Existing
source-derived conversions remain the presentation assets.

Museum geometry is now reproducibly extracted and audited; see
[museum geometry](museum-geometry.md). This does not yet establish the arrival
pose, materials, runtime collision, or a playable destination.

## Validation

The updated short `chamber_arrival_test.gd` passes cave interruption/retry,
Skip, duplicate-start rejection, actual old-scene cleanup, carried sample state,
museum playlist ordering, intro Skip, no repeat and floor support. The optional
full-cave mode now expects the museum handoff rather than returning to the cave.
That updated long mode has not been rerun in this pass; earlier natural cave
playback was verified before the handoff change.

`museum_introduction_test.gd` passes natural playback of both museum clips,
pause/held playback time, a frozen world between clips, final control restoration,
no repeat and arrival floor support. Pause measurement allows a queued decoder/
audio frame to settle before testing held position. Empty/out-of-range playlists
are rejected. No complete first-level route or museum-content completion is claimed.

Current logs: `~/lol2_out/museum_capture_20260913/handoff_test.log` and
`museum_intro_test.log`. Older cave/voice evidence remains in its original folders.

2026-09-25: natural cave playlist, real Museum handoff and both Museum introduction clips now complete within the earned continuous entrance-to-Museum route. The test neither skips nor emits completion signals. See [connected route evidence](cave-earned-museum-walk-checks.json); its4x engine clock is a test adapter, not source timing parity. The final Museum save retains the earned Stalagmite, health30 and active timed curse.
