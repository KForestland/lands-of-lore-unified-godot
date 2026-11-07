# Monastery Dampen charm icon preparation

```sh
python3 tools/prepare_monastery_dampen_media.py --game /path/to/original-game --output-root /path/to/fresh-output
```

Requires Python 3, Pillow and the published shared icon readers. Both GLOBAL.MIX and LOCAL.MIX are pinned. Definition72 must retain name70-Dampen ch, identity0x43F8BC0D and handler27. Its initial-state icon resolves through the shared decoder to resource107,34×11 pixels. The resulting assets/lol2/generated/monastery_dampen/dampen.png matches the existing complete one-file pack byte for byte.

Output must be fresh and must not overlap the game directory. Decoding completes in a temporary directory before output creation. Isolated generation with legacy RE access disabled loaded no native/RE modules. Five refusal controls covered existing output, missing originals, overlap and either incorrect archive.

This command prepares the icon only. Existing Dawn-runes movies remain owned by the complete monastery-room preparation command; historical branch/handler evidence and prepare_monastery_dawn_runes.py remain unchanged. It does not replay the native handler or change gameplay behavior. Whole clean assembly and acceptance remain separate gates.
