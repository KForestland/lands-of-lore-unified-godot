# Jungle village dialogue preparation

Run from the source checkout with Python 3, NumPy, Pillow and FFmpeg installed:

```sh
python3 tools/prepare_jungle_village_dialogue_media.py --game /path/to/original-game --texture /path/to/fresh/L4_HJ/materials/texture.bin --output-root /path/to/new-village-output
python3 tools/prepare_jungle_followup_dialogue_media.py --game /path/to/original-game --texture /path/to/fresh/L4_HJ/materials/texture.bin --output-root /path/to/new-followup-output
```

Prepare the texture input using the published `tools/lol2/map_materials.py export` command for area L4_HJ. Each output directory must be absent and must not overlap either input. The original L4_HJ archive, texture, control/template/resource binding and extracted E076E/E077E movie hashes are checked. Original movie section ranges and labels are checked as well. No historical generated media or native execution is needed.

Village control99/template58/resource494 produces 540 frames in six atlas pages, three WAV sections and conversation.json. Followup control85/template70/resource493 produces 606 frames in seven pages, three WAV sections and conversation.json. Each command also writes its source report under docs and extracted movie under tmp in its output root. Do not publish those original-derived outputs. The legacy scripts remain unchanged.

Both movies use the published Python partial-codebook decoder; FFmpeg extracts audio. The fallback video decoder is retained for consistency but is not used by these pinned movies. FFmpeg reports end-of-demux diagnostics on these inputs; successful extraction and each section's duration are checked. Existing authored clockwise orientation, cyan transparency, shared crop, billboard size/placement, section order and completion behavior are preserved. Death frames remain in the atlases but do not determine the normal conversation crop. This reproduces the existing Godot presentation, not native rendering or new event-dispatch evidence.

Local verification compared every file of both complete runtime packs (10 and 11 files) and both source reports byte for byte against the existing packs. Generation used an isolated snapshot of committed published tools plus the new commands. Eight refusal checks covered existing outputs, missing originals, input overlap and incorrect textures for both commands. A decoder failure can leave a partial output directory; retain it for diagnosis and use a fresh directory on retry.

This closes these two preparation paths only. Whole clean assembly and gameplay acceptance remain separate gates.
