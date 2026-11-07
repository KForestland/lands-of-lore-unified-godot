# Monastery garden and cellar

The hall's original hotspot2 now opens MGAR (garden), and hotspot0 opens MCEL
(cellar) only after flag134, earned from Julian's first conversation. Existing
library and office hotspots remain unchanged. Admission was recovered from the
MENT callback, rather than inferred from room names.

Garden setup installs Morgan only when the original flags permit it:181 and259
exclude him; an unvisited garden after140 excludes him;260 requires an owned
Power Orb. First presence sets Met_Morgan. Entry sets258 before the original
150–163 clips, and176/177/178 after them. A normal repeat plays200–203, then sets260.
Power Orb acquisition and Morgan’s blessing/returned-orb branch are now integrated;
`broken_repair_earned_walk_test` checks them after translation and Julian’s delayed
orb grant. The absent-NPC room remains visitable.

Cellar setup shows Rix only before170 and while GV_RIX_DEAD is clear, setting171.
Meeting Dawn (Met_Dawn) admits his first entry conversation:170 is written before
100–112. A saved partial conversation retains the actor's presence even though
170 is already set. A subsequent room visit correctly finds him absent. The
original600-unit hold timer and side-hotspot response pool remain separate.

`tools/prepare_monastery_side_rooms.py` executes original callback instructions
with explicit host boundaries, checks40 actor-admission cases, and stages31
original dialogue clips, two animated backgrounds and two idle patches. Exact
frame/PCM counts are checked by the shared media staging code. These assets
remain local.

Four focused regressions pass in
`tmp/regressions/monastery_side_20260927/report.json`, including native-admission
fixture matching, original playback, first/repeat/absence behavior, delayed flag
writes and partial disk saves. The cellar image was visually inspected. The
isolated test supplies Julian/Dawn prerequisites. The expanded cave-derived
shop route now visits both rooms using already earned prerequisites and natural
playback (80.78s total); see `docs/weapon-shop-earned-walk-checks.json`. No full Act One or original presentation acceptance is implied.
