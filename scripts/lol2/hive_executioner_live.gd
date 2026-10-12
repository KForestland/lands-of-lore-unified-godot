extends Node3D
## Playable emulation adapter. Source actor36, 300 health and selector11/frame8;
## steering, awareness, damage and seconds are provisional, not native AI parity.
const SPAWN := Vector3(-642,-235,-6462)
const MAX_HEALTH := 300
const SPEED := 55.0
const REACH := 75.0
const ATTACK_DURATION := 18.0/15.0
# Mask2 is the provisional live branch already represented by attack selector11.
# Source action14/15 lookup maps that branch to death18 and corpse19.
const DEATH_DURATION := 9.0/15.0
var state := initial()
var body: CharacterBody3D
var host: Node3D
var nest: Node3D
static func initial() -> Dictionary:
	return {"version":1,"health":MAX_HEALTH,"position":[SPAWN.x,SPAWN.y,SPAWN.z],"mode":"idle","elapsed":0.0,"cooldown":0.0,"hit_sent":false}
static func validate(s: Variant) -> String:
	if not s is Dictionary or s.get("version") != 1: return "Invalid live Executioner state."
	if not preload("res://scripts/lol2/hive_clock_runtime.gd")._integer(s.get("reward_seed",324508639),0x7fffffff): return "Invalid Executioner reward RNG."
	var hp = s.get("health")
	if not (hp is int or hp is float) or not is_finite(float(hp)) or hp != floorf(hp) or hp < 0 or hp > MAX_HEALTH: return "Invalid live Executioner health."
	if s.get("mode") not in ["idle","walk","attack","dying","dead"] or not s.get("hit_sent") is bool: return "Invalid live Executioner mode."
	if (hp == 0) != (s.mode in ["dying","dead"]): return "Inconsistent live Executioner death."
	if not s.get("position") is Array or s.position.size()!=3: return "Invalid live Executioner position."
	for n in s.position:
		if not (n is int or n is float) or not is_finite(float(n)) or absf(n)>32768: return "Invalid live Executioner coordinate."
	for key in ["elapsed","cooldown"]:
		var n = s.get(key)
		if not (n is int or n is float) or not is_finite(float(n)) or n<0 or n>(ATTACK_DURATION if key=="elapsed" else 0.8): return "Invalid live Executioner clock."
	if s.mode == "attack" and (s.elapsed>=ATTACK_DURATION or s.hit_sent != (s.elapsed>=8.0/15.0)): return "Inconsistent live Executioner hit frame."
	if s.mode in ["dying","dead"] and s.cooldown != 0: return "Defeated Executioner has a cooldown."
	if s.mode == "dying" and (s.elapsed>=DEATH_DURATION or s.hit_sent): return "Invalid Executioner death progress."
	if s.mode not in ["attack","dying"] and (s.elapsed != 0 or s.hit_sent): return "Inactive live Executioner attack progressed."
	return ""
func _ready() -> void:
	host = get_parent()
	nest = host.get_node("Nest")
	body = CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	body.floor_snap_length = 8
	body.set_meta("hive_executioner_live",true)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 16
	capsule.height = 56
	shape.shape = capsule
	body.add_child(shape)
	add_child(body)
	restore(state)
func checkpoint() -> Dictionary:
	return state.duplicate(true)
func restore(saved: Dictionary) -> void:
	state = saved.duplicate(true)
	state.version=int(state.version)
	state.health=int(state.health)
	state.elapsed=float(state.elapsed)
	state.cooldown=float(state.cooldown)
	for i in range(3): state.position[i]=float(state.position[i])
	body.position = Vector3(state.position[0],state.position[1]+28,state.position[2])
	body.velocity = Vector3.ZERO
	present()
func active() -> bool:
	return nest.phase == 3 and host.executioner_runtime == null and host.get_node("Warriors").active() and not is_instance_valid(host.inventory) and not host.interface_hud.cursor_active and not host.runes.active()
