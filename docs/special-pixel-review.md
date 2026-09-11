# Indexed special-pixel review

Build fixture assets using the RE repository's build_special_pixel_review.py:

```sh
python3 tools/draracle/build_special_pixel_review.py --game-root /path/to/lol2 --out /path/to/godot/assets/lol2/generated/special_pixel_review
```

Run the separate scene:

```sh
flatpak run org.godotengine.Godot --path /path/to/godot res://scenes/lol2/special_pixel_review.tscn
```

Space toggles destination remapping. The title identifies shade64 as the initial loader table. -- --capture-remap saves captures/special_pixel_review.png.
The generated expected.png is the CPU reference for exact RGB comparison.

The shader reads indexed background/sprite textures:0 preserves background,
1 remaps the background index,2–255 use source palette colours. Ordinary
source shading is omitted in this diagnostic. GPU output matches every
pixel of the640×400 CPU reference (256000 pixels, zero mismatches).

The RE verifier resolves both native special-pixel fixups to object4 +
0x4000. The cache loader reads section4 into object4 + 0, establishing
row64 as the initial table. The fixture builder verifies this provenance.
Later runtime modifications and original source lighting remain unverified.
The table bytes and GPU reference are unchanged from the candidate test.
It is deliberately separate from the playable cave. The cave's RGB buffer
cannot preserve duplicate palette indices or exact remapping history.
An indexed render path or an explicitly approximate RGB fallback is needed
before scene integration. No new props or cave visual changes in this pass.
