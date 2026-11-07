extends RefCounted
## Mechanism transaction (KIT-API, roadmap 2026-11-01 round 2; astra_round2.md section 1).
## One small, pure-data contract for world mechanisms that take an item from the player: a slot, a charger, a receptacle.
## Every call takes a snapshot and returns {"ok": true, "snapshot": NEW} or {"ok": false, "reason": TEXT}; the input
## snapshot is never mutated, so a refused or interrupted action can't consume an item or grant a reward halfway.
##   offer(snapshot, recipe, item_id, context) -> proposal | refusal   (validates only)
##   occupy(snapshot, proposal)                 -> transaction | refusal   (item moves inventory -> slot)
##   commit(snapshot, recipe, event_id)         -> transaction | refusal   (once: ready/output/world change + receipt)
##   retrieve(snapshot, recipe)                 -> transaction | refusal   (slot -> inventory, capacity-checked, never twice)
##   refuse(reason)                             -> refusal
## Snapshot: {"version": 1, "inventory": [item ids], "capacity": int, "slots": {target: {"occupied": id, "committed": bool,
## "receipts": [event ids]}}}. Hosts map their own save state to and from it (no second inventory). Load restores the
## world (floor shown, charger lit) from "committed", never by replaying commit.
## Recipe: {"target": id, "accepts": [item ids], "output": id or "" (the occupied item is transformed on commit; "{item}"
## in it is replaced by the occupied instance id, so two charged globes keep unique ids), "retrievable": bool,
## "repeatable": bool (true: taking the output out resets the slot for the next cycle, receipts kept; false: committed
## stays, e.g. the slid floor), "forms": [allowed player forms] or [] for any}. Recipe behaviour comes from a cited source.

const VERSION := 1


static func refuse(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


static func empty_snapshot(inventory: Array = [], capacity: int = 25) -> Dictionary:
	return {"version": VERSION, "inventory": inventory.duplicate(), "capacity": capacity, "slots": {}}


static func slot(snapshot: Dictionary, target: String) -> Dictionary:
	var slots: Dictionary = snapshot.get("slots", {})
	if slots.has(target): return slots[target]
	return {"occupied": "", "committed": false, "receipts": []}


static func validate(snapshot: Variant) -> String:
	if not snapshot is Dictionary: return "snapshot is not a dictionary"
	var s: Dictionary = snapshot
	if int(s.get("version", 0)) != VERSION: return "unsupported mechanism snapshot version %s" % str(s.get("version"))
	if not s.get("inventory") is Array or not s.get("slots") is Dictionary: return "snapshot needs inventory and slots"
	if int(s.get("capacity", -1)) < 0: return "snapshot needs a capacity"
	var slots: Dictionary = s.slots
	for target: Variant in slots:
		var entry: Variant = slots[target]
		if not entry is Dictionary or not entry.get("occupied") is String or not entry.get("committed") is bool or not entry.get("receipts") is Array:
			return "slot %s is malformed" % str(target)
	return ""


static func offer(snapshot: Dictionary, recipe: Dictionary, item_id: String, context: Dictionary = {}) -> Dictionary:
	var target: String = recipe.get("target", "")
	if target.is_empty(): return refuse("recipe has no target")
	if not bool(context.get("in_reach", true)): return refuse("too far from %s" % target)
	var forms: Array = recipe.get("forms", [])
	if not forms.is_empty() and not forms.has(context.get("form", "human")): return refuse("this form cannot use %s" % target)
	var inventory: Array = snapshot.get("inventory", [])
	if not inventory.has(item_id): return refuse("%s is not carried" % item_id)
	var accepts: Array = recipe.get("accepts", [])
	if not accepts.has(item_id): return refuse("%s does not fit %s" % [item_id, target])
	if not slot(snapshot, target).occupied.is_empty(): return refuse("%s is already occupied" % target)
	return {"ok": true, "proposal": {"target": target, "item": item_id, "count": inventory.count(item_id)}}


static func occupy(snapshot: Dictionary, proposal: Dictionary) -> Dictionary:
	var target: String = proposal.get("target", "")
	var item: String = proposal.get("item", "")
	var inventory: Array = snapshot.get("inventory", [])
	if inventory.count(item) != int(proposal.get("count", -1)): return refuse("stale proposal for %s" % target)
	if not slot(snapshot, target).occupied.is_empty(): return refuse("%s is already occupied" % target)
	var next: Dictionary = snapshot.duplicate(true)
	var next_inventory: Array = next.inventory
	next_inventory.erase(item)
	var entry: Dictionary = slot(snapshot, target).duplicate(true)
	entry.occupied = item
	next.slots[target] = entry
	return {"ok": true, "snapshot": next}


static func commit(snapshot: Dictionary, recipe: Dictionary, event_id: String) -> Dictionary:
	var target: String = recipe.get("target", "")
	var entry: Dictionary = slot(snapshot, target)
	if entry.occupied.is_empty(): return refuse("%s is empty" % target)
	if entry.committed: return refuse("%s already happened" % target)
	var next: Dictionary = snapshot.duplicate(true)
	var changed: Dictionary = entry.duplicate(true)
	changed.committed = true
	var output: String = recipe.get("output", "")
	if not output.is_empty(): changed.occupied = output.replace("{item}", entry.occupied)
	var receipts: Array = changed.receipts
	receipts.append(event_id)
	next.slots[target] = changed
	return {"ok": true, "snapshot": next}


static func retrieve(snapshot: Dictionary, recipe: Dictionary) -> Dictionary:
	var target: String = recipe.get("target", "")
	if not bool(recipe.get("retrievable", false)): return refuse("%s keeps what it holds" % target)
	var entry: Dictionary = slot(snapshot, target)
	if entry.occupied.is_empty(): return refuse("%s is empty" % target)
	var inventory: Array = snapshot.get("inventory", [])
	if inventory.size() >= int(snapshot.get("capacity", 0)): return refuse("no room to carry %s" % entry.occupied)
	var next: Dictionary = snapshot.duplicate(true)
	var next_inventory: Array = next.inventory
	next_inventory.append(entry.occupied)
	var changed: Dictionary = entry.duplicate(true)
	changed.occupied = ""
	if bool(recipe.get("repeatable", false)): changed.committed = false  # next cycle; receipts keep the history
	next.slots[target] = changed
	return {"ok": true, "snapshot": next}
