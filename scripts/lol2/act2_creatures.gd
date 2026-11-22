extends "res://scripts/lol2/scripted_creature_population.gd"
## Original Act2 placements/sprites on the shared owner. Source fields are retained;
## size, stats, peaceful NPCs and native-bit-to-wake mapping are documented adapters.
var area_id := ""
var binding: Node
## Plasma bolts for the held stone squid. Null until the first shot.
var plasma_bolts: Node = null
## After the birth the mother dies on her own. The creatures of L20 stay absent, including across a save.
func _birth_area_quiet() -> bool:
	if area_id != "L20_BB": return false
	var raw: Variant = host.quest_state.get("l19_dawn_curse", {})
	if not raw is Dictionary or not bool(raw.get("creatures_cleared", false)): return false
	var changed: bool = false
	for id in state.actors:
		var actor: Dictionary = state.actors[id]
		if bool(actor.present):
			actor.present = false
			changed = true
	if changed: sync_quests()
	present()
	return true

func advance(delta: float) -> void:
	if _birth_area_quiet(): return
	var walker=host.get_node_or_null("L9StatueWalk") if area_id=="L9_DR" else null
	var held: bool=walker!=null and walker.enabled()
	var previous: Array=[]
	if held:
		previous=[state.actors["76"].woken,state.actors["76"].rise,bodies["76"].velocity]
		state.actors["76"].woken=false;state.actors["76"].rise=-1.0
	super.advance(delta)
	if plasma_bolts != null and is_instance_valid(plasma_bolts):
		plasma_bolts.call("advance", delta)
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

## Owner r17 18-19-21. Actor 58 stays on its placement and fires at sight.
## Actors 61 and 68 stay the opening melee: that walk meets 68, and 61 comes to the path.
func anchored(id: String) -> bool:
	return area_id == "L9_DR" and id == "58"

## Selector 3 frame 4 is frame-event kind 3 value 82. That word is unread.
## The shot is the existing plasma bolt, aimed at the player.
func on_anchor_impact(id: String) -> void:
	var bolts: Node = _ensure_plasma()
	var body: CharacterBody3D = bodies[id]
	bolts.set("exclude", _anchor_rids())
	var muzzle: Vector3 = body.global_position + Vector3.UP * 36.0
	bolts.call("cast_plasma", "actor" + id, muzzle, "player")

func _anchor_rids() -> Array:
	var rids: Array = []
	rids.append((bodies["58"] as CharacterBody3D).get_rid())
	return rids

func _ensure_plasma() -> Node:
	if plasma_bolts != null and is_instance_valid(plasma_bolts):
		return plasma_bolts
	var node: Node = preload("res://scripts/lol2/dawn_spell_bolts.gd").new()
	node.name = "StSquidPlasma"
	add_child(node)
	node.set("targets", Callable(self, "_plasma_targets"))
	node.set("deliver", Callable(self, "_plasma_hit"))
	plasma_bolts = node
	return node

func _plasma_targets() -> Dictionary:
	var body: Node3D = host.player
	return {"player": {"body": body, "point": body.global_position + Vector3.UP * 32.0, "type": 1, "valid": true}}

func _plasma_hit(request: Dictionary) -> void:
	if str(request.get("kind")) != "plasma" or str(request.get("to")) != "player":
		return
	if host.starting_magic.protected():
		return
	var loss: int = preload("res://scripts/lol2/player_defense.gd").incoming(host, preload("res://scripts/lol2/dawn_modern_combat.gd").PLASMA_DAMAGE, 4)
	host.starting_magic.set_health(maxi(0, host.starting_magic.health() - loss))

## The admitted village guard is a peaceful interaction owner (DEVIATIONS0251).
func peaceful_actor(id: String) -> bool:
	if area_id=="L14_HT" and id=="90":return not host.quest_state.get("l14_belial",{}).get("spoken",false)
	return area_id=="L8_SJ" and ((id=="115" and host.has_node("L8Larkhon")) or id=="21" or (id=="113" and host.quest_state.get("l8_journey",{}).get("admitted",false)))

var _l20_death_sent: Dictionary = {}

## INTERIM COMBAT SCALE (owner decision 2026-11-10, option A of fable_lane/BJ14_STOPS_AND_PLAN.md F9; DEVIATIONS 0558).
## Until the original item and damage numbers are decoded (master plan I-03 / R-01), Act 2 creatures take four times
## Luther's damage and deal a quarter of theirs: the same as a quarter of their health, without rewriting saved health.
## Remove this block when real combat lands. Story actors keep their own rules.
const INTERIM_SCALE := 4
const INTERIM_AREAS := ["L8_SJ", "L9_DR", "L10_DC", "L12_CM", "L13_RC", "L14_HT"]
const INTERIM_EXCLUDED := {"L8_SJ": ["23"], "L14_HT": ["90"]}
func interim_scaled(id: String) -> bool:
	return area_id in INTERIM_AREAS and not id in INTERIM_EXCLUDED.get(area_id, [])
