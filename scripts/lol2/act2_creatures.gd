extends "res://scripts/lol2/scripted_creature_population.gd"
## Original Act2 placements/sprites on the shared owner. Source fields are retained;
## size, stats, peaceful NPCs and native-bit-to-wake mapping are documented adapters.
var area_id := ""
var binding: Node
func advance(delta: float) -> void:
	var walker=host.get_node_or_null("L9StatueWalk") if area_id=="L9_DR" else null
	var held: bool=walker!=null and walker.enabled()
	var previous: Array=[]
	if held:
		previous=[state.actors["76"].woken,state.actors["76"].rise,bodies["76"].velocity]
		state.actors["76"].woken=false;state.actors["76"].rise=-1.0
	super.advance(delta)
	if area_id=="L14_HT" and host.has_node("L14HopperPlatform"):host.get_node("L14HopperPlatform").advance_creatures(delta)
	if area_id=="L13_RC":_advance_citadel_flight(delta)
	if held:
		state.actors["76"].woken=previous[0];state.actors["76"].rise=previous[1]
		bodies["76"].velocity=previous[2]
		walker.advance(delta)
static func attach(map: Node3D, area: String) -> Node3D:
	var source := "res://scripts/lol2/act2_populations/%s.json" % area
	var media := "res://assets/lol2/generated/act2_creatures/%s/" % area
	if not FileAccess.file_exists(source) or not FileAccess.file_exists(media + "sprites.json"):
		push_error("Missing Act2 creature assets: " + area)
		return null
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	var owner = load("res://scripts/lol2/act2_creatures.gd").new()
	owner.area_id = area
	owner.name = "Act2Creatures"
	var names: Dictionary = {}
	for key in data.definitions: names[key] = data.definitions[key].name
	owner.configure({"root": media, "source": source, "look": data.look, "names": names,
		"quest_key": "act2_creatures_" + area, "fighting_owner": "quest_state", "target_prefix": area + "actor"})
	map.add_child(owner)
	var error: String = owner.setup(map)
	if not error.is_empty(): push_error(area + " creatures: " + error)
	owner.binding = map.progression
	if owner.binding != null: owner.binding.native.object_state_changed.connect(owner.native_field)
	return owner

func native_field(ref: String, field: String, value: int) -> void:
	if not ref.begins_with("actor:"): return
	var id := ref.get_slice(":", 1)
	if not state.actors.has(id): return
	# PROVEN native bit writes. Opcode 9 arm 3 ORs 1 into byte +0x16 (flag 0x10000): the link.
	# present is the population boolean for that link. Mapping +0xB5 bit 0 onto the generic awake state stays a LIKELY adapter.
	if field == "bit_0x16_0x01" and value == 1:
		State.spawn(state, id)
		present()
		return
	if field == "bit_0xb5_0x01":
		if value == 0: State.wake(state, id, true)
		else: state.actors[id].woken = false
		sync_quests()
		present()

func sync_quests() -> void:
	super.sync_quests()

func restore_from_quests() -> String:
	return super.restore_from_quests()

## The admitted village guard is a peaceful interaction owner (DEVIATIONS0251).
func peaceful_actor(id: String) -> bool:
	if area_id=="L14_HT" and id=="90":return not host.quest_state.get("l14_belial",{}).get("spoken",false)
	return area_id=="L8_SJ" and ((id=="115" and host.has_node("L8Larkhon")) or id=="21" or (id=="113" and host.quest_state.get("l8_journey",{}).get("admitted",false)))

func receive_damage(id: String, amount: int, melee: bool=true, effect: int=20) -> bool:
	if area_id=="L14_HT" and id=="90" and host.has_node("L14Belial") and not host.get_node("L14Belial").permits_hit(melee,amount):return false
	var tribe=host.get_node_or_null("L8Tribe") if area_id=="L8_SJ" else null
	if id=="23" and tribe!=null and tribe.state().phase!="idle":return tribe.receive_strike(amount,melee)
	return super.receive_damage(id,amount,melee,effect)

func present()->void:
	super.present()
	var guardian=host.get_node_or_null("L8Larkhon") if area_id=="L8_SJ" else null
	if guardian!=null:guardian.apply_pose()

## Modern fallback for the source Ruloi on raised platforms: use the existing
## collision body and SPEED, never reposition the player or edit health.
func _advance_citadel_flight(_delta:float)->void:
	if not world_active() or not host.quest_state.get("l13_eggs",{}).get("vent_broken",false):return
	var changed:=false
	for n in range(21,40):
		var id:=str(n)
		if not bodies.has(id) or not state.actors[id].present or state.actors[id].health<=0 or Net.held(net_holds,id) or Prism.blinded(prism_blinds,id):continue
		var body:CharacterBody3D=bodies[id]
		var delta:Vector3=host.player.global_position-body.global_position
		if delta.y>=-80 or delta.y< -400 or Vector2(delta.x,delta.z).length()>640:continue
		State.wake(state,id)
		var before:=body.position
		body.velocity=(delta-Vector3.UP*32).normalized()*State.SPEED
		body.move_and_slide()
		if not body.position.is_equal_approx(before):
			state.actors[id].position=Live.saved_position(body.position-origin());moving[id]=true;changed=true
	if changed:sync_quests();present()
