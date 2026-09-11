# Cavern walkthrough proof of concept

The agreed demo scope is a cave walkthrough. Combat, enemy AI, interactions
and audio are not release requirements for this proof of concept.

Run the populated local project:

```sh
flatpak run org.godotengine.Godot --path /path/to/project res://scenes/lol2/cave_walkthrough.tscn
```

The local launcher is /home/bob/run_lol2_cave_walkthrough.sh. This starts at
checkpoint14; --checkpoint=N selects another of119 checkpoints. Existing
original/diagnostic scenes remain available. Standalone Linux and Windows exports are documented in standalone-demo.md.

Controls: WASD and mouse; Shift sprint; Esc release mouse and click to resume;
F fly; Space/Ctrl ascend/descend in flight; N/P checkpoints; R reset;
B props; C roof. Checkpoint changes return to walking. Window resize updates
all active render targets. The on-screen guide shows the current mode.

The scene includes2373 wall spans,1953 floor faces,1939 ceiling faces,
1183 ordinary props and3 recovered special-pixel props. Special sprite
planes update their cameras and far-to-near order as the viewpoint changes.
Their palette-index compositing remains intact until final colour resolve.
Occluder copies follow the visibility of the original props/roof, so hidden
objects cannot keep masking special sprites. Unused diagnostic viewports are
disabled and the main camera skips redundant world rendering.

## Validation

Four scripted camera positions/directions test changed sprite order, two
window sizes, prop hiding/restoration and roof hiding. All intermediate
index/marker buffers and final RGB captures match CPU expectations. Sizes:
960×540 then800×450;1598400 final pixels total, zero mismatches. Camera
transforms are checked against the player camera. Special pixels are present
in three views and absent when props are hidden.

```sh
flatpak run org.godotengine.Godot --path /path/to/project res://scenes/lol2/cave_walkthrough.tscn -- --walkthrough-capture
python3 tools/verify_walkthrough_capture.py
flatpak run org.godotengine.Godot --path /path/to/project res://scenes/lol2/cave_walkthrough.tscn -- --walkthrough-walk-check
```

The input test injects a physical W press through Godot's input system:
60.59 units moved, zero resets, grounded at the end. This tests a short walk
at checkpoint14, not a new full119-route certification. The resulting HUD
and cave capture were visually inspected. Tested on Godot4.7.2 Compatibility
with Radeon RX9070XT; other hardware/backends are untested.

Remaining walkthrough work: broader movement/performance checks and obvious visual cleanup.93 floor material assignments remain unresolved,
roof material/tint and lighting are provisional, prop billboarding is a
preview convention. The multi-pass approach still duplicates static masks;
no broad FPS target or native screenshot/draw-order parity is claimed.
Additional special bindings and enhanced lighting can follow without making
gameplay a requirement for this demo.

## WASD direction fix

The initial walkthrough inherited local camera yaw from the prop inspection
look_at call, while its reset only restored pitch. WASD followed the player
heading but the view faced elsewhere. The walkthrough reset now restores
camera rotation to pitch-only, including R and checkpoint changes.

`--controls-check` injects physical W/A/S/D inputs and measures displacement
against camera-relative forward/right across two checkpoints and three mouse
turns. Before the fix all24 direction cases failed (alignment -0.6044);
afterwards all24 pass. A separate check verifies reset clears inherited yaw
and roll. The existing forward-walk/floor-collision check also passes.

## Lighting mode

Enhanced distance-based warm/cool lighting is now on by default. L toggles
the exact reference view; --reference-lighting starts without the enhancement.
See cave-lighting.md for scope and validation. This does not add gameplay,
world light sources or cast shadows.

G toggles optional green glow on four existing resource469 props. To start
near one, use --glow-record=1108. See cave-prop-glow.md.

## Creature stand-ins

K toggles two guard and two roach-like static dummies. Their positions and
scale are provisional, with no AI/collision/gameplay. Checkpoint119 shows
both types; see dummy-creatures.md. Approved lighting and glow are retained.
