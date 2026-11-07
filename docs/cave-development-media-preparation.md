# Cave development movie preparation

```sh
python3 tools/prepare_cave_development_media.py --game /original/game --re-root /published/re --story-root /fresh/assets/lol2/video_review --output-root /fresh/development-output
```

First prepare the Cave story with export_chamber_discussion.py and --include-kenneth. The story root must contain the fresh kevin_entry6.ogv and chamber_provenance.json. This command checks that clip's original source binding and actual output hash. It pins L1_DCI.MIX, entries 20/24 and the published RE2791eb1 converter (fd8a40bd...). Requires Python, FFmpeg/ffprobe with Theora/Vorbis/VQA support and the published MIX reader.

It writes kevin_entry20.ogv, bluescreen_entry24.ogv and provenance.json under assets/lol2/video_review. Merge these three files into the same assembly as the prerequisite story pack. The two development clips retain the existing video-review choices, filenames, 150/64 source frames and 15fps. Provenance retains the three existing clip labels and source identities, with current Ogg hashes. These are development review clips, not additions to the production story playlist.

Both clips matched existing decoded RGB frames, decoded audio and encoded packets. Ogg container bytes and their hashes vary between encodes. Every provenance field except fresh output hashes matched. Isolated published-helper generation and five refusal controls passed: existing output, absent game, absent converter, absent story and input/output overlap. The converter subprocess uses the pinned standalone helper; no native replay is performed. Temporary original VQA data is removed on exit. Final copying is sequential and can leave partial output on filesystem failure. Keep original/generated media out of source publication. Whole-build resource and gameplay checks remain separate.