func damage_to_player_scale(id: String) -> float:
	return 1.0 / INTERIM_SCALE if interim_scaled(id) else 1.0

## Actor 46 kind-6 caller 0x0B is group 12398. The port did not fire it when health reached 0.
func _l20_death_caller(id: String) -> void:
	if area_id != "L20_BB" or id != "46" or bool(_l20_death_sent.get(id, false)):
		return
	if not state.actors.has(id) or int(state.actors[id].health) != 0:
		return
	var binder: Node = host.get("progression") as Node
	if binder == null or not binder.has_method("fire"):
		return
	_l20_death_sent[id] = true
	binder.fire("actor:" + id, 6, {"caller_byte": 11})

func receive_damage(id: String, amount: int, melee: bool=true, effect: int=20) -> bool:
	if area_id=="L14_HT" and id=="90" and host.has_node("L14Belial") and not host.get_node("L14Belial").permits_hit(melee,amount):return false
	var tribe=host.get_node_or_null("L8Tribe") if area_id=="L8_SJ" else null
	if id=="23" and tribe!=null and tribe.state().phase!="idle":return tribe.receive_strike(amount,melee)
	var landed := super.receive_damage(id, amount * INTERIM_SCALE if interim_scaled(id) else amount, melee, effect)
	# L20 grate 52: actor 47 and actor 48 kind-6 caller 0x0B travel the grate. The port did not fire that caller.
	if landed and area_id == "L20_BB" and (id == "47" or id == "48") and int(state.actors[id].health) == 0:
		var binder: Node = host.get("progression") as Node
		if binder != null and binder.get("native") != null:
			binder.native.call("fire_event", "actor:" + id, 6, {"caller_byte": 11})
	if landed and id == "46":
		_l20_death_caller(id)
	return landed

func present()->void:
	super.present()
	var guardian=host.get_node_or_null("L8Larkhon") if area_id=="L8_SJ" else null
	if guardian!=null:guardian.apply_pose()

## Ruloi that stand on a ledge they cannot fly off (row 0667); time without progress per id.
const LEDGE_GLIDE:=["22"]
## 22 stands 140 above the lift top; the lift bottom is 1040 lower (L13Elevator motion height -1040).
const LIFT_DEPTH:=-1300.0
var ledge_stuck:Dictionary={}
## Modern fallback for the source Ruloi on raised platforms: use the existing
## collision body and SPEED, never reposition the player or edit health.
func _advance_citadel_flight(_delta:float)->void:
	if not world_active():return
	# Owner F10 01-12..01-22 on r19o4 (lead 2026-11-16): 22 engages wherever the player meets the lift (riding it, on the
	# deck at either end), also before the egg basin drains; the other Ruloi keep the basin gate (row 0667 note).
	var vent:bool=host.quest_state.get("l13_eggs",{}).get("vent_broken",false)
	var changed:=false
	for n in range(21,40):
		var id:=str(n)
		if not vent and id not in LEDGE_GLIDE:continue
		if not bodies.has(id) or not state.actors[id].present or state.actors[id].health<=0 or Net.held(net_holds,id) or Prism.blinded(prism_blinds,id):continue
		var body:CharacterBody3D=bodies[id]
		var delta:Vector3=host.player.global_position-body.global_position
		var gliding:=float(ledge_stuck.get(id,0.0))>=0.5
		if gliding and delta.y>=-8:ledge_stuck.erase(id);gliding=false
		var lowest:=LIFT_DEPTH if id in LEDGE_GLIDE else -400.0
		if (delta.y>=-80 and not gliding) or delta.y<lowest or Vector2(delta.x,delta.z).length()>640:continue
		State.wake(state,id)
		var before:=body.position
		var flight:Vector3=(delta-Vector3.UP*32).normalized()*State.SPEED
		body.velocity=flight
		body.move_and_slide()
		# Ledge glide (Ruloi 22 above the lift, owner save 04-56-17; DEVIATIONS row 0667): a Ruloi standing on a raised
		# ledge cannot fly off it with move_and_slide (its floor holds it), so after half a second without progress it
		# glides straight toward the player, through its ledge (only the ids in LEDGE_GLIDE), down to his height; the normal Ruloi
		# chase and attack take over from there.
		# Once gliding it keeps gliding until the height check above hands it back.
		if id in LEDGE_GLIDE and (body.position.distance_to(before)<0.5 or float(ledge_stuck.get(id,0.0))>=0.5):
			ledge_stuck[id]=float(ledge_stuck.get(id,0.0))+_delta
			if float(ledge_stuck[id])>=0.5:body.position=before+flight*_delta;body.velocity=flight
		else:ledge_stuck.erase(id)
		if not body.position.is_equal_approx(before):
			state.actors[id].position=Live.saved_position(body.position-origin());moving[id]=true;changed=true
	if changed:sync_quests();present()
