extends Node3D
## Seven source return-warrior placements; pursuit/attack clocks are modern adapters.
const Attack=preload("res://scripts/lol2/hive_warrior_attack.gd")
const Selection=preload("res://scripts/lol2/hive_warrior_selection.gd")
const Death=preload("res://scripts/lol2/hive_warrior_death.gd")
const Presenter=preload("res://scripts/lol2/hive_executioner_sprite.gd")
var death_presenters: Dictionary={}
var death_static: Dictionary={}
var death_visual: Dictionary={}
const State=preload("res://scripts/lol2/hive_return_population_state.gd")
const Forms=preload("res://scripts/lol2/player_form_rules.gd")
const Net=preload("res://scripts/lol2/net_exile_hold.gd")
## Net of Exile holds {actor id: seconds left}; transient (net_exile_hold.gd).
var net_holds: Dictionary={}
var rules=State
var target_prefix:="hivewarrior"
var visual_paths: Dictionary={}
var host: Node3D
var state:=State.initial()
var bodies: Dictionary={}
func _ready() -> void:
	host=get_parent()
	var material:=StandardMaterial3D.new()
	material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/hive_warriors/warrior.png"))
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for id in rules.SPAWNS:
		var body:=CharacterBody3D.new()
		body.collision_mask=1
		body.floor_snap_length=8
		body.set_meta("hive_return_actor",str(id))
		body.set_meta("hive_population_owner",self)
		var shape:=CollisionShape3D.new()
		var capsule:=CapsuleShape3D.new()
		capsule.radius=14;capsule.height=70
		shape.shape=capsule
		body.add_child(shape)
		var sprite:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		quad.size=Vector2(100,94);quad.center_offset.y=12
		sprite.mesh=quad;sprite.material_override=material
		if visual_paths.has(id):
			var own_material:=material.duplicate()
			own_material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(visual_paths[id]))
			sprite.material_override=own_material
		body.add_child(sprite)
		add_child(body)
		bodies[str(id)]=body
		if not visual_paths.has(id):
			var presenter=Presenter.new()
			var bind_error: String=presenter.bind(sprite,"res://assets/lol2/generated/hive_warrior_sprites/",{11:{"frames":18,"height":200},12:{"frames":16,"height":200},13:{"frames":18,"height":200},14:{"frames":16,"height":200},20:{"frames":13,"height":200},21:{"frames":1,"height":200}})
			if not bind_error.is_empty(): push_error(bind_error);return
			death_presenters[str(id)]=presenter
			death_static[str(id)]={"sprite":sprite,"texture":sprite.material_override.albedo_texture,"size":sprite.mesh.size,"center":sprite.mesh.center_offset}
	restore(state)
func checkpoint() -> Dictionary: return state.duplicate(true)
func restore(saved: Dictionary) -> void:
	state=rules.canonical(saved)
	net_holds.clear()
	for id in bodies:
		var a: Dictionary=state.actors[id]
		if death_presenters.has(id) and a.active and a.health==0 and not a.has("death_animation"): a.death_animation=Death.initial(true)
		var p: Array=a.position
		bodies[id].position=Vector3(p[0],p[1]+35,p[2])
		bodies[id].velocity=Vector3.ZERO
	present()
func arrive(quests: Dictionary) -> void:
	rules.arrive(state,quests)
	present()
func present() -> void:
	for id in bodies:
		var alive: bool=state.actors[id].active and state.actors[id].health>0
		var death: bool=death_presenters.has(id) and state.actors[id].has("death_animation")
		bodies[id].visible=(alive or death) and not bodies[id].get_meta("hive_retired",false)
		var token:="living"
		if death:
			var value: Dictionary=state.actors[id].death_animation
			var pose:=21 if value.corpse else 20
			token=str(pose)+":"+str(int(value.frame))
			if death_visual.get(id,"")!=token:
				var visual_error: String=death_presenters[id].present({"pose":pose,"source_pose":{"selector":pose,"frame":value.frame}})
				if not visual_error.is_empty(): push_error(visual_error);return
		elif state.actors[id].has("attack_animation"):
			var value: Dictionary=state.actors[id].attack_animation
			token=str(int(value.selector))+":"+str(int(value.frame))
			if death_visual.get(id,"")!=token:
				var visual_error: String=death_presenters[id].present({"pose":value.selector,"attack":value,"source_pose":value})
				if not visual_error.is_empty(): push_error(visual_error);return
		elif death_static.has(id) and death_visual.get(id,"living")!="living":
			var original: Dictionary=death_static[id]
			original.sprite.material_override.albedo_texture=original.texture
			original.sprite.material_override.uv1_scale=Vector3.ONE
			original.sprite.material_override.uv1_offset=Vector3.ZERO
			original.sprite.mesh.size=original.size
			original.sprite.mesh.center_offset=original.center
		death_visual[id]=token
		bodies[id].collision_layer=2 if alive else 0
func active() -> bool:
	return is_instance_valid(host.starting_magic) and host.starting_magic.world_active()
func targets() -> Dictionary:
	var result: Dictionary={}
	for id in bodies:
		if state.actors[id].active and state.actors[id].health>0:
			result[target_prefix+id]={"body":bodies[id],"point":bodies[id].global_position,"actor":id,"owner":self}
	return result
