# Cave wall preparation

Run from the source checkout with Python 3 and Pillow:

```sh
python3 tools/prepare_cave_walls_media.py --game /original/game --output-root /fresh/wall-output
```

The output root must be fresh and disjoint from the original game directory. The command checks the original L1_DC archive, exports its texture data using the published material exporter and geometry profile, then prepares both assets/lol2/generated/wall_review (83 files) and wall_indices (29 files). All calculation and validation finish before output creation.

Six pure wall-span models reproduce the established geometry. They were originally compared against native replay in the legacy verifiers; this command does not execute native replay. Texture extraction, inferred UVs, variant images, single-variant fallback names and grayscale index images retain the existing runtime data. No historical generated inputs or RE checkout are required.

Independent review reproduced all 112 files byte-for-byte. Every span record, region, fixed-point corner and active flag matched the preserved historical results in order. All 29 extracted material reports and 333 intermediate PNGs matched; the final report contains 2,373 walls across 3,044 checked records. Isolated generation loaded only published helpers, and existing-output, missing-original, overlapping-output and wrong-archive controls refused.

The existing scope remains: inferred UV orientation and manually selected variants are retained; transparency, animation timing and live rendering parity are not newly established. The report retains eight unresolved geometry records, one unsupported material, 664 inactive spans and six crossing-boundary deferrals. Legacy scripts and runtime behavior are unchanged. Whole-project clean assembly and gameplay acceptance require separate verification.
