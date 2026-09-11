# Indexed special-pixel review

Build fixture assets using the RE repository's build_special_pixel_review.py:

```sh
python3 tools/draracle/build_special_pixel_review.py --game-root /path/to/lol2 --out /path/to/godot/assets/lol2/generated/special_pixel_review
```

Run the separate scene:

```sh
flatpak run org.godotengine.Godot --path /path/to/godot res://scenes/lol2/special_pixel_review.tscn
```

Space toggles destination remapping. The title identifies the candidate
shade64 binding as unverified. -- --capture-remap saves captures/special_pixel_review.png.
The generated expected.png is the CPU reference for exact RGB comparison.

The shader reads indexed background/sprite textures:0 preserves background,
1 remaps the background index,2–255 use source palette colours. Ordinary
source shading is omitted in this diagnostic. GPU output matches every
pixel of the640×400 CPU reference (256000 pixels, zero mismatches).

The file shade row64 is a candidate because the native immediate is4000;
its runtime address adjustment is NOT recovered. This test proves the
compositor with supplied inputs, not table selection or original lighting.
It is deliberately separate from the playable cave. The cave's RGB buffer
cannot preserve duplicate palette indices or exact remapping history.
An indexed render path or an explicitly approximate RGB fallback is needed
before scene integration. No new props or cave visual changes in this pass.
