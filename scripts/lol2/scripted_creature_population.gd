extends Node3D
## Live source-scripted creature population (Museum skeletons/Rat, cave guards).
## Configured with a sprite manifest, population source and per-definition look.
## Source spawn/wake/rise/attack/death structure; perception, steering, scale and
## clocks are documented adapters.
const State=preload("res://scripts/lol2/scripted_creature_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const Library=preload("res://scripts/lol2/creature_sprite_library.gd")
const Forms=preload("res://scripts/lol2/player_form_rules.gd")
const Net=preload("res://scripts/lol2/net_exile_hold.gd")
const STRIKE_COOLDOWN:=0.45
const STRIKE_REACH:=110.0
var config: Dictionary={}
const NAV_RANGE:=1200.0
var navigation: RefCounted
var routes: Dictionary={}
var host: Node3D
var src: Dictionary
var state: Dictionary
var library:=Library.new()
var bodies: Dictionary={}
var materials: Dictionary={}
var meshes: Dictionary={}
var clocks: Dictionary={}
var moving: Dictionary={}
var strike_remaining:=0.0
## Net of Exile holds {actor id: seconds left}; transient (net_exile_hold.gd).
var net_holds: Dictionary={}
var label: Label

## config: root (sprite dir), source (json path), look {definition: {canvas, scale,
## floor_row, radius, height}}, names {definition: label}, counter_note.
func configure(settings: Dictionary) -> void:
	config=settings

func setup(walkthrough: Node3D, saved: Variant=null) -> String:
	host=walkthrough
	src=State.source(config.source)
	var error:=library.load_manifest(config.root)
	if config.has("nav"):
		navigation=preload("res://scripts/lol2/creature_navigation.gd").new()
		var nav_error: String=navigation.load_graph(str(config.nav))
		if not nav_error.is_empty(): navigation=null
	if not error.is_empty(): return error
	for row in src.actors:
		var id:=str(int(row.actor));var d:=str(int(row.definition))
		var body:=CharacterBody3D.new()
		body.name="MuseumCreature"+id
		body.collision_layer=2;body.collision_mask=1;body.safe_margin=0.05
		body.set_meta("population_actor",id);body.set_meta("population_owner",self)
		var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
		var look: Dictionary=config.look[d]
		capsule.radius=float(look.radius);capsule.height=float(look.height)
		shape.shape=capsule;shape.position.y=capsule.height/2.0
		body.add_child(shape)
		var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new()
		quad.size=Vector2(look.canvas[0],look.canvas[1])*float(look.scale)
		quad.center_offset=Vector3(0,(float(look.floor_row)-float(look.canvas[1])/2.0)*float(look.scale),0)
		mesh.mesh=quad
		var indexed: bool=str(config.get("render",""))=="cave_indexed"
		materials[id]=library.bind(mesh,indexed)
		body.add_child(mesh);add_child(body)
		if indexed:
			mesh.layers=2
			host._copy_occluders(mesh)
		meshes[id]=mesh
		bodies[id]=body;clocks[id]=0.0;moving[id]=false
	host.player.collision_mask|=2
	label=Label.new();label.position=Vector2(16,48)
	var layer:=CanvasLayer.new();layer.add_child(label);add_child(layer)
	if config.has("quest_key") and saved==null: return restore_from_quests()
	return restore(saved if saved!=null else State.initial(src))

## Source coordinates plus the host's world translation (cave native_translation).
func origin() -> Vector3:
	var value=host.get("native_translation")
	return value if value is Vector3 else Vector3.ZERO

## Checkpoint recovery drops unfinished attacks, like the cave encounter.
func recover() -> void:
	for id in bodies:
		state.live[id].merge({"mode":Live.IDLE,"elapsed":0.0,"hit":false,"hits":0},true)
		state.live[id].erase("cooldown")
		bodies[id].velocity=Vector3.ZERO
	present()

## quest_key mode: the packet lives in host.quest_state[quest_key] (travels with
## quests). It is inserted only once something changes, so legacy quests stay equal.
func sync_quests() -> void:
	if config.has("quest_key") and host.get("quest_state") is Dictionary: host.quest_state[str(config.quest_key)]=state

func restore_from_quests() -> String:
	var key:=str(config.get("quest_key",""))
	var had: bool=host.quest_state.has(key)
	var error:=restore(host.quest_state.get(key,State.initial(src)))
	if error.is_empty() and had: sync_quests()
	return error

func checkpoint() -> Dictionary:
	return state.duplicate(true)

func restore(saved: Variant) -> String:
	var error:=State.validate(saved,src)
	if not error.is_empty(): return error
	state=State.canonical(saved,src)
	net_holds.clear()
	for id in bodies:
		var p: Array=state.actors[id].position
		bodies[id].position=Vector3(p[0],p[1],p[2])+origin()
		bodies[id].velocity=Vector3.ZERO
		moving[id]=false;clocks[id]=0.0
	present()
	return ""

func world_active() -> bool:
	return host.starting_magic!=null and host.starting_magic.world_active()

func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	strike_remaining=maxf(0.0,strike_remaining-delta)
	if not world_active():
		for id in bodies: bodies[id].velocity=Vector3.ZERO
		return
	Net.tick(net_holds,delta)
	var target: Vector3=host.player.global_position
	var local: Vector3=target-origin()
	if host.player.is_on_floor(): State.contact(state,src,local,local.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,int(host.player_form))
	State.advance_clocks(state,src,delta)
	var protected: bool=Forms.protected(host)
	var space:=get_world_3d().direct_space_state
	for id in bodies:
		var body: CharacterBody3D=bodies[id]
		moving[id]=false
		if not State.ready_to_fight(state,src,id):
			body.velocity=Vector3.ZERO;continue
		var live: Dictionary=state.live[id]
		if Net.held(net_holds,id):
			# Netted: stands still, any started attack is cancelled.
			body.velocity=Vector3.ZERO
			live.merge({"mode":Live.IDLE,"elapsed":0.0,"hit":false,"hits":0},true)
			continue
		var separation: Vector3=target-body.global_position
		var distance:=Vector2(separation.x,separation.z).length()
		var sight:=false
		if distance<=State.ALERT_RANGE and absf(separation.y)<80:
			var ray:=PhysicsRayQueryParameters3D.create(body.global_position+Vector3.UP*36,target+Vector3.UP*8,1,[body.get_rid(),host.player.get_rid()])
			ray.hit_from_inside=true
			sight=space.intersect_ray(ray).is_empty()
		var health: int=host.starting_magic.health()
		var previous: int=live.mode
		var damage:=State.advance_live(state,src,id,delta,distance,sight,protected,health,preload("res://scripts/lol2/player_defense.gd").scalar(host))
		if damage>0:
			host.starting_magic.set_health(maxi(0,health-damage))
			if host.has_method("save_feedback"): host.save_feedback("You fell. R: recover here · F9: load save" if host.starting_magic.health()==0 else name_of(id)+" struck you.")
		var steer: Vector3=separation
		# Out of sight but within range: follow the region-portal graph (adapter).
		if live.mode==Live.IDLE and not sight and navigation!=null and health>0 and distance<=NAV_RANGE and not live.has("cooldown"):
			var waypoint=_waypoint(id,body.global_position-origin(),target-origin(),delta)
			if waypoint!=null:
				live.mode=Live.PURSUE
				steer=Vector3(waypoint.x,0,waypoint.y)+origin()-body.global_position
		if live.mode!=previous: clocks[id]=0.0
		if live.mode!=Live.PURSUE:
			body.velocity=Vector3.ZERO
			if live.mode==Live.ATTACK and distance>0.01: live.heading=Live.heading_units(Vector2(separation.x,-separation.z))
			continue
		var direction:=Vector3(steer.x,0,steer.z).normalized()
		var ahead: Vector3=body.global_position+direction*14
		var floor_ray:=PhysicsRayQueryParameters3D.create(ahead+Vector3.UP*12,ahead-Vector3.UP*60,1,[body.get_rid(),host.player.get_rid()])
		if space.intersect_ray(floor_ray).is_empty():
			body.velocity=Vector3.ZERO;continue
		var before: Vector3=body.global_position
		body.velocity=Vector3(direction.x*State.SPEED,0 if body.is_on_floor() else body.velocity.y-128*delta,direction.z*State.SPEED)
		body.move_and_slide()
		var travel: Vector3=body.global_position-before
		if Vector2(travel.x,travel.z).length()>0.001:
			moving[id]=true;clocks[id]+=delta
			live.heading=Live.heading_units(Vector2(travel.x,-travel.z))
		state.actors[id].position=Live.saved_position(body.position-origin())
	if config.has("quest_key"):
		for id in bodies:
			var a: Dictionary=state.actors[id]
			if (a.health>0 and a.woken) or (a.health==0 and float(a.death)<State.clip_seconds(int(src.definitions[str(int(State.actor_row(src,id).definition))].clips.death.frames))):
				sync_quests();break
	present()

## Cached next portal per actor, refreshed every0.5s or when reached.
func _waypoint(id: String, from: Vector3, to: Vector3, delta: float) -> Variant:
	var cached: Dictionary=routes.get(id,{"age":99.0,"point":null})
	cached.age=float(cached.age)+delta
	if cached.age>=0.5 or (cached.point!=null and Vector2(from.x,from.z).distance_to(cached.point)<10):
		cached.point=navigation.next_point(from,to)
		cached.age=0.0
	routes[id]=cached
	return cached.point

func _view(id: String, slots: int=8) -> int:
	var relative: Vector3=host.camera.global_position-bodies[id].global_position
	var heading: Vector2=Live.heading_vector(int(state.live[id].heading))
	var to_camera:=Vector2(relative.x,-relative.z)
	if to_camera.length_squared()<0.000001: return 0
	var animation:=preload("res://scripts/lol2/cave_actor_animation.gd")
	var bearing: int=animation.native_bearing(roundi(to_camera.x*65536),roundi(to_camera.y*65536))
	var units: int=animation.native_bearing(roundi(heading.x*65536),roundi(heading.y*65536))<<8
	var shift:=4096*8/slots
	return ((((bearing-(((units-shift)&0xffffffff)>>8))&255)*slots)>>8)

func present() -> void:
	var updates: Dictionary={}
	for id in bodies:
		var actor: Dictionary=state.actors[id];var live: Dictionary=state.live[id]
		var d:=int(State.actor_row(src,id).definition)
		var clips: Dictionary=src.definitions[str(d)].clips
		var material: ShaderMaterial=materials[id]
		bodies[id].collision_layer=2 if actor.health>0 and actor.present else 0
		bodies[id].visible=actor.present
		if not actor.present: continue
		if actor.health<=0:
			var frame:=int(floor(float(actor.death)*State.FPS))
			if frame>=int(clips.death.frames): library.present(material,d,int(clips.corpse.selector),0)
			else: library.present(material,d,int(clips.death.selector),frame)
		elif not actor.woken:
			if str(src.get("dormant_pose","rise"))=="idle": library.present(material,d,int(clips.idle.selector),0,_view(id,library.view_count(d,int(clips.idle.selector))))
			else: library.present(material,d,int(clips.rise.selector),0)
		elif not State.ready_to_fight(state,src,id):
			library.present(material,d,int(clips.rise.selector),mini(int(floor(float(actor.rise)*State.FPS)),int(clips.rise.frames)-1))
		elif live.mode==Live.ATTACK:
			var attack: Dictionary=clips.attacks[int(live.attack)]
			library.present(material,d,int(attack.selector),mini(int(floor(float(live.elapsed)*State.FPS)),int(attack.frames)-1))
		elif live.mode==Live.PURSUE:
			library.present(material,d,int(clips.walk.selector),int(floor(float(clocks[id])*State.FPS))%int(clips.walk.frames),_view(id,library.view_count(d,int(clips.walk.selector))))
		else:
			library.present(material,d,int(clips.idle.selector),0,_view(id,library.view_count(d,int(clips.idle.selector))))
		if meshes.has(id): updates[meshes[id]]=library.last_texture
	# Cave composite: occlusion/light copies follow their creature (one pass).
	if str(config.get("render",""))=="cave_indexed":
		for pair in host.occluder_pairs+host.light_pairs:
			if not pair[0] in meshes.values(): continue
			pair[1].global_transform=pair[0].global_transform
			pair[1].visible=pair[0].is_visible_in_tree()
			if updates.has(pair[0]): pair[1].material_override.set_shader_parameter("indices",updates[pair[0]])

## Source controls (e.g. Museum exhibit control92) used with E: reach96, aim0.97 and
## a clear ray, the same gate as the Broken Thohan case.
func aimed_control() -> String:
	if not world_active() or not state.has("controls"): return ""
	var origin: Vector3=host.camera.global_position
	var forward: Vector3=-host.camera.global_basis.z
	for control in src.get("controls",[]):
		if not control.has("use"): continue
		var id:=str(int(control.control))
		if int(state.controls.get(id,0))!=int(control.use.owner_state): continue
		var p: Array=control.position
		var point: Vector3=Vector3(p[0],p[1],p[2])+origin()
		var delta: Vector3=point-origin
		if delta.length()>96 or delta.length()<0.01 or forward.dot(delta.normalized())<0.97: continue
		var query:=PhysicsRayQueryParameters3D.create(origin,point,1,[host.player.get_rid()])
		var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.position.distance_to(point)>12: continue
		return id
	return ""

func control_hint() -> String:
	return "" if aimed_control().is_empty() else "E — Touch the exhibit"

func use_control() -> bool:
	var id:=aimed_control()
	if id.is_empty(): return false
	State.use_control(state,src,id)
	sync_quests()
	if host.has_method("save_feedback"): host.save_feedback("Something stirs.")
	present()
	return true

func name_of(id: String) -> String:
	return str(config.get("names",{}).get(str(int(State.actor_row(src,id).definition)),"Creature"))

func targets() -> Dictionary:
	var result: Dictionary={}
	for id in bodies:
		if state.actors[id].health>0 and state.actors[id].present:
			result[str(config.get("target_prefix","creature"))+id]={"body":bodies[id],"point":bodies[id].global_position+Vector3(0,24,0),"actor":id,"owner":self}
	return result

func receive_damage(id: String, amount: int, melee: bool=true, effect: int=20) -> bool:
	if amount<=0 or not state.actors.has(id) or state.actors[id].health<=0: return false
	var loss:=mini(amount,int(state.actors[id].health))
	var scale:=int(State.actor_row(src,id).reward_scale)
	if melee:
		var owner_key:=str(config.get("fighting_owner","fighting_checkpoint"))
		var reward:=preload("res://scripts/lol2/cave_melee_reward.gd").apply(host.get(owner_key),int(state.actors[id].health),amount,scale)
		if reward.has("error"): return false
		host.set(owner_key,reward.quests)
	elif host.starting_magic==null or not host.starting_magic.award_hit(loss,effect,scale): return false
	if State.damage(state,src,id,amount)!=loss: return false
	if state.actors[id].health==0: net_holds.erase(id)
	sync_quests()
	if host.has_method("save_feedback"): host.save_feedback((name_of(id)+" defeated.") if state.actors[id].health==0 else "Strike landed.")
	present()
	return true

func aimed() -> String:
	var origin: Vector3=host.camera.global_position
	var query:=PhysicsRayQueryParameters3D.create(origin,origin-host.camera.global_basis.z*STRIKE_REACH,3,[host.player.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("population_owner") or hit.collider.get_meta("population_owner")!=self: return ""
	return str(hit.collider.get_meta("population_actor"))

func strike() -> bool:
	if host.get("bacatta")!=null and is_instance_valid(host.bacatta) and host.bacatta.input_locked(): return false
	if not world_active() or strike_remaining>0: return false
	if host.player_form==0 and host.equipped_item=="": return false
	strike_remaining=STRIKE_COOLDOWN
	var id:=aimed()
	if id.is_empty(): return false
	var damage: int=Forms.melee_damage(host.player_form,host.equipped_item!="")
	if host.get("item_effects")!=null and host.item_effects.has_method("melee_damage"): damage=host.item_effects.melee_damage(damage)
	if not receive_damage(id,damage): return false
	net_hit(id,str(host.equipped_item))
	return true

## Net of Exile on a landed hit (net_exile_hold.gd).
func net_hit(id: String, item: String) -> bool:
	if not Net.apply(net_holds,id,item,state.actors.has(id) and int(state.actors[id].health)>0): return false
	state.live[id].merge({"mode":Live.IDLE,"elapsed":0.0,"hit":false,"hits":0},true)
	bodies[id].velocity=Vector3.ZERO
	Net.notify(host,Net.feedback(name_of(id)))
	present()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		if aimed()!="" and strike(): get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_R and host.starting_magic!=null and host.starting_magic.health()==0:
		host.starting_magic.set_health(30)
		for id in bodies: state.live[id].merge({"mode":Live.IDLE,"elapsed":0.0,"hit":false,"hits":0},true)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_instance_valid(label): return
	var id:=aimed() if world_active() else ""
	label.text="" if id.is_empty() else name_of(id)+" %d/%d" % [state.actors[id].health,int(State.actor_row(src,id).health)]+(" · netted" if Net.held(net_holds,id) else "")
	if host.starting_magic!=null and host.starting_magic.health()==0: label.text="You fell · R: recover here · F9: load save"
