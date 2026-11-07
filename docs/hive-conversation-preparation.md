# Hive conversation-pack preparation

```sh
python3 tools/lol2/map_materials.py export --game-root /path/to/original/game --area L5_HC --out /path/to/fresh/materials
python3 tools/prepare_hive_conversation_media.py --game /path/to/original/game --texture /path/to/fresh/materials/texture.bin --output-root /path/to/fresh/output
```

The first command needs the published geometry profile. Conversation preparation uses published source/material/movie and chunk readers, Pillow, NumPy and FFmpeg. Inputs are original `DAT/L5_HC.MIX`, `DAT/L5_HCI.MIX` and the freshly exported Hive texture. The Hive archive, texture and extracted E070E movie hashes are checked.

Original control 75 joins template 6 and movie resource 182. The six section ranges and labels are extracted from the movie's LINF/LNIN chunks. No historical conversation proof or extracted VQA is an input. The full runtime pack contains ten atlas pages for 962 frames, six WAV sections and `conversation.json`.

Lead verification reproduced all 17 files byte-for-byte with an isolated committed-source checkout and no native/RE imports. Five refusal controls cover existing output, overlap, missing originals, wrong archive and wrong texture. Output must be fresh and outside both inputs. Extracted VQA stays under `tmp/hive_conversation`; decoding failures may leave partial staging output.

The legacy writer and native verifier remain unchanged. Clockwise orientation, magenta key, common crop, frame-242 anchor, 128-unit height, world position and sequential section order preserve the existing authored presentation. The last section remains present in the data but outside normal conversation display. This preparation does not newly verify native rendering, full event dispatch or quest admission.
