extends SceneTree
## Source items a story owner holds until its step: L9 dead bracers under Magic Shield 312 (Prima p.113, l9_dead_bracers.gd, astra f12e82f).
const GATED := {"act2:L9_DR:item55": "l9_dead_bracers shield312", "act2:L9_DR:item0": "l9_pyre Kit full urn reward", "act2:L8_SJ:item32": "l8_clubhouse opened", "act2:L8_SJ:item33": "l8_clubhouse opened", "act2:L8_SJ:item34": "l8_clubhouse opened", "act2:L14_HT:item67": "l14_niche raised"}
const Binder = preload("res://scripts/lol2/act2_progression.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const Source = preload("res://scripts/lol2/act2_items_catalog.gd")
var failures := 0
func area() -> String: return ""
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; print("FAIL items: ",message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	Engine.set_meta("lol2_enhanced",false)
	var scene = load(Binder.LEVEL_SCENES[int(area().get_slice("_",0).trim_prefix("L"))]).instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	scene.progression.set_physics_process(false)
	scene.progression.change_scene_enabled = false
	scene.act2_creatures.set_physics_process(false)
	var owner = scene.act2_items
	check(owner != null, "item owner attached")
	if owner == null: quit(1); return
	var data: Dictionary = Source.source().areas[area()]
	# Placements also hosted by area_world_items.gd (L8_SJ eggs / Manafoil) are left to that controller (one sprite, one E owner);
	# explicit astra additions: L9 Tower blank, L13 basin items (3), L14 machine statue; L16 Dark Bow = excluded row 24 shown by the
	# SE-tower oil burn (grok S02, STORY-071, 2026-11-07).
	var shared = scene.get("area_world_items")
	var deferred: Array = data.items.filter(func(row): return shared != null and is_instance_valid(shared) and shared.hosts_twin(str(row.id))).map(func(row): return str(row.id))
	check(owner.sprites.size() + deferred.size() == data.items.size()+int({"L9_DR":1,"L13_RC":3,"L14_HT":1,"L16_CA":1}.get(area(),0)) and data.items.size()+data.excluded.size() == int(data.source_count), "all original rows accounted (%d left to area_world_items), explicit Tower/basin/machine additions separate" % deferred.size())
	var first := ""
	var inaccessible: Array = []
	for row in data.items:
		var id := str(row.id)
		if id in deferred:
			check(not owner.sprites.has(id) and owner.target() != id and not owner.take(id), "twin left to area_world_items " + id)
			continue
		check(Catalog.known(id) and Catalog.label(id) == str(row.label) and Catalog.icon(id) == str(row.icon), "original catalog identity " + id)
		var expected_use: String = {117:"silverleaf",119:"amaranth_serum"}.get(int(row.definition), "")
		check(Catalog.slot(id).is_empty() and Catalog.use_kind(id) == expected_use, "placed item handler contract " + id)
		if expected_use.is_empty(): check(not Catalog.use_hint(id).is_empty(), "unhosted handler explains refusal " + id)
		var point: Vector3 = owner.aim_point(id)
		var found := false
		for offset in [Vector3(0,20,32),Vector3(32,20,0),Vector3(0,20,-32),Vector3(-32,20,0),Vector3(0,2,16),Vector3(16,2,0),Vector3(0,2,-16),Vector3(-16,2,0),Vector3(0,40,8)]:
			scene.player.global_position = point + offset - scene.camera.position
			scene.camera.look_at(point)
			await physics_frame
			if owner.available(id): found = true; break
		if GATED.has(id):
			# Story-gated source item: its owner keeps it out of reach until the step releases it (tested by that owner).
			check(not found, "story gate holds " + id + " (" + GATED[id] + ")")
			continue
		if not found:
			inaccessible.append(id)
			continue
		# Capacity refusal must preserve both the sprite and collection history.
		var before: Dictionary = scene.quest_state.get("act2_items",Source.initial()).duplicate(true)
		scene.carried_collected = Catalog.ids("jungle").slice(0,64)
		check(scene.carried_collected.size() == 64 and not owner.take(id) and owner.sprites[id].visible and scene.quest_state.get("act2_items",Source.initial()) == before, "capacity atomic " + id)
		scene.carried_collected.clear()
		check(owner.take(id) and id in scene.carried_collected and not owner.sprites[id].visible, "near/aim/LOS pickup " + id)
		check(not owner.take(id), "no duplicate pickup " + id)
		if first.is_empty(): first = id
	check(inaccessible.is_empty(), "no source item obstructed from bounded nearby probes: " + str(inaccessible))
	if not first.is_empty():
		# Keep two distinct copies if the source has them; placement ids remain distinct.
		scene.carried_collected = [first]
		for row in data.items:
			if str(row.id) != first and int(row.definition) == Source.definition(first) and str(row.id) in scene.quest_state.act2_items.collected:
				scene.carried_collected.append(str(row.id)); break
		Source.sync(scene)
		var expected: Array = scene.carried_collected.duplicate()
		# Save in a valid stable pose; the item probes are fixture placements, not route walks.
		scene.camera.rotation = Vector3.ZERO
		var path := "user://tests/"+area()+"_items.json"
		check(scene.quicksave(path).is_empty(), "save with placed items")
		scene.carried_collected.clear()
		check(scene.quickload(path).is_empty() and scene.carried_collected == expected, "reload duplicate-capable inventory")
		check(not owner.sprites[first].visible, "collection history survives reload")
		var packet: Dictionary = scene.area_handoff()
		check(preload("res://scripts/lol2/jungle_save.gd").validate_inventory(packet.inventory).is_empty(), "legacy inventory contract retained")
		check(Source.validate(packet.quests.act2_items).is_empty(), "world handoff packet validated")
		scene.carried_collected.clear()
		check(scene.apply_area_handoff(packet).is_empty() and scene.carried_collected == expected, "handoff restores placed items")
		var bad := packet.duplicate(true)
		bad.quests.act2_items.carried.append("act2:L8_SJ:item99999")
		check(not scene.apply_area_handoff(bad).is_empty() and scene.carried_collected == expected, "invalid handoff refused atomically")
	print(area()," placed=",data.items.size()," excluded=",data.excluded.size()," inaccessible=",inaccessible)
	if failures==0: print("PASS ",area()," source items, original icons/labels, pickup/capacity/refusal and save/handoff")
	quit(0 if failures==0 else 1)