func clear_path() -> bool:
	var q := PhysicsRayQueryParameters3D.create(body.global_position,host.camera.global_position,1,[body.get_rid(),host.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
func in_reach() -> bool:
	return body.global_position.distance_to(host.camera.global_position)<=REACH and clear_path()
func receive_strike(damage: int, melee: bool = true, spell_effect: int = -1) -> bool:
	if not active() or state.health == 0 or damage <= 0: return false
	var remaining := maxi(0,int(state.health)-damage)
	if melee:
		var reward := preload("res://scripts/lol2/hive_live_melee_reward.gd").apply(host.player_reward_checkpoint,int(state.get("reward_seed",324508639)),remaining)
		if reward.has("error"):
			push_error(reward.error)
			return false
		host.player_reward_checkpoint = reward.checkpoint
		state.reward_seed = reward.seed
	elif spell_effect in [20,21,22,23]:
		var reward := preload("res://scripts/lol2/hive_live_spell_reward.gd").apply(host.player_magic_checkpoint,int(state.get("reward_seed",324508639)),int(state.health)-remaining,spell_effect)
		if reward.has("error"):
			push_error(reward.error)
			return false
		host.player_magic_checkpoint = reward.checkpoint
		state.reward_seed = reward.seed
	state.health = remaining
	if state.health == 0:
		state.mode="dying";state.elapsed=0.0;state.hit_sent=false;state.cooldown=0.0
	present()
	return true
func _physics_process(delta: float) -> void:
	advance(delta)
func advance(delta: float) -> void:
	# Native checkpoint fixtures retain their own owner and presentation.
	if host.executioner_runtime != null:
		body.collision_layer=0
		return
	present()
	if not active() or not is_finite(delta) or delta<=0: return
	if state.mode=="dying":
		state.elapsed+=delta
		if state.elapsed>=DEATH_DURATION: state.mode="dead";state.elapsed=0.0
		present()
		return
	if state.health==0: return
	state.cooldown=maxf(0,float(state.cooldown)-delta)
	if state.mode == "attack":
		state.elapsed=minf(ATTACK_DURATION,float(state.elapsed)+delta)
		if not state.hit_sent and state.elapsed>=8.0/15.0:
			state.hit_sent=true
			if in_reach():
				var guards = host.get_node("Warriors")
				if not preload("res://scripts/lol2/player_form_rules.gd").protected(host): guards.health=maxi(0,guards.health-preload("res://scripts/lol2/player_defense.gd").incoming(host,15))
				if guards.health==0: host.set_physics_process(false)
		if state.elapsed>=ATTACK_DURATION:
			state.mode="idle";state.elapsed=0.0;state.hit_sent=false;state.cooldown=0.8
	elif in_reach():
		state.mode="idle"
		if state.cooldown==0: state.mode="attack"
	elif body.global_position.distance_to(host.camera.global_position)<420 and clear_path():
		var direction: Vector3 = host.player.global_position-body.global_position
		direction.y=0
		direction=direction.normalized()
		# Avoid walking across unsupported chasms; full pathfinding remains open.
		var next: Vector3=body.global_position+direction*maxf(20,SPEED*delta)
		var floor_query := PhysicsRayQueryParameters3D.create(next+Vector3(0,8,0),next-Vector3(0,44,0),1,[body.get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(floor_query).is_empty():
			body.velocity=direction*SPEED+Vector3(0,-20,0)
			body.move_and_slide()
			state.position=[body.position.x,body.position.y-28,body.position.z]
			state.mode="walk"
		else: state.mode="idle"
	else: state.mode="idle"
	present()
func present() -> void:
	if not is_instance_valid(body): return
	var visible_actor: bool = nest.phase==3
	body.collision_layer=2 if visible_actor and state.health>0 and host.executioner_runtime==null else 0
	if host.executioner_runtime!=null: return
	nest.actor.position=Vector3(state.position[0],state.position[1],state.position[2])
	nest.actor.visible=visible_actor and not body.get_meta("hive_retired",false)
	if not visible_actor: return
	var pose := 11 if state.mode=="attack" else 0
	var frame := mini(17,int(float(state.elapsed)*15))
	var view := {"pose":pose}
	if pose==11: view.attack={"selector":11,"frame":frame}
	elif state.mode in ["dying","dead"]:
		view.pose=18 if state.mode=="dying" else 19
		view.source_pose={"selector":view.pose,"frame":mini(8,int(float(state.elapsed)*15)) if state.mode=="dying" else 0}
	var error: String=nest.present_executioner(view)
	if not error.is_empty(): push_error(error)
