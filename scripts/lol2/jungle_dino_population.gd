extends Node3D
## Live L4_HJ DINO herds. State: quests.jungle_dino_population (travels with quests).
## Source positions/150HP/scale4, original indexed selectors and bite damage request;
## perception, steering and clip clocks are documented adapters.
const State=preload("res://scripts/lol2/jungle_dino_population_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const Sprite=preload("res://scripts/lol2/jungle_dino_sprite.gd")
const Forms=preload("res://scripts/lol2/player_form_rules.gd")
const Net=preload("res://scripts/lol2/net_exile_hold.gd")
## Same creature pixel scale as the cave Roach presentation (adapter).
const UNITS_PER_PIXEL:=0.21818181818181817
const STRIKE_COOLDOWN:=0.45
const STRIKE_REACH:=110.0
var host: Node3D
var bodies: Dictionary={}
var sprites: Dictionary={}
var meshes: Dictionary={}
var clocks: Dictionary={}
var moving: Dictionary={}
var rules: Dictionary={}
var source: Dictionary={}
var strike_remaining: float:
	get: return float(view().get("strike_remaining",0.0))
	set(value): state().strike_remaining=value
## Net of Exile holds {actor id: seconds left}; transient (net_exile_hold.gd).
var net_holds: Dictionary={}
var label: Label
var audio: Node3D

func setup(walkthrough: Node3D) -> String:
	host=walkthrough
	source=State.source();rules=State.rules()
	var library:=Sprite.new()
	for row in source.actors:
		var id:=str(int(row.actor))
		var body:=CharacterBody3D.new()
		body.name="SourceDino"+id
		body.collision_layer=2;body.collision_mask=1
		body.safe_margin=0.05
		body.set_meta("population_actor",id)
		body.set_meta("population_owner",self)
		var shape:=CollisionShape3D.new()
		var capsule:=CapsuleShape3D.new()
		capsule.radius=14;capsule.height=40
		shape.shape=capsule;shape.position.y=20
		body.add_child(shape)
		var mesh:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		quad.size=Vector2(320,200)*UNITS_PER_PIXEL
		# Canvas row188 is the lowest opaque idle pixel; place it on the floor.
		quad.center_offset=Vector3(0,(188-100)*UNITS_PER_PIXEL,0)
		mesh.mesh=quad
		var material:=ShaderMaterial.new()
		material.shader=preload("res://scripts/lol2/jungle_dino_sprite.gdshader")
		mesh.material_override=material
		body.add_child(mesh);add_child(body)
		var sprite:=Sprite.new()
		var error:=library.bind(mesh) if sprites.is_empty() else sprite.bind_shared(mesh,library)
		if not error.is_empty(): return error
		sprites[id]=library if sprites.is_empty() else sprite
		bodies[id]=body;meshes[id]=mesh;clocks[id]=0.0;moving[id]=false
	host.player.collision_mask|=2
	label=Label.new();label.position=Vector2(16,48)
	var layer:=CanvasLayer.new();layer.add_child(label);add_child(layer)
	audio=preload("res://scripts/lol2/jungle_dino_audio.gd").new()
	add_child(audio);audio.setup(self)
	restore()
	return ""

## Mutating access: inserts the source packet into quests on first live change.
func state() -> Dictionary:
	if not host.quest_state.has("jungle_dino_population"): host.quest_state.jungle_dino_population=State.initial()
	return host.quest_state.jungle_dino_population

## Read-only access: legacy quests stay byte-identical until something happens.
var _fresh: Dictionary={}
func view() -> Dictionary:
	if host.quest_state.has("jungle_dino_population"): return host.quest_state.jungle_dino_population
	if _fresh.is_empty(): _fresh=State.initial()
	return _fresh

func restore() -> void:
	_fresh={}
	net_holds.clear()
	var s:=view()
	for id in bodies:
		var p: Array=s.actors[id].position
		bodies[id].position=Vector3(p[0],p[1],p[2])
		bodies[id].velocity=Vector3.ZERO
		moving[id]=false;clocks[id]=0.0
	if audio!=null: audio.sync(0.0,true)
	present()

func world_active() -> bool:
	return host.starting_magic!=null and host.starting_magic.world_active()

func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	if not world_active():
		if audio!=null: audio.pause()
		for id in bodies: bodies[id].velocity=Vector3.ZERO
		return
	if strike_remaining>0:
		strike_remaining=maxf(0.0,snappedf(strike_remaining-delta,1.0/1024))
	# Work on the read view; quests gain the packet only once something changes.
	var s:=view()
	var changed:=false
	for actor in s.actors.values():
		if actor.health==0 and actor.death<State.DEATH_SECONDS: changed=true
	State.advance_death(s,delta)
	Net.tick(net_holds,delta)
	var target: Vector3=host.player.global_position
	var protected: bool=Forms.protected(host)
	var space:=get_world_3d().direct_space_state
	for id in bodies:
		var body: CharacterBody3D=bodies[id]
		var live: Dictionary=s.live[id]
		moving[id]=false
		if s.actors[id].health<=0:
			body.velocity=Vector3.ZERO;continue
		if Net.held(net_holds,id):
			# Netted: stands still, any started bite is cancelled.
			body.velocity=Vector3.ZERO
			if live.mode!=Live.IDLE or float(live.elapsed)!=0.0 or live.hit: live.merge({"mode":Live.IDLE,"elapsed":0.0,"hit":false},true);clocks[id]=0.0;changed=true
			continue
		var separation: Vector3=target-body.global_position
		var distance:=Vector2(separation.x,separation.z).length()
		var sight:=false
		if distance<=State.ALERT_RANGE and absf(separation.y)<96:
			var ray:=PhysicsRayQueryParameters3D.create(body.global_position+Vector3.UP*30,target+Vector3.UP*8,1,[body.get_rid(),host.player.get_rid()])
			ray.hit_from_inside=true
			sight=space.intersect_ray(ray).is_empty()
		var health: int=host.starting_magic.health()
		var previous_mode: int=live.mode
		rules=rules.duplicate()
		rules.damage=preload("res://scripts/lol2/player_defense.gd").incoming(host,int(source.damage))
		var damage:=Live.advance(live,true,delta,distance,sight,protected,health,rules)
		if damage>0:
			host.starting_magic.set_health(maxi(0,health-damage))
			if host.has_method("save_feedback"): host.save_feedback("You fell. R: recover here · F9: load save" if host.starting_magic.health()==0 else "A dinosaur bit you.")
		if live.mode!=previous_mode:
			clocks[id]=0.0;changed=true
		if live.mode==Live.ATTACK or damage>0: changed=true
		if live.mode!=Live.PURSUE:
			body.velocity=Vector3.ZERO
			if live.mode==Live.ATTACK and distance>0.01: _face(id,Vector2(separation.x,-separation.z))
			continue
		var direction:=Vector3(separation.x,0,separation.z).normalized()
		var ahead: Vector3=body.global_position+direction*16
		var floor_ray:=PhysicsRayQueryParameters3D.create(ahead+Vector3.UP*12,ahead-Vector3.UP*60,1,[body.get_rid(),host.player.get_rid()])
		if space.intersect_ray(floor_ray).is_empty():
			body.velocity=Vector3.ZERO;continue
		var before: Vector3=body.global_position
		body.velocity=Vector3(direction.x*State.SPEED,0 if body.is_on_floor() else body.velocity.y-128*delta,direction.z*State.SPEED)
		body.move_and_slide()
		var travel: Vector3=body.global_position-before
		if Vector2(travel.x,travel.z).length()>0.001:
			moving[id]=true
			_face(id,Vector2(travel.x,-travel.z))
		s.actors[id].position=Live.saved_position(body.position)
	for id in bodies:
		if moving[id] or (s.actors[id].health>0 and s.live[id].mode==Live.IDLE):
			clocks[id]+=delta
			if moving[id]: changed=true
	if changed and not host.quest_state.has("jungle_dino_population"):
		host.quest_state.jungle_dino_population=s
		_fresh={}
	if audio!=null: audio.sync(delta)
	present()

func _face(id: String, facing: Vector2) -> void:
	view().live[id].heading=Live.heading_units(facing)

func _view(id: String) -> int:
	var relative: Vector3=host.camera.global_position-bodies[id].global_position
	var heading: Vector2=Live.heading_vector(int(view().live[id].heading))
	var to_camera:=Vector2(relative.x,-relative.z)
	if to_camera.length_squared()<0.000001: return 0
	var animation:=preload("res://scripts/lol2/cave_actor_animation.gd")
	var bearing: int=animation.native_bearing(roundi(to_camera.x*65536),roundi(to_camera.y*65536))
	var units: int=animation.native_bearing(roundi(heading.x*65536),roundi(heading.y*65536))<<8
	return ((((bearing-(((units-4096)&0xffffffff)>>8))&255)*8)>>8)

func present() -> void:
	var s:=view()
	for id in bodies:
		var actor: Dictionary=s.actors[id]
		var live: Dictionary=s.live[id]
		var sprite=sprites[id]
		var clips: Dictionary=source.clips
		bodies[id].collision_layer=2 if actor.health>0 else 0
		if actor.health<=0:
			var frame:=mini(int(floor(float(actor.death)*State.FPS)),int(clips.death.frames))
			if frame>=int(clips.death.frames): sprite.present(clips.corpse.selector,0)
			else: sprite.present(clips.death.selector,frame)
		elif live.mode==Live.ATTACK:
			sprite.present(clips.bite.selector,mini(int(floor(float(live.elapsed)*State.FPS)),int(clips.bite.frames)-1))
		elif live.mode==Live.PURSUE:
			sprite.present(clips.walk.selector,int(floor(float(clocks[id])*State.FPS))%int(clips.walk.frames),_view(id))
		else:
			sprite.present(clips.idle.selector,int(floor(float(clocks[id])*State.FPS))%int(clips.idle.frames))

func targets() -> Dictionary:
	var result: Dictionary={}
	var s:=view()
	for id in bodies:
		if s.actors[id].health>0:
			result["jungledino"+id]={"body":bodies[id],"point":bodies[id].global_position+Vector3(0,24,0),"actor":id,"owner":self}
	return result

func receive_damage(id: String, amount: int, melee: bool=true, effect: int=20) -> bool:
	var s:=view()
	if amount<=0 or not s.actors.has(id) or s.actors[id].health<=0: return false
	var loss:=mini(amount,int(s.actors[id].health))
	if melee:
		var reward:=preload("res://scripts/lol2/cave_melee_reward.gd").apply(host.quest_state,int(s.actors[id].health),amount,int(source.reward_scale))
		if reward.has("error"): return false
		reward.quests.jungle_dino_population=s.duplicate(true)
		host.quest_state=reward.quests
		s=state()
	elif host.starting_magic==null or not host.starting_magic.award_hit(loss,effect,int(source.reward_scale)): return false
	if not host.quest_state.has("jungle_dino_population"):
		host.quest_state.jungle_dino_population=s.duplicate(true)
		s=state()
	if State.damage(s,id,amount)!=loss: return false
	if s.actors[id].health==0: net_holds.erase(id)
	if audio!=null: audio.sync(0.0)
	if host.has_method("save_feedback"): host.save_feedback("Dinosaur defeated." if s.actors[id].health==0 else "Strike landed.")
	present()
	return true

func aimed() -> String:
	var origin: Vector3=host.camera.global_position
	var forward: Vector3=-host.camera.global_basis.z
	var query:=PhysicsRayQueryParameters3D.create(origin,origin+forward*STRIKE_REACH,3,[host.player.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("population_owner") or hit.collider.get_meta("population_owner")!=self: return ""
	return str(hit.collider.get_meta("population_actor"))

func strike() -> bool:
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
	if not Net.apply(net_holds,id,item,view().actors.has(id) and int(view().actors[id].health)>0): return false
	state().live[id].merge({"mode":Live.IDLE,"elapsed":0.0,"hit":false},true)
	bodies[id].velocity=Vector3.ZERO;clocks[id]=0.0
	Net.notify(host,Net.feedback("dinosaur"))
	present()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		if aimed()!="" and strike(): get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_R and host.starting_magic!=null and host.starting_magic.health()==0:
		# Retry like the Hive: recover here, creature defeats and positions retained.
		host.starting_magic.set_health(30)
		for id in bodies: state().live[id].merge({"mode":Live.IDLE,"elapsed":0.0,"hit":false},true)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_instance_valid(label): return
	var id:=aimed() if world_active() else ""
	label.text="" if id.is_empty() else "Dinosaur %d/%d" % [view().actors[id].health,int(source.max_health)]+(" · netted" if Net.held(net_holds,id) else "")
	if host.starting_magic!=null and host.starting_magic.health()==0: label.text="You fell · R: recover here · F9: load save"
