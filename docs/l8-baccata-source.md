# Baccata's trap rescue

STORY-029 starts from the actual `tmp/l8_dawn_earned_save.json` output of
STORY-028. The walking fixture follows the original L8 region portals from
shore region66 to region254, with ordinary grounded movement and live combat.

Original L8 source archive SHA256:
`3eff07430a453d2c6f09133f869874e0530af1b6a3bfff7f4297761b96a28bc2`.
Prop100/template32 and prop101/template30 are coincident at
(4549/4550,100,-1006). Actor116/definition8 BACL8 stands at(4549,0,-1005).
Props1117/1122 at that location have callbacks linking actor116:
for example group9604 contains `090274000300`; group11282 likewise links
actor116 and writes actor commands13/7. Their conversation conditions and
full native state sequence remain unjoined.

The source prop export maps initial selector0 to external movie `bc08.vqa`,
descriptor253. `tools/prepare_l8_baccata.py` reproduces47 original frames at15fps
from SPHERE2\\L8_SJ\\BC08.VQA in DAT/L8_SJI.MIX. Movie SHA256
`2de265038589dd81c5916ee73d9b334cf90a36dccb5cfb0604a30e1cfea77314`.
These are **standing** Baccata pixels. The upside-down billboard is an explicit
modern trap-presentation adapter, not a recovered hanging animation. The two
static foliage fallback images are hidden to avoid overlapping presentation.

Prima90/117 supplies cutting him free, conversation and departure. Brady103
also allows attack/leave; those alternatives are not claimed by this slice.
The rescue uses E with a carried sword/dagger/blade, preserves the inventory,
then a second E presents a narrated conversation summary and starts a saved
five-second departure. The original actor moves south within the clearing,
then disappears. Timing, steering, admission and summary are modern adapters.
No invented dialogue quotation, reward, native speech or later attitude claim.

The saved phase and departure clock are validated; no rescue without the
actual shore receipt. Pause suspends departure; save/reload resumes it. An
already completed rescue never restores the trap or grants anything.

Qualification: `tmp/regressions/l8_baccata_ready/report.json`, 1/1 PASS108.00s,
source stable. Actual earned Dawn save ->78 portal waypoints with live combat ->
cut/talk/depart -> pause and mid-departure save/reload -> final earned save
`tmp/l8_baccata_earned_save.json`. The initial failed run exposed JSON numeric
phase validation; the corrected validator accepts integral JSON numbers.
