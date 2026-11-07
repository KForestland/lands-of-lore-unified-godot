# Museum Broken Thohan preparation

```sh
python3 tools/prepare_museum_broken_thohan_media.py --game /path/to/original/game --output-root /path/to/fresh-output
```

Requires Python/Pillow and the checkout's published archive, source-event, material and prop readers, including the geometry profile. Produces all12files in `assets/lol2/generated/museum_broken_thohan`: `control.json`, `icon.png` and ten sword frames. Independent reconstruction matches the entire existing pack byte-for-byte.

The original Museum/GLOBAL/LOCAL archives and geometry/metadata/texture entries are pinned. The control181 placement, grant/return events, predicates, command groups, Case template9 children35/36, template24 bounds and region413 containment are reread from originals. Four parsing helpers match the legacy producer's ASTs exactly. The full regenerated catalog also equals its historical source-evidence fields.

The ten sword images come directly from the published prop-template decoder on fresh Museum texture. This is the same template-image code used by the attached-prop exporter, without importing its instance/constructor layer. The inventory icon comes from the original unique Broken Thohan item definition. No new recipe, historical generated input, constructor helper or native replay is required. An isolated committed-helper run imports no native modules; existing-output, missing-game, altered-archive and overlapping-output checks pass.

The output must be absent and must not overlap the game tree. Images and source checks precede output creation; later write failures may leave partial output. The original writer remains untouched. Its docs-only native qualifier replay/fixup evidence is not regenerated or newly claimed; the retained catalog's semantics and modern interaction adapter are unchanged. Original/generated assets are excluded from source publication. Whole-project qualification remains separate.