func receive_damage(id: String, damage: int, melee: bool=true, effect: int=20) -> bool:
	if not active() or not state.actors.has(id) or damage<=0: return false
	var a: Dictionary=state.actors[id]
	if not a.active or a.health<=0: return false
	var remaining:=maxi(0,int(a.health)-damage)
	# All seven HIVEW definitions carry the same source reward scale8 as EXEC.
	var reward: Dictionary
	if melee:
		reward=preload("res://scripts/lol2/hive_live_melee_reward.gd").apply(host.player_reward_checkpoint,int(a.seed),remaining)
		if reward.has("error"): push_error(reward.error);return false
		host.player_reward_checkpoint=reward.checkpoint
	else:
		reward=preload("res://scripts/lol2/hive_live_spell_reward.gd").apply(host.starting_magic.magic_state(),int(a.seed),int(a.health)-remaining,effect)
		if reward.has("error"): push_error(reward.error);return false
		host.starting_magic.commit(reward.checkpoint)
	a.seed=reward.seed
	if death_presenters.has(id):
		# Ordinary health-update kind0; masks2/4 share the attack table.
		a.warrior_mask=Selection.mask_after_health(a.get("warrior_mask",1 if a.health>50 else 2),a.health,remaining,0).mask
	a.health=remaining
	if remaining==0:
		net_holds.erase(id)
		a.windup=0.0;a.cooldown=0.0
		a.erase("attack_animation")
		if death_presenters.has(id): a.death_animation=Death.initial()
	present()
	return true
func _physics_process(delta: float) -> void: advance(delta)
func advance(delta: float) -> void:
	if not active() or not is_finite(delta) or delta<=0: return
	Net.tick(net_holds,delta)
	for id in bodies:
		var a: Dictionary=state.actors[id]
		if not a.active: continue
		if a.health<=0:
			if a.has("death_animation"): Death.advance(a.death_animation,delta)
			continue
		var body: CharacterBody3D=bodies[id]
		a.cooldown=maxf(0.0,float(a.cooldown)-delta)
		if Net.held(net_holds,id):
			# Netted: stands still, any started attack/windup is cancelled.
			body.velocity=Vector3.ZERO;a.windup=0.0;a.erase("attack_animation")
			continue
		var distance:=body.global_position.distance_to(host.camera.global_position)
		var ray:=PhysicsRayQueryParameters3D.create(body.global_position,host.camera.global_position,1,[body.get_rid(),host.player.get_rid()])
		var visible_target:=get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		if death_presenters.has(id):
			var admitted: bool=distance<=75 and visible_target
			if admitted and a.cooldown<=0 and not a.has("attack_animation"):
				a.seed=(1103515245*int(a.seed)+12345)&0x7fffffff
				var selected: Dictionary=Selection.select(5,a.get("warrior_mask",1 if a.health>50 else 2),0,int(a.seed)%101)
				a.attack_animation=Attack.initial(selected.selector)
			if a.has("attack_animation"):
				body.velocity=Vector3.ZERO;a.windup=0.0
				var defense:=preload("res://scripts/lol2/player_defense.gd").scalar(host)
				var result: Dictionary=Attack.advance(a.attack_animation,delta,admitted and not Forms.protected(host),15 if defense>0 else 6)
				if result.has("error"): push_error(result.error);return
				for event in result.events:
					if event.type=="damage": host.get_node("Warriors").health=maxi(0,host.get_node("Warriors").health-(preload("res://scripts/lol2/player_defense.gd").damage(int(event.amount),defense,int(event.get("flags",4))) if defense>0 else int(event.amount)))
				if result.terminal:
					a.erase("attack_animation");a.cooldown=0.8
				if host.get_node("Warriors").health==0: present();host.set_physics_process(false);return
				continue
			if admitted: body.velocity=Vector3.ZERO;continue
		if distance<=75 and visible_target:
			body.velocity=Vector3.ZERO
			if a.cooldown>0: continue
			a.windup=float(a.windup)+delta
			if a.windup>=1.2:
				a.windup=0.0;a.cooldown=0.8
				if not Forms.protected(host): host.get_node("Warriors").health=maxi(0,host.get_node("Warriors").health-preload("res://scripts/lol2/player_defense.gd").incoming(host,15))
				if host.get_node("Warriors").health==0: host.set_physics_process(false);return
		else:
			a.windup=0.0
			if distance>420 or not visible_target: body.velocity=Vector3.ZERO;continue
			var direction: Vector3=host.player.global_position-body.global_position
			direction.y=0;direction=direction.normalized()
			var next: Vector3=body.global_position+direction*maxf(20,55*delta)
			var floor_ray:=PhysicsRayQueryParameters3D.create(next+Vector3(0,8,0),next-Vector3(0,52,0),1,[body.get_rid()])
			if get_world_3d().direct_space_state.intersect_ray(floor_ray).is_empty(): continue
			body.velocity=direction*55+Vector3(0,-20,0)
			body.move_and_slide()
			a.position=preload("res://scripts/lol2/creature_live_rules.gd").saved_position(body.position-Vector3(0,35,0))

	present()

## Net of Exile on a landed hit (net_exile_hold.gd).
func net_hit(id: String, item: String) -> bool:
	if not state.actors.has(id) or not Net.apply(net_holds,id,item,state.actors[id].active and int(state.actors[id].health)>0): return false
	var a: Dictionary=state.actors[id]
	a.windup=0.0;a.erase("attack_animation")
	bodies[id].velocity=Vector3.ZERO
	Net.notify(host,Net.feedback("Hive warrior"))
	present()
	return true

func target_label(id: String) -> String:
	return "Hive Warrior %d/400" % int(state.actors[id].health)+(" · netted" if Net.held(net_holds,id) else "")
