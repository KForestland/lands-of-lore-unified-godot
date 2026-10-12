extends RefCounted
## Cross-area player continuity check (docs/player-continuity.md). Reads the EXISTING owners only — Cave
## _completion_state(), Museum/Jungle inventory_state() (+ Jungle quest-owned magic/fighting), Hive area_handoff(),
## or a save/handoff packet — and flattens them into one semantic snapshot. compare() lists every difference that is
## not an explicitly allowed change. A field present before and absent after is always a failure.
const Fighting = preload("res://scripts/lol2/player_fighting_transport.gd")
const Magic = preload("res://scripts/lol2/player_magic_state.gd")

## Snapshot of a live area host (Cave, Museum, Jungle or Hive).
static func from_host(host: Node) -> Dictionary:
	if host.has_method("_completion_state"): return from_packet(host._completion_state(), {})
	if host.has_method("area_handoff") and host.has_node("Warriors"):
		var handoff: Dictionary = host.area_handoff()
		return from_packet(handoff.inventory, handoff.quests)
	var quests = host.get("quest_state")
	return from_packet(host.inventory_state(), quests if quests is Dictionary else {})

## Snapshot of a save or handoff: Museum checkpoint saves, {inventory, quests} saves/handoffs, or a bare packet.
static func from_save(state: Dictionary) -> Dictionary:
	if state.get("checkpoint") is Dictionary: return from_packet(state.checkpoint, {})
	if state.get("inventory") is Dictionary: return from_packet(state.inventory, state.get("quests", {}))
	return from_packet(state, {})

## Inventory packet fields win over quest-owned fields (the same precedence the Jungle/Hive loaders use).
static func from_packet(inventory: Dictionary, quests: Dictionary) -> Dictionary:
	var result := {}
	for key in ["health", "player_form", "equipped_item", "equipped_armor"]:
		if inventory.has(key): result[key] = inventory[key]
	if inventory.get("collected") is Array:
		for id in inventory.collected:
			var key := "collected[%s]" % id
			result[key] = int(result.get(key, 0)) + 1
	if inventory.get("curse") is Dictionary:
		for key in ["phase", "cave_triggered"]:
			if inventory.curse.has(key): result["curse." + key] = inventory.curse[key]
	if inventory.get("item_effects") is Dictionary:
		var effects: Dictionary = inventory.item_effects
		for id in effects.get("spent", []):
			var key := "spent[%s]" % id
			result[key] = int(result.get(key, 0)) + 1
		for key in ["ancient_charges", "offhand", "dampened"]:
			if effects.has(key): result["item_effects." + key] = effects[key]
		if effects.get("aloe") is Dictionary:
			for key in ["pending", "base"]: result["item_effects.aloe." + key] = effects.aloe.get(key)
		if effects.get("fire_crystals") is Dictionary:
			for id in effects.fire_crystals: result["item_effects.fire_crystals[%s]" % id] = effects.fire_crystals[id]
	var magic = inventory.get("magic", quests.get("player_magic_reward_state"))
	if magic is Dictionary and magic.get("player") is Dictionary:
		for key in ["level", "experience", "mana", "maximum"]: result["magic." + key] = magic.player.get(key)
		# Check source presence; migration/defaults belong to the actual loader.
		if magic.has("spell"): result["magic.spell"] = magic.spell
	var fighting = null
	if inventory.get("fighting") is Dictionary: fighting = inventory.fighting.get("player_reward_state")
	if fighting == null: fighting = quests.get("player_reward_state")
	if fighting is Dictionary and fighting.get("player") is Dictionary:
		for key in ["level", "experience", "maximum", "health", "condition", "stat151", "stat155"]: result["fighting." + key] = fighting.player.get(key)
	return _normalized(result)

static func _normalized(snapshot: Dictionary) -> Dictionary:
	for key in snapshot:
		var value = snapshot[key]
		if value is float and value == floorf(value): snapshot[key] = int(value)
	return snapshot

## Differences between two snapshots that `allowed` does not explain. `allowed` maps a field to the value it must
## have afterwards (an exact value, null = removed on purpose, or {"min":a,"max":b} for documented elapsed-time drift).
## An allowed change that did not happen is reported too, so each permission is exercised, not merely tolerated.
static func compare(before: Dictionary, after: Dictionary, allowed: Dictionary = {}) -> Array:
	var errors: Array = []
	var keys: Array = before.keys()
	for key in after.keys() + allowed.keys():
		if key not in keys: keys.append(key)
	keys.sort()
	for key in keys:
		if allowed.has(key):
			var rule = allowed[key]
			if rule is Dictionary:
				if not _finite_number(rule.get("min")) or not _finite_number(rule.get("max")) or float(rule.min) > float(rule.max) or not rule.get("reason") is String or str(rule.reason).strip_edges().is_empty():
					errors.append("%s: invalid numeric allowance" % key)
				elif not after.has(key) or not _finite_number(after[key]) or float(after[key]) < float(rule.min) or float(after[key]) > float(rule.max):
					errors.append("%s: %s outside allowed %s..%s" % [key, after.get(key, "<missing>"), rule.min, rule.max])
			elif rule == null:
				if after.has(key): errors.append("%s: expected removal, still %s" % [key, after[key]])
			elif not after.has(key) or after[key] != rule:
				errors.append("%s: expected %s, got %s" % [key, rule, after.get(key, "<missing>")])
			continue
		if not after.has(key): errors.append("%s: missing after (was %s)" % [key, before[key]])
		elif not before.has(key): errors.append("%s: appeared unexpectedly (%s)" % [key, after[key]])
		elif before[key] != after[key]: errors.append("%s: %s -> %s" % [key, before[key], after[key]])
	return errors

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

## Upper bound using the original checkpoint remainder and measured simulated time. World pause can reduce
## regeneration, never increase this bound. Invalid inputs produce a rule that compare() refuses.
static func mana_allowance(mana: int, maximum: int, elapsed: float, remainder: float) -> Dictionary:
	var period: float = Magic.Progress.CAST_REGEN_SECONDS
	if mana < 0 or maximum < mana or not is_finite(elapsed) or elapsed < 0 or not is_finite(remainder) or remainder < 0 or remainder >= period:
		return {"reason":"invalid regeneration clock"}
	var gain := int(floor((elapsed + remainder) / period))
	return {"min":mana, "max":mini(maximum, mana + gain), "reason":"measured simulated seconds %.6f + carried remainder %.6f" % [elapsed, remainder]}
