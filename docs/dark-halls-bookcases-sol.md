# Dark Halls P4: secret bookcase doors

In progress. Component proof passed; earned bookcase59 traversal passed. Bookcases51/58 need earned approaches, original motion comparison and owner acceptance remain open.

## Meta duck

1. Problem: r17 draws bookcases51/58/59 as walk-through scenery; owner reports17-19-42,17-13-57,17-08-18 identify missing doors.
2. Chain: Dark Halls optional; explicitly assigned functional door repair. Do not expand into unrelated visual polish.
3. Intent: exploration reveals secret passages, rather than granting loot directly. HINTBOOK2431-2435,2480-2481,2526-2528; native four use groups. H10 pins every record.
4. Contract: approach and use a bookshelf;51/59 open once,58 toggles. Solid closed; passage traversable open; state persists. No item grants in these groups. Existing separate loot remains separate.
5. Exact: identities, input/use event, one-way versus toggle behavior, native travel magnitude100/60/116, closed solidity, traversal and saves. Approximate: E/reach/facing adapter, mesh-bound leaf collision and local horizontal translation. Native placement modes2/4 are not decoded as direction; the chosen local sideways vector is explicitly a presentation adapter pending original comparison. No invented rewards or locks.
6. Smallest option: native_script_host dispatch for kind4 and opcodes1/9/16/20; own solid mesh leaves so motion and collider move together. Separate boolean quest key preserves old saves with no new key. The native opcode1_other_modes adapter supplies the travel word, not proof of the rendered direction.
7. Component proof dark_halls_bookcases_test: actual physics rays across closed/open doorway; native state handling including repeat use, strict saves and disk rollback. Earned test: pinned repaired-monastery save -> actual cellar hotspots -> original entry -> W/Shift/mouse with live enemies -> approach59 -> E -> walk across threshold -> F5/reload. No goal placement or population disabling. Remaining51/58 routes and original comparison must still pass. Owner clears only after playtest.
8. Recorded here, in the deviation piece and on the shared board at checkpoint.

Builder read: retain the common native host and move the visible shelf and its collider as one object. Risks: local horizontal direction differs from original; a shortest floor route enters from the wrong side; repeat use of a one-way shelf inadvertently toggles. Flip point: original footage could establish slide direction for each native mode. Next check: inspect earned59 captures and verify it actually walks across the threshold after E.

Earned59: tmp/sol_bookcases_earned_first/report.json PASS/source_stable (68.39s); closed/open/through captures inspected. Component tests bookcases+slides2/2 PASS. godot_check8/0; ledger --check PASS. Affected execution remains pending before handover.

## r19 restoration (Sol, 2026-11-09)

Restored on r19-work 0603225 in private branch sol/dark-halls-r19-20261109 by reversing the r18 holdback b5c0fd8 (the old 36c5cee is already an ancestor). The three holdback failures were reproduced locally. The body apply helper now records its applied form as transient metadata, so crouch reconciliation preserves a directly applied Lizard/Beast even when the scene field is stale. Bookcase aiming excludes the target leaf and checks the whole line for other blockers; the oblique and intervening-wall assertions both pass.

The legacy slice crossed bookcases59 and51 before their solids were hosted. It now aims and presses E from the reachable visible approach before crossing, retaining their solids. The separate earned tests exercise player input and active combat. No native gate, timer, reach or form dimensions changed. Registry helper omission corrected; restored tests assigned 1010–1017. Compile/ledger/registry checks pass. Final targeted and full affected receipts are in tmp/sol_r19_targeted2 and tmp/sol_sweep_0..3/report; consult actual reports for status. Owner acceptance and lead Kimi review remain open.
