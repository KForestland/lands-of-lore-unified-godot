# Task D review — Astra, 2026-10-31

Baseline r12v f50d945, own worktree lol2_astraleftovers. Headless/source-data review only; earlier reserved captures reused, no new rendered run. `source_audit.json` independently checks original archive hashes, every exported native wall-record identity, and material file existence for the five maps. No missing native wall records or missing material files in any of the five. Extra record IDs are producer boundary/floorless supplements, not claims of extra original walls.

## D1 — five Act 2/3 maps

Frame times below use the lead's exact formula t=6580+(N-1)*30, correcting the earlier Fable sheet labels by 10s for L13/L16. Original camera/region alignment remains UNKNOWN; these are broad appearance comparisons, not pixel-aligned fidelity tests.

| Area | Directly viewed reference | Finding / change |
|---|---|---|
| L8_SJ | Existing L8 night capture/reference evidence (Fable); source pack | Native walls and props accounted. Existing own-palette sector shader retained; bare tree tops have original trunk art and distance darkness/pitch adapter. No new invented crowns. |
| L10_DC | Fable side-by-side, g_00057 at137:40 | Tomb/fence environment present in old port capture; original has much darker stone. PROVEN omission: native sector data in14330 faces was unused by generic host. Added per-sector depth shading using L10's own palette table. The images are different positions; no missing tomb/fence claim. |
| L13_RC | Side-by-side, g_00187 at202:40 | Original dark Ruloi hall and port have compatible stone floor/wall motifs; port is full-bright.4531 source-lit faces now use L13 shade rows. Purple crystal present in old port; exact source viewpoint UNKNOWN. |
| L16_CA | Side-by-side, g_00296 at257:10 | Old capture is selector3 underground tunnel; original frame is outdoor lava/city. Cannot infer missing outdoor city from unlike arrivals. Current producer starts selector1 per existing lead decision.29137 source-lit faces now use L16 shade rows; bright palette ratios above1 retained as source-derived, not clamped to an invented dark curve. |
| L19_BC | Side-by-side, g_00374 at296:10 CANDIDATE | Roofed ornate room and floor present; longplay colour candidate is not a bound camera.9049 source-lit faces now use L19 own shade rows. No panorama invented for a roofed map. |

Implementation: act2_sector_light.gd reuses L8's shader formula and colour-table adapter, keeps per-face operands and prop custom data, nearest-height containing-floor fallback for unbound assemblies, initial-floor light for movers. `sector_light_enabled` reverts per host. Static animation texture replacements are forwarded to shader overrides. Actor/item lighting, native palette remapping per pixel, moving-sector relighting and exact panorama parity remain outside this patch. Four W4 DEVIATIONS rows; test verifies all four palettes/operands, animation and revert. Render comparison remains pending the lead's grant.

## D2 — Hive owner reports

Owner screenshots09-50-03 and09-50-35 were opened directly. Original f_00489/f_00500/f_00510 were opened directly: lava-rock floor, gas shapes and rock pillars visible; f_00500 is a plausible hall reference, exact coordinates UNKNOWN.

-09-50-03 bridge: source regions121/122/1004 have valid floor polygons at-235 and opaque material21. Material21 image directly inspected: lava-rock, no alpha holes. The screenshot's bridge top shares lava-rock texture with the lower room, which can obscure its outline. Native exported edge2 to region116 has no parapet (prior S1 source analysis). No data omission found; exact alleged hole and original parapet remain UNKNOWN. Adding side walls would invent geometry without a bound reference.
-09-50-35 platforms: regions846/862/845 have source floors at-265/-275/-255 and valid polygons. No missing floor identified. Whether the owner means a scripted raised platform is UNKNOWN; mechanisms are explicitly Fable/lead scope. No fabricated platform inserted.
-09-51-11 boulder gap: regions1067,387-390 are in current native bit0 blocker set; existing Hive host enables it. Prior S1 fix retained, source regression check added.
-10-32-17 brazier wall: original records1609/1610 are represented in current pack; prior S1 visual fix retained. Native special-connector traversal remains UNKNOWN, distinct from missing drawn wall.

## D3 — Cave/Jungle owner reports

-09-18-05: viewed Terra pair with f_00157. Owner is under bridge; original candidate is above it. Collision cannot be inferred from that pair. Records1484-1487 are staged: step/lintel and adjoining walls preserve the41-unit opening; native regions1081/1102 are not bit0 blocked. The85-unit step/special-connector refusal remains UNKNOWN. No wall-collision copy added: prior S1 trials blocked Spark/earned routes. Needs a matched original traversal witness, not an invented patch.
-09-32-52: S1 source finding retained: no native wall/ceiling within350 units; region4439 edge1/3 lacks original wall records above the gorge. Original view at that exact location UNKNOWN; no wall fabricated.
-09-29-20: verification-only complete. Placement5211 uses prop_727, original bare-trunk art (64x200, native box28x100). No crown placement within300 in S1 source census. Existing Fable conclusion retained; no extra crown added.

The source geometry findings are PROVEN about staged data only. The unresolved original viewpoints/behavior stay UNKNOWN. No original-game bug has been proven by this review, so no invented ORIGINAL_BUGS_TO_FIX entry. New headless map_leftovers_data_test protects the exact source floors, opacity, brazier records, blockers, Cave records and tree identity; it does not pretend to prove original collision or rendered fidelity.
