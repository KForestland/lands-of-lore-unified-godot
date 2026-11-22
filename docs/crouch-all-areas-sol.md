# P5: crouch in every area

In progress; owner clearance open.

## Meta duck

1. Problem: C crouches only in the Museum; r17 Dark Halls report17-07-18 cannot crawl through the webbed opening near entry.
2. Chain: shared movement behavior explicitly assigned by the owner; no unrelated map edits.
3. Intent: teach/gate: low openings require the Human to crouch, then allow standing only after the head clears the ceiling.
4. Contract: hold C -> existing Human capsule32/eye28; release -> Human46/eye42 if space allows; remain low under an obstruction; other forms retain their own shapes. The Museum already establishes these mechanics. Native L7 region65 at the reported opening has floor116 and ceiling156, a40-unit gap; neighboring region71 is floor85/ceiling175, region123 floor116/ceiling206. Generated geometry is direct source evidence for the gap, rather than a reason to edit the wall.
5. Exact: C hold, Human-only, collision and clearance, no standing through a ceiling, no new world geometry, existing form/quest/inventory semantics. Approximate: Museum's already-documented32-unit capsule and28-unit eye apply to all areas. No new crouch speed/timer introduced. Crouch posture is transient input state and is reconciled after a save/body rebuild.
6. Smallest option: player_crouch.gd owns the existing Museum logic; Museum, Jungle and original Cave walk bases call it. Their derived areas inherit it. Form changes and save loads can rebuild the collider; the helper re-applies held crouch if that happened. No input while mouse is released/paused/flying.
7. Proof: museum_crouch_test remains required. dark_halls_crouch_earned_test starts from the pinned r17 repaired-monastery save, clicks the cellar and entry, walks and fights to the original opening, checks a standing attempt is blocked, holds C and walks under region65, releases C under the header (must stay crouched), walks clear and releases C (must stand). Captures and no geometry edits. Full affected tests plus owner playtest remain gates.
8. Recorded here, in deviation ledger and board checkpoint; task stays claimed until reviewed proof is complete.

Builder read: change the player's body using the existing shape owner, not the crawlspace. Risks: the old crouched boolean diverges from a collider rebuilt on reload; a form transition retains Human-only posture; a synthetic input test silently substitutes for an earned walk. Flip point: physical traversal of native region65 proves whether the player-only change suffices. Next check: run that earned standing-versus-C traversal with the actual movement code and live enemies.

Proof: tmp/sol_crouch_earned_first/report.json2/2 PASS/source stable (earned Dark Halls30.66s, Museum4.06s). Header and clear captures inspected. godot_check13/0. Final slide/bookcase/Museum components3/3 PASS after aiming-ray and silent-restore hardening. Affected687/952 selected; sweep pending.

## Low-header save/reload correction

An earned negative control reproduced standing-body reconstruction inside native region65: F5 while crouched under the40-unit header, walk clear and release C, reload that real save. The previous helper left Human46 inside the ceiling (tmp/sol_crouch_reload_negative/report.json FAIL40.98s). This was a player-body restore bug, not a map problem.

player_form_body.gd now records transient body posture and marks forced shape rebuilds for clearance reconciliation. On the first movement tick, player_crouch.gd fits the Human standing if possible, otherwise crouched, using the existing overlap query. The host's posture flag follows the body's actual applied posture, so a force-restored shape cannot diverge from an old cached flag. No save format/quest/inventory fields or world geometry change. A released C remains unable to stand under the header and automatically stands when the player walks clear.

The same earned walk then passed, including the actual low-header F5/reload and a second walk clear without C held; Museum crouch also passed: tmp/sol_crouch_reload_fixed/report.json2/2 PASS/source_stable (35.70s/3.98s). These results belong to the dedicated lol2_sol_crouch_restore snapshot; the earlier affected sweep tests the older snapshot and is not final qualification for this correction.

## r19 restoration (Sol, 2026-11-09)

Restored on r19-work 0603225 in private branch sol/dark-halls-r19-20261109 by reversing the r18 holdback b5c0fd8 (the old 36c5cee is already an ancestor). The three holdback failures were reproduced locally. The body apply helper now records its applied form as transient metadata, so crouch reconciliation preserves a directly applied Lizard/Beast even when the scene field is stale. Bookcase aiming excludes the target leaf and checks the whole line for other blockers; the oblique and intervening-wall assertions both pass.

The legacy slice crossed bookcases59 and51 before their solids were hosted. It now aims and presses E from the reachable visible approach before crossing, retaining their solids. The separate earned tests exercise player input and active combat. No native gate, timer, reach or form dimensions changed. Registry helper omission corrected; restored tests assigned 1010–1017. Compile/ledger/registry checks pass. Final targeted and full affected receipts are in tmp/sol_r19_targeted2 and tmp/sol_sweep_0..3/report; consult actual reports for status. Owner acceptance and lead Kimi review remain open.
