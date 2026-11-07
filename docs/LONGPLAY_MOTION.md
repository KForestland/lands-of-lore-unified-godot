# Longplay motion measurement (Astra task E / W9)

`tools/measure_longplay_motion.py` measures a screen box using NumPy phase correlation. Requires host Python3, NumPy and Pillow. It reports frame hashes, timestamps, separate motion episodes, integer-pixel displacement, translation-compensated px/s, rejected pairs and temporal resolution. No OpenCV is required. The registered headless `longplay_motion_test` runs deterministic translation/scale/negative cases; Flatpak uses host Python when its bundled Python lacks the analysis packages.

Dense source extraction is read-only, headless video decoding; it does not acquire Godot's renderer. Example (the output directory must exist):

```sh
ffmpeg -hide_banner -loglevel error -threads 1 -ss 12304 \
  -i '<owner-media> stuff/Lands of Lore 2_ Guardians of Destiny longplay - Most Difficult.mp4' \
  -t 16 -vf 'fps=4,scale=640:360' -threads 1 tmp/dense_l13_door/d_%05d.png
python3 tools/measure_longplay_motion.py \
  --frames tmp/dense_l13_door --pattern 'd_*.png' \
  --time-origin 12304 --frame-step .25 --window 12308 12314 \
  --box 210 45 180 160 --background-box 30 40 120 140 \
  --out tmp/l13_aperture_candidate.json
```

This example is a **rejected mover calibration**: direct inspection shows camera travel through a hole, not a source-identified movable. A nonzero compensated screen speed is not evidence that a native mover moved. Perspective/parallax can survive translation subtraction. The tool always reports `automatic_adapter_replacement_allowed=false`; manual source-object and camera checks are required.

A stationary background box removes translation only. Without it or an explicitly asserted `--camera-static`, pairs are rejected. Rotation, zoom, parallax, texture animation, combat effects and occlusion are limitations; high correlation is not a proof against them. Low texture/ambiguous correlation, residual over0.20 or spacing over0.5 seconds are rejected. The maximum spacing is configurable but must not be relaxed to make a sparse scene index look like a dense timing measurement. The cached `g_*.jpg` Act2 index is30s apart; it is rejected by default.

## World calibration

No world speed is emitted by default. `--depth D --vfov F` assumes a known object depth and vertical FOV and reports image-plane world-units/s only. Focal length is image_height/(2*tan(F/2)); world-units/pixel = depth/focal. This does not recover depth-direction motion.

An alternative is `--camera-height H --ground-y Y --horizon-y Y0 --level-camera --vfov F`, which explicitly assumes flat ground, a level camera and the object's known ground-contact row. Depth = H*focal/(Y-Y0). Height and FOV alone are insufficient. The original camera calibration must be evidenced; the port's32/48-unit camera clearance and75-degree FOV are not silently promoted to original values. Crop coordinates are measured on the supplied full image; any original viewport cropping/rescaling must be reflected in calibration.

Integer displacement resolution is1px; per-pair speed quantization is1/dt px/s. Frame extraction adds sampling uncertainty (at4fps, up to one0.25s interval plus original-frame rounding). Source-specific motion start/end needs before/after stationary frames; a window that begins/ends in motion supplies bounds, not a complete duration.

The current mover interpolator uses `weight=min(1,4*delta)`, an exponential approach, not a constant4-world-units/s velocity. A screen speed cannot simply replace that coefficient. A usable calibration must establish object identity, motion axis/endpoints, camera behavior, scale and motion-time curve. No runtime mover constants were changed in this tool patch.

## 2026-10-31 evidence

- Source video found at the archive path above (7,460,168,252 bytes; duration18588.903667s). Frame-level SHA256 pins are in measurement outputs; no claim that a whole-video hash was computed.
- Dense L8 window6650–6690s (110:50–111:30): camera walks through forest.6652–6655s ROI analysis returned70.880px/s median among5 accepted pairs, but **rejected for mover calibration** after viewing the sheet. Background parallax/control mismatch, not an identified movable.
- Dense L13 aperture window12304–12320s (205:04–205:20): player approaches/passes an aperture.12308–12314s ROI analysis returned36.979px/s among14 accepted pairs, but **rejected for mover calibration**: camera travel, no native-mover identity. World speed stays null.
- L13 sparse index12100–12400s:11 frames,0 valid timing pairs,0 episodes, speed null (correct sparse-data refusal).
- Reviewed source-video overview201:00–203:00 and202:50–206:10, plus208:20–212:30. They show conversation/movie, Ruloi combat and camera traversal; no source-identified stationary-camera mover event was established. Cached-index time labels follow the lead's formula but are not assumed exact source-video correspondence without a match.
- Source mover identities checked independently: L8 movable53/54 at raw(3385,4204,h20)/(3390,4286,h20); L13 movable50/71/77 at raw(-2057,2719,h-1140)/(-4057,1034,h-1240)/(-5941,1126,h-1040). None is assigned to the candidate videos without evidence.

Receipts/contact sheets: `~/AI_COMMS/astra_lane/taskE_20261031/`. Tool verification is complete; replacement of guessed motion constants remains open pending a matched source-mover clip and calibrated geometry/camera, requested on AI_COMMS. Existing adapters remain labelled adapters.
