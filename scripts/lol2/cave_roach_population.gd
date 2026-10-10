extends Node3D
## Source positions/health and original indexed presentation, plus the live
## perception/pursuit/bite adapter in cave_roach_population_state.gd.
const State=preload("res://scripts/lol2/cave_roach_population_state.gd")
const ActorAnimation=preload("res://scripts/lol2/cave_actor_animation.gd")
const Forms=preload("res://scripts/lol2/player_form_rules.gd")
var src: Dictionary
var clocks: Dictionary={}
var audio: Node3D
var state: Dictionary:
	get: return host.roach_population
func world_active() -> bool:
	return not get_tree().paused and host.starting_magic!=null and host.starting_magic.world_active()
var host: Node3D
var bodies: Dictionary={}
var meshes: Dictionary={}
var animations: Dictionary={}
var headings: Dictionary={}
var reward_scale:=1
var moving: Dictionary={}

func setup(walkthrough: Node3D) -> void:
	host=walkthrough
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(State.SOURCE))
	src={"actors":State.audio_actors()}
	reward_scale=int(source.reward_scale)
	var library:=ActorAnimation.new()
	assert(library.load_assets().is_empty())
	assert(library.load_extra_roach_actions().is_empty())
	for row in source.actors:
		var id:=str(int(row.actor))
		var animation:=ActorAnimation.new()
		# Share immutable textures, never an actor's animation clock/view selection.
		animation.view_textures=library.view_textures
		animation.action_textures=library.action_textures
		animation.canvas_size=library.canvas_size
		animation.centre_offset=library.centre_offset
		animation.world_units_per_pixel=library.world_units_per_pixel
		animation.set_view(0);animation.frame_count=animation.textures.size()
		animations[id]=animation
		clocks[id]=0.0
		var angle:=float(row.heading)*TAU/65536.0
		headings[id]=Vector2(sin(angle),cos(angle))
		var body:=CharacterBody3D.new()
		body.name="SourceRoach"+id
		body.collision_layer=2;body.collision_mask=1
		body.safe_margin=0.05
		body.set_meta("cave_population_actor",id)
		body.set_meta("cave_population_owner",self)
		var shape:=CollisionShape3D.new()
		var capsule:=CapsuleShape3D.new()
		capsule.radius=6;capsule.height=12
		shape.shape=capsule;shape.position.y=6
		body.add_child(shape)
		var mesh:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		quad.size=animation.canvas_size*animation.world_units_per_pixel
		quad.center_offset=animation.centre_offset
		mesh.mesh=quad;mesh.layers=2
		var material:=ShaderMaterial.new()
		material.shader=load("res://scripts/lol2/indexed_surface_review.gdshader")
		material.set_shader_parameter("sprite",true)
		mesh.material_override=material
		body.add_child(mesh);add_child(body)
		bodies[id]=body;meshes[id]=mesh
		host._copy_occluders(mesh)
	host.player.collision_mask|=2
	restore()
	audio=preload("res://scripts/lol2/cave_roach_audio.gd").new();add_child(audio)
	assert(audio.setup(self,State.audio_contract(),"res://assets/lol2/generated/cave_roach_audio/audio.json").is_empty())

func restore() -> void:
	State.initialize_visuals(host.roach_population)
	State.initialize_live(host.roach_population)
	for id in bodies:
		var p: Array=host.roach_population.actors[id].position
		bodies[id].position=Vector3(p[0],p[1],p[2])+host.native_translation
		bodies[id].velocity=Vector3.ZERO
		headings[id]=State.heading_vector(int(host.roach_population.live[id].heading))
		moving[id]=false
		animations[id].reset();clocks[id]=0.0
	if is_instance_valid(audio): audio.sync(0.0,true)
	present()

func present(delta: float=0.0) -> void:
	var updates: Dictionary={}
	State.initialize_live(host.roach_population)
	for id in bodies:
		var actor: Dictionary=host.roach_population.actors[id]
		var visual: Dictionary=host.roach_population.visuals[id]
		var live: Dictionary=host.roach_population.live[id]
		var animation=animations[id]
		var mesh: MeshInstance3D=meshes[id]
		var relative: Vector3=host.camera.global_position-bodies[id].global_position
		animation.select_direction(Vector2(relative.x,-relative.z),headings[id])
		if visual.action in [9,14]:
			animation.play_action(int(visual.action));animation.set_action_elapsed(float(visual.elapsed))
		elif live.mode==State.ATTACK:
			# Selector6/resource794; the same clip the entrance encounter uses.
			animation.play_action(5);animation.set_action_elapsed(float(live.elapsed))
		elif live.mode==State.PURSUE:
			animation.clear_action();animation.elapsed=fposmod(float(clocks[id]),animation.frame_count/State.FPS)
			animation.advance(0.0,true)
		else:
			# Both source action0 selectors use the single front view, resource769.
			animation.clear_action();animation.set_view(0);animation.advance(0.0,false)
		bodies[id].collision_layer=2 if actor.health>0 else 0
		mesh.visible=actor.health>0 or float(visual.elapsed)<2.5
		var texture: Texture2D=animation.textures[animation.frame_index]
		mesh.material_override.set_shader_parameter("indices",texture)
		updates[mesh]=texture
	# One pass over the host render copies, rather than one pass per actor.
	for pair in host.occluder_pairs+host.light_pairs:
		if updates.has(pair[0]):
			pair[1].global_transform=pair[0].global_transform
			pair[1].visible=pair[0].visible
			pair[1].material_override.set_shader_parameter("indices",updates[pair[0]])

