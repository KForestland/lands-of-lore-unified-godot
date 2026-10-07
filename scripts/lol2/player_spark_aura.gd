extends Node3D
## Effect24 lightning aura. Target/flight/timing/damage are explicit modern adapters.
const State = preload("res://scripts/lol2/player_spark_aura_state.gd")
const DAMAGE := [8,12,16,20]
const RANGE := 400.0
const SPEED := 320.0
var host: Node3D
var magic: Node
var visuals: Array[MeshInstance3D] = []
func setup(owner_host: Node3D, owner_magic: Node) -> void:
	host = owner_host
	magic = owner_magic
func state() -> Dictionary:
	return magic.magic_state().get("spark_aura",State.initial()).duplicate(true)
func commit(a: Dictionary) -> void:
	# Hits can replace the magic checkpoint with newly earned XP; merge into latest.
	var saved: Dictionary = magic.magic_state().duplicate(true)
	saved.spark_aura = a
	magic.commit(saved)
func protected() -> bool: return State.active(state())
func start() -> void:
	var a := state()
	if a.area != host.scene_file_path:
		a.bolts = []
		a.area = host.scene_file_path
	if not State.active(a):
		var items: Dictionary = host.item_effects.state()
		if not items.has("aloe"): items.aloe = host.item_effects.State.aloe_initial()
		if int(items.aloe.pending) == 0: items.aloe.base = magic.health()&0xff
		sweep(a)
		magic.set_health(1)
	State.extend(a)
	commit(a)
	present(a)
func recover() -> void:
	var items: Dictionary = host.item_effects.state()
	if not items.has("aloe"): items.aloe = host.item_effects.State.aloe_initial()
	items.aloe.pending = int(items.aloe.base)
	items.aloe.base = 1
func cancel() -> void:
	var a := state()
	if not State.active(a): return
	a.timer = 0
	a.fraction = 0.0
	a.pulse = 0.0
	recover()
	commit(a)
func targets() -> Dictionary:
	var result := {}
	if host.get("roach") != null and host.roach.model.enemy_health > 0:
		result.roach23 = {"body":host.roach.body,"point":host.roach.body.global_position+Vector3(0,6,0)}
	if host.get("roach_population_live")!=null: result.merge(host.roach_population_live.targets())
	if host.get("dino_population")!=null and is_instance_valid(host.dino_population): result.merge(host.dino_population.targets())
	if host.get("skeleton_population")!=null and is_instance_valid(host.skeleton_population): result.merge(host.skeleton_population.targets())
	if host.get("guard_population")!=null and is_instance_valid(host.guard_population): result.merge(host.guard_population.targets())
	if host.get("wild_roach_population")!=null and is_instance_valid(host.wild_roach_population): result.merge(host.wild_roach_population.targets())
	if host.get("lurking_roach_population")!=null and is_instance_valid(host.lurking_roach_population): result.merge(host.lurking_roach_population.targets())
	if host.get("bacatta")!=null and is_instance_valid(host.bacatta): result.merge(host.bacatta.targets())
	if host.get("kelsrick")!=null and is_instance_valid(host.kelsrick): result.merge(host.kelsrick.targets())
	if host.get("dawn")!=null and is_instance_valid(host.dawn): result.merge(host.dawn.targets())
	if host.get("bacatta65")!=null and is_instance_valid(host.bacatta65): result.merge(host.bacatta65.targets())
	if host.get("bacatta57")!=null and is_instance_valid(host.bacatta57): result.merge(host.bacatta57.targets())
	if host.get("exit_encounter")!=null and is_instance_valid(host.exit_encounter): result.merge(host.exit_encounter.targets())
	if host.get("villager_population")!=null and is_instance_valid(host.villager_population): result.merge(host.villager_population.targets())
	if host.has_node("Warriors"):
		var guards = host.get_node("Warriors")
		for i in 2:
			if guards.enemies[i] > 0:
				result["guardian%d" % guards.ACTORS[i]] = {"body":guards.bodies[i],"point":guards.bodies[i].global_position+Vector3(0,35,0),"index":i}
	if host.get("executioner_live") != null and host.executioner_live.active() and host.executioner_live.state.health > 0:
		result.executioner36 = {"body":host.executioner_live.body,"point":host.executioner_live.body.global_position}
	if host.get("rune_population") != null:
		result.merge(host.rune_population.targets())
	if host.get("return_population") != null:
		result.merge(host.return_population.targets())
	if host.get("ambush_population") != null:
		result.merge(host.ambush_population.targets())
	return result
func clear_to(origin: Vector3, target: Dictionary) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin,target.point,3,[host.player.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == target.body
func sweep(a: Dictionary) -> void:
	var origin: Vector3 = host.camera.global_position
	var live := targets()
	for id in live:
		var target: Dictionary = live[id]
		if host.player.global_position.distance_to(target.body.global_position) > RANGE or not clear_to(origin,target): continue
		if a.bolts.size() >= 128: break
		a.bolts.append({"target":id,"effect":State.draw_effect(a),"position":[origin.x,origin.y,origin.z],"life":5.0})
func hit(id: String, effect: int, target: Dictionary) -> void:
	var damage: int = DAMAGE[effect-20]
	if id == "roach23": host.roach.receive_magic(damage,effect)
	elif id == "executioner36": host.executioner_live.receive_strike(damage,false,effect)
	elif target.has("owner"): target.owner.receive_damage(str(target.actor),damage,false,effect)
	else: host.get_node("Warriors").damage_guardian(int(target.index),damage,effect)
func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0 or not magic.magic_state().has("spark_aura"): return
	var remaining := delta
	while remaining > 0.0000001:
		var step := minf(remaining,1.0/60.0)
		advance_step(step)
		remaining -= step
	if delta == 0: advance_step(0)
func advance_step(delta: float) -> void:
	var a := state()
	if a.area != host.scene_file_path:
		a.bolts = [] # Flights belong to the departed area; protection travels.
		a.area = host.scene_file_path
	var update := State.advance(a,delta)
	for pulse in int(update.pulses): sweep(a)
	if update.expired: recover()
	commit(a)
	var live := targets()
	var kept: Array = []
	for bolt in a.bolts:
		if not live.has(bolt.target): continue
		var target: Dictionary = live[bolt.target]
		var position := Vector3(bolt.position[0],bolt.position[1],bolt.position[2])
		var end: Vector3 = position.move_toward(target.point,SPEED*delta)
		var query := PhysicsRayQueryParameters3D.create(position,end,3,[host.player.get_rid()])
		var collision: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not collision.is_empty() and collision.collider != target.body: continue
		if (not collision.is_empty() and collision.collider == target.body) or end.distance_to(target.point) < 2.0:
			hit(str(bolt.target),int(bolt.effect),target)
			continue
		bolt.life = float(bolt.life)-delta
		if bolt.life <= 0: continue
		bolt.position = [end.x,end.y,end.z]
		kept.append(bolt)
	a.bolts = kept
	commit(a)
	present(a)
func present(a: Dictionary) -> void:
	while visuals.size() > a.bolts.size(): visuals.pop_back().queue_free()
	while visuals.size() < a.bolts.size():
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 2.0
		sphere.height = 4.0
		mesh.mesh = sphere
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.3,0.7,1.0)
		mesh.material_override = material
		add_child(mesh)
		visuals.append(mesh)
	for i in visuals.size():
		var p: Array = a.bolts[i].position
		visuals[i].global_position = Vector3(p[0],p[1],p[2])
