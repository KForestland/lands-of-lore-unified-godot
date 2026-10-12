extends RefCounted
## Restoration save state; original chain IDs and two-cut release rule retained.
const Rule = preload("res://scripts/lol2/river_chain_rule.gd")
const FALL_SECONDS := 0.7
const CHAIN_SECONDS := 25.0/15.0

static func validate(value: Variant) -> bool:
	if not value is Dictionary or not value.get("warning_played") is bool: return false
	if not value.get("cuts") is Array or not value.get("sections") is Array: return false
	if value.sections.size() != 6: return false
	var seen := {}
	var counts := {}
	for cut in value.cuts:
		if not cut is Dictionary: return false
		var id = cut.get("id")
		if not (id is int or id is float) or not is_finite(float(id)) or id != floorf(float(id)): return false
		id = int(id)
		if not Rule.LINKS.has(id) or seen.has(id): return false
		if not _time(cut.get("elapsed"), 0.0, CHAIN_SECONDS): return false
		seen[id] = true
		var section: int = Rule.LINKS[id]
		counts[section] = counts.get(section, 0)+1
		if counts[section] > 2: return false
	for i in range(6):
		var elapsed = value.sections[i]
		if not _time(elapsed, -1.0, FALL_SECONDS): return false
		if elapsed < 0 and elapsed != -1: return false
		if (elapsed >= 0) != (counts.get(56+i, 0) == 2): return false
	return true

static func _time(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum

static func capture(deck: Node3D, chains: Node3D, warning: Node) -> Dictionary:
	var cuts: Array = []
	var ids: Array = deck.chain_rule.cut.keys()
	ids.sort()
	for id in ids: cuts.append({"id": id, "elapsed": clampf(chains.chains[id].elapsed, 0.0, CHAIN_SECONDS)})
	var sections: Array = []
	for id in range(56, 62): sections.append(deck.sections[id].elapsed)
	return {"cuts": cuts, "sections": sections, "warning_played": warning.played}

static func restore(value: Dictionary, deck: Node3D, chains: Node3D, warning: Node) -> void:
	assert(validate(value))
	deck.chain_rule.cut.clear()
	deck.chain_rule.counts.clear()
	for chain in chains.chains.values():
		chain.elapsed = -1.0
		chain.frame = -1
		chain.mesh.material_override.set_shader_parameter("indices", chains.intact_texture)
		for pair in chains.host.occluder_pairs + chains.host.light_pairs:
			if pair[0] == chain.mesh: pair[1].material_override.set_shader_parameter("indices", chains.intact_texture)
	for cut in value.cuts:
		deck.chain_rule.cut_chain(int(cut.id))
		chains.chains[int(cut.id)].elapsed = float(cut.elapsed)
	for id in range(56, 62):
		var section: Dictionary = deck.sections[id]
		section.elapsed = float(value.sections[id-56])
		section.body.collision_layer = 1 if section.elapsed < 0 else 0
		section.mesh.position = section.start
		section.mesh.visible = true
		for pair in deck.host.occluder_pairs + deck.host.light_pairs:
			if pair[0] == section.mesh:
				pair[1].global_transform = section.mesh.global_transform
				pair[1].visible = true
	deck._physics_process(0.0)
	chains._physics_process(0.0)
	warning.dismiss()
	warning.played = value.warning_played
