extends SceneTree
## KIT-API: the mechanism transaction contract (offer / occupy / commit / retrieve / refuse) on two recipes:
## the Hive flute slot (Prima pp.78/81: the iron flute in the slot slides a green floor over the oil; retrievable so the
## lift can still be summoned) and a cemetery charger (an empty globe becomes a charged one; astra_round2.md).
const M := preload("res://scripts/lol2/mechanism_transaction.gd")
const FLUTE_SLOT := {"target": "hive:flute_slot", "accepts": ["iron_flute"], "output": "", "retrievable": true, "forms": ["human", "beast"]}
const CHARGER := {"target": "l10:gold_charger", "accepts": ["empty_globe"], "output": "gold_globe", "retrievable": true, "repeatable": true, "forms": []}
const WHITE := {"target": "l9:white_charger", "accepts": ["l10:globe:1", "l10:globe:2"], "output": "{item}:white", "retrievable": true, "repeatable": true, "forms": []}
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


func _initialize() -> void:
	var start := M.empty_snapshot(["iron_flute", "aloe"], 3)
	check(M.validate(start).is_empty(), "a fresh snapshot validates")
	# Refusals change nothing.
	check(not M.offer(start, FLUTE_SLOT, "aloe").ok, "a wrong item is refused")
	check(not M.offer(start, FLUTE_SLOT, "empty_globe").ok, "an item not carried is refused")
	check(not M.offer(start, FLUTE_SLOT, "iron_flute", {"in_reach": false}).ok, "out of reach is refused")
	check(not M.offer(start, FLUTE_SLOT, "iron_flute", {"form": "lizard"}).ok, "the lizard cannot use the slot")
	# Offer -> occupy -> commit.
	var proposal: Dictionary = M.offer(start, FLUTE_SLOT, "iron_flute")
	check(proposal.ok, "the flute fits the slot")
	var occupied: Dictionary = M.occupy(start, proposal.proposal)
	check(occupied.ok and not occupied.snapshot.inventory.has("iron_flute"), "occupy moves the flute out of the inventory")
	check(start.inventory.has("iron_flute") and M.slot(start, "hive:flute_slot").occupied.is_empty(), "the input snapshot is unchanged")
	check(not M.occupy(occupied.snapshot, proposal.proposal).ok, "a stale proposal cannot occupy twice")
	var committed: Dictionary = M.commit(occupied.snapshot, FLUTE_SLOT, "flute_floor_slid")
	check(committed.ok and M.slot(committed.snapshot, "hive:flute_slot").committed, "commit marks the floor as slid")
	check(not M.commit(committed.snapshot, FLUTE_SLOT, "again").ok, "commit happens once")
	# Save/reload: JSON roundtrip keeps the committed state.
	var reloaded: Variant = JSON.parse_string(JSON.stringify(committed.snapshot))
	check(M.validate(reloaded).is_empty() and M.slot(reloaded, "hive:flute_slot").committed, "the committed floor survives save/reload")
	# Retrieve the flute; the floor stays; a second retrieve is refused.
	var back: Dictionary = M.retrieve(reloaded, FLUTE_SLOT)
	check(back.ok and back.snapshot.inventory.count("iron_flute") == 1 and M.slot(back.snapshot, "hive:flute_slot").committed, "the flute comes back and the floor stays")
	check(not M.retrieve(back.snapshot, FLUTE_SLOT).ok, "the flute cannot be retrieved twice")
	# Charger: the occupied globe is transformed on commit; a full inventory refuses retrieval without losing it.
	var globe_start := M.empty_snapshot(["empty_globe", "a", "b"], 3)
	var charged: Dictionary = M.commit(M.occupy(globe_start, M.offer(globe_start, CHARGER, "empty_globe").proposal).snapshot, CHARGER, "gold_charged")
	check(M.slot(charged.snapshot, "l10:gold_charger").occupied == "gold_globe", "the charger turns the empty globe into a gold globe")
	var crowded: Dictionary = charged.snapshot.duplicate(true)
	crowded.inventory.append("c")
	check(not M.retrieve(crowded, CHARGER).ok and M.slot(crowded, "l10:gold_charger").occupied == "gold_globe", "a full inventory keeps the globe in the charger")
	var got: Dictionary = M.retrieve(charged.snapshot, CHARGER)
	check(got.ok and got.snapshot.inventory.count("gold_globe") == 1 and not got.snapshot.inventory.has("empty_globe"), "one charged globe out, no duplicate")
	check(not M.offer(got.snapshot, CHARGER, "gold_globe").ok, "a charged globe does not fit the charger again")
	# Repeatable cycles with unique instance ids (astra review of 85c8f42): two distinct globes, two distinct outputs.
	var two := M.empty_snapshot(["l10:globe:1", "l10:globe:2"], 5)
	for globe: String in ["l10:globe:1", "l10:globe:2"]:
		var step: Dictionary = M.offer(two, WHITE, globe)
		check(step.ok, "%s fits the white charger" % globe)
		two = M.occupy(two, step.proposal).snapshot
		var lit: Dictionary = M.commit(two, WHITE, "white:" + globe)
		check(lit.ok, "%s is charged (a new cycle after the first retrieve)" % globe)
		two = M.retrieve(lit.snapshot, WHITE).snapshot
	check(two.inventory.has("l10:globe:1:white") and two.inventory.has("l10:globe:2:white") and two.inventory.size() == 2, "two unique charged globes, no duplicate id")
	check(M.slot(two, "l9:white_charger").receipts.size() == 2 and not M.slot(two, "l9:white_charger").committed, "receipts keep both cycles; the charger is ready again")
	check(M.slot(back.snapshot, "hive:flute_slot").committed, "a non-repeatable slot stays committed after retrieve (the floor stays)")
	check(not M.validate({"version": 1, "inventory": [], "capacity": 3, "slots": {"x": {"occupied": 5}}}).is_empty(), "a malformed slot is rejected on load")
	print("Mechanism transaction: %d failures" % failures)
	if failures == 0: print("PASS mechanism_transaction")
	quit(1 if failures else 0)