func advance(delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	if not world_active():
		if is_instance_valid(audio): audio.pause()
		for id in bodies: bodies[id].velocity=Vector3.ZERO
		return
	State.advance_visuals(host.roach_population,delta)
	if host.roach!=null: _behave(delta)
	for id in clocks:
		if moving.get(id,false): clocks[id]+=delta
	present(delta)
	if is_instance_valid(audio): audio.sync(delta)

## Player health has one owner: the cave encounter model shared with actor23.
func _behave(delta: float) -> void:
	var target: Vector3=host.player.global_position
	var protected: bool=Forms.protected(host)
	var space:=get_world_3d().direct_space_state
	for id in bodies:
		var body: CharacterBody3D=bodies[id]
		moving[id]=false
		if host.roach_population.actors[id].health<=0 or host.roach_population.visuals[id].action==9 or State.dormant(host.roach_population,id):
			body.velocity=Vector3.ZERO;continue
		var separation: Vector3=target-body.global_position
		var distance:=Vector2(separation.x,separation.z).length()
		var sight:=false
		if distance<=State.ALERT_RANGE and absf(separation.y)<72:
			var ray:=PhysicsRayQueryParameters3D.create(body.global_position+Vector3.UP*12,target+Vector3.UP*8,1,[body.get_rid(),host.player.get_rid()])
			ray.hit_from_inside=true
			sight=space.intersect_ray(ray).is_empty()
		var health: int=host.roach.model.player_health
		var damage:=State.advance_live(host.roach_population,id,delta,distance,sight,protected,health,preload("res://scripts/lol2/player_defense.gd").scalar(host))
		if damage>0:
			host.roach.model.player_health=maxi(0,health-damage)
			host._save_feedback("You fell. R returns to the checkpoint; F9 loads your save." if host.roach.model.player_health==0 else "You were hit.")
		var live: Dictionary=host.roach_population.live[id]
		if live.mode!=State.PURSUE:
			body.velocity=Vector3.ZERO
			if live.mode==State.ATTACK and distance>0.01: _face(id,Vector2(separation.x,-separation.z))
			continue
		var direction:=Vector3(separation.x,0,separation.z).normalized()
		var ahead: Vector3=body.global_position+direction*8
		var floor_ray:=PhysicsRayQueryParameters3D.create(ahead+Vector3.UP*8,ahead-Vector3.UP*52,1,[body.get_rid(),host.player.get_rid()])
		if space.intersect_ray(floor_ray).is_empty():
			# Never walk off a ledge or into the river; wait at the edge.
			body.velocity=Vector3.ZERO;continue
		var previous: Vector3=body.global_position
		body.velocity=Vector3(direction.x*State.SPEED,0 if body.is_on_floor() else body.velocity.y-128*delta,direction.z*State.SPEED)
		body.move_and_slide()
		var travel: Vector3=body.global_position-previous
		if Vector2(travel.x,travel.z).length()>0.001:
			moving[id]=true
			_face(id,Vector2(travel.x,-travel.z))
		host.roach_population.actors[id].position=State.Live.saved_position(body.position-host.native_translation)

func _face(id: String, facing: Vector2) -> void:
	var units:=State.heading_units(facing)
	host.roach_population.live[id].heading=units
	headings[id]=State.heading_vector(units)

## Checkpoint recovery mirrors the entrance encounter: unfinished bites are dropped.
func recover() -> void:
	State.initialize_live(host.roach_population)
	for id in bodies:
		host.roach_population.live[id].merge({"mode":State.IDLE,"elapsed":0.0,"hit":false},true)
		bodies[id].velocity=Vector3.ZERO;moving[id]=false
	present()

func targets() -> Dictionary:
	var result: Dictionary={}
	for id in bodies:
		if host.roach_population.actors[id].health>0:
			result["caveroach"+id]={"body":bodies[id],"point":bodies[id].global_position+Vector3(0,6,0),"actor":id,"owner":self}
	return result

func receive_damage(id: String, amount: int, melee: bool=true, effect: int=20) -> bool:
	if amount<=0 or not host.roach_population.actors.has(id): return false
	var actor: Dictionary=host.roach_population.actors[id]
	var loss:=mini(amount,int(actor.health))
	if loss<=0: return false
	if melee:
		var reward:=preload("res://scripts/lol2/cave_melee_reward.gd").apply(host.quest_state,int(actor.health),amount,reward_scale)
		if reward.has("error"): return false
		host.quest_state=reward.quests
	else:
		if host.starting_magic==null or not host.starting_magic.award_hit(loss,effect,reward_scale): return false
	if State.damage(host.roach_population,id,amount)!=loss: return false
	present()
	if is_instance_valid(audio): audio.sync(0.0)
	return true

func strike() -> bool:
	if host.starting_magic==null or not host.starting_magic.world_active() or host.roach==null: return false
	if host.player_form==0 and host.equipped_item=="": return false
	if host.roach.model.strike_remaining>0: return false
	var selected:=""
	var closest:=INF
	var origin: Vector3=host.camera.global_position
	for id in bodies:
		if host.roach_population.actors[id].health<=0: continue
		var point: Vector3=bodies[id].global_position+Vector3(0,6,0)
		var delta: Vector3=point-origin
		var distance:=delta.length()
		if distance<=0.01 or distance>96 or distance>=closest or (-host.camera.global_basis.z).dot(delta/distance)<0.9: continue
		var query:=PhysicsRayQueryParameters3D.create(origin,point,3,[host.player.get_rid()])
		query.hit_from_inside=true
		var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider!=bodies[id]: continue
		selected=id;closest=distance
	if selected.is_empty(): return false
	host.roach.model.strike_remaining=host.roach.Model.STRIKE_COOLDOWN
	return receive_damage(selected,Forms.melee_damage(host.player_form,host.equipped_item!=""))
