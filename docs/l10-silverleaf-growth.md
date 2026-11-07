# Emperor revisit and Silverleaf growth

STORY-030 starts at the actual STORY029 save, walks from Baccata's clearing to
the native L8 exit, arrives at L10 selector1, passes the already-open main gate
and walks to the original Emperor sarcophagus. Without the surrendered bracers,
the conversation is unintelligible and the twelve original Silverleaf props grow.
No leaves are added to inventory at this stage.

`docs/l10-silverleaf-source.json` records15 byte-pinned objects and31 groups.
Reproduce with `python3 tools/verify_l10_silverleaf_source.py --game GAME`.
Prop254 kind6/value0 group11762 links props159..170. Each tree's kind4/mode0
event grants identity0E347A01, original definition117, then advances its state.
Source region3819/group988 links prop254 after a native predicate; region3789
has the original room callback. Their native flag meanings are not inferred.
The admitted sequence is explicitly book-led (Prima90/104), DEVIATIONS0250.
The original sprites are Silverleaf growth; they replace their prior unconditional
display with the saved growth state. One owner `l10_silverleaf` controls this.

Qualification: `tmp/regressions/l10_silverleaf_growth_probe/report.json`,1/1 PASS.
Earned input `tmp/l8_baccata_earned_save.json`; output
`tmp/l10_silverleaf_growth_earned_save.json`. Tests exercise remote refusal,
actual physical sarcophagus interaction, all12 visible source props, unchanged
inventory, repeat refusal and save/reload. No arrival seeds or fall recovery.
