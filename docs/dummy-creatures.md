# Static creature stand-ins

The walkthrough now includes two ordinary guard and two roach-like dummies
for atmosphere and scale. K hides/shows all four. They have no animation,
AI, combat, interaction or collision. The user-approved glow and lighting
settings are retained.

Original block-sprite resource408 supplies the guard pose; resource733 supplies
the insect pose. Both were visually inspected. Kevin's identified314–407 range
is excluded. An older resource966 preview was re-inspected and appears to be
a fallen guard, not a suitable roach; it is not used. Labels are visual
identifications, not recovered original filenames or creature-state bindings.

The RE exporter decodes the pinned original cache/codebooks and crops only
empty indexed borders. Guard408 is54×175 after cropping; insect733 is214×55.
Index0 remains transparent; the selected frames contain no special index1.
Unused block-record tails are reported, not silently declared padding.

```sh
python3 tools/draracle/export_dummy_creatures.py --game-root /path/to/lol2 --out /path/to/godot/assets/lol2/generated/dummy_creatures
```

Display heights56 (guard) and12 (roach-like) are provisional. Positions are
chosen using existing floor geometry: regions353/354 near checkpoint14 and
region1813 near checkpoint119. One insect is offset within the latter floor
polygon to separate it from the guard. These are deliberately selected display
positions, not claims of original enemy spawns. Pixels, aspect ratio and pose
are preserved. Fixed-Y billboarding repeats the same pose from every angle.

Dummies enter the indexed background, special-pixel occlusion masks and
approved light pass. Their visibility updates all three. No new game images
are committed; generated original-data assets stay local.

```sh
flatpak run org.godotengine.Godot --path /path/to/project res://scenes/lol2/cave_walkthrough.tscn -- --checkpoint=119
```

For visibility comparison, add --dummy-capture, then run
`python3 tools/verify_dummy_creatures.py --checkpoint 119`. Captures at14 and119
show visible changes and exact RGB/index restoration when toggled back on.
The larger cavern view shows both creature types and was visually inspected.
Four-view movement/resize/visibility index-compositor regression still passes
with zero mismatches. These checks do not establish original scale, animation,
spawn behaviour or all-view visual parity.

The next useful work is walkthrough feedback and packaging/polish; gameplay
remains outside the proof-of-concept scope.
