# Wild Village earned loop — milestone2

Production `c39a342`:7/7 PASS in 644.01s. Fresh, fail-fast STORY028..034 continuation from the pinned milestone1 shore save; no inventory merges, seeds or stale output reuse.

Run `LANE_NICE=19 tools/run_lane.sh 24-31 -- python3 tools/run_act2_wild_village_earned_loop.py --output tmp/FRESH_DIRECTORY`. The driver snapshots production sources and rejects any drift.

Report `tmp/act2_wild_village_qualified/route_report.json`, SHA256 `3f7bcbbaa381d7c22f98207f683c686a70a16d01d8cc01ef0849665d30957a18`.

Final earned save `tmp/act2_wild_village_qualified/l8_clubhouse_earned_save.json`, SHA256 `02cfe975f0e0dcf98e60d23b4b9e403ef2ce701f200c01115be704568c0c58f6`. It carries seven remaining Silverleaves, Amaranth Serum119 and original Ancients Stones32/33/34; tribe phase departed and clubhouse open. All seven semantic slices include persistence checks. Separate yield qualification is not merged into this route.

Original source and adapter limits remain in each slice document and DEVIATIONS0248..0254. STORY004 B1 room-view navigation remains open; this milestone does not claim full native presentation parity.
