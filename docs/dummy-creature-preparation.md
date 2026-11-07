# Cave dummy-creature preparation

```sh
python3 tools/prepare_dummy_creature_media.py --texture /fresh/L1_DC/materials/texture.bin --output-root /fresh/dummy-output
```

Requires Python 3, Pillow and published sprite/material readers. Export the Cave texture with the published material exporter. Its hash is pinned. The output root must be absent and disjoint from the texture input. This replaces the legacy captured-cache input for clean preparation without changing the legacy exporter.

The output is two indexed PNGs and creatures.json under assets/lol2/generated/dummy_creatures. Descriptors 408 and 733 retain the established crop, display heights and four provisional placements. These are existing static stand-ins, not original actor spawns or new behavior. Native timing, AI, collision and visual fidelity are not claimed.

An isolated published-helper run reproduced all three files byte-for-byte with no native/RE imports. Existing-output, missing-texture, wrong-texture and overlapping-output controls refused. Decode failure can leave a partial fresh directory; preserve it and use another destination for retry. The pack remains required by the existing Cave scene and standalone preparation check. Whole-build and gameplay qualification are separate.
