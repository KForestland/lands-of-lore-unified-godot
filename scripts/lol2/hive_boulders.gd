extends Node3D
## Saved visual/path actors and contact response; native scheduler parity remains open.
const State=preload("res://scripts/lol2/hive_boulder_actor_state.gd")
const PathControl=preload("res://scripts/lol2/hive_path_control.gd")
const Presenter=preload("res://scripts/lol2/hive_executioner_sprite.gd")
const SPEED=160.0 # Modern locomotion adapter, not a recovered native statistic.
const GRAVITY=320.0
const Contact=preload("res://scripts/lol2/hive_boulder_contact_state.gd")
const Impulse=preload("res://scripts/lol2/hive_boulder_impulse.gd")
const Damage=preload("res://scripts/lol2/hive_boulder_damage.gd")
const FormBody=preload("res://scripts/lol2/player_form_body.gd")
const FRICTION=256.0 # Modern units/s² adapter. No timed contact cooldown.
var contact:=Contact.initial()
var player_attempted:=false
var host: Node3D
var state:=State.initial()
var bodies: Dictionary={}
var presenters: Dictionary={}
var data: Dictionary
func _ready() -> void:
	host=get_parent()
	data=host.boulder_surfaces.data
	for id in State.SPAWNS:
		var body:=CharacterBody3D.new()
		body.name="Boulder"+id
		# Environment collision; player response is resolved explicitly below.
		body.collision_layer=0
		body.collision_mask=1
		body.floor_snap_length=2.0
		var collider:=CollisionShape3D.new()
		var sphere:=SphereShape3D.new()
		sphere.radius=20.0
		collider.shape=sphere
		collider.position.y=20.0
		body.add_child(collider)
		var sprite:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		quad.size=Vector2(95.0/78.0*40.0,40.0)
		quad.center_offset=Vector3(0,20,0)
		sprite.mesh=quad
		var material:=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold=0.5
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.material_override=material
		body.add_child(sprite)
		add_child(body)
		body.add_collision_exception_with(host.player)
		var presenter:=Presenter.new()
		var error:=presenter.bind(sprite,"res://assets/lol2/generated/hive_worm_sprites/",{0:{"frames":1,"width":95,"height":78},1:{"frames":10,"width":95,"height":78}},Vector2(95,78))
		assert(error.is_empty())
		bodies[id]=body
		presenters[id]=presenter
	host.boulder_surfaces.script_group.connect(on_group)
	restore(state)
func on_group(group: int) -> void:
	State.apply_group(state,group)
func contact_checkpoint() -> Dictionary:
	return contact.duplicate(true)
func restore_contact(value: Variant) -> String:
	var error:=Contact.validate(value)
	if not error.is_empty(): return error
	contact=Contact.canonical(value)
	player_attempted=false
	return ""
func checkpoint() -> Dictionary:
	return state.duplicate(true)
func restore(value: Variant) -> String:
	var error:=State.validate(value)
	if not error.is_empty(): return error
	state=State.canonical(value)
	for id in bodies:
		var row: Dictionary=state.actors[id]
		bodies[id].position=Vector3(row.position[0],row.position[1],row.position[2])
		bodies[id].velocity=Vector3(0,row.velocity_y,0)
		bodies[id].visible=not state.legacy_retired
		presenters[id].present({"pose":1 if row.rolling else 0,"source_pose":{"selector":1 if row.rolling else 0,"frame":row.frame}})
	return ""
func _physics_process(delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	if state.legacy_retired or get_tree().paused or host.flying or host.get_node("Warriors").health==0:
		player_attempted=false
		return
	var conversation=host.get_node("ConversationReview")
	if conversation.started and not conversation.completed:
		player_attempted=false
		return
	if contact.magnitude>0:
		player_attempted=true
		var angle: float=float(contact.angle)*TAU/65536.0
		host.player.move_and_collide(Vector3(sin(angle),0,-cos(angle))*float(contact.magnitude)*delta)
		contact.magnitude=maxf(0,float(contact.magnitude)-FRICTION*delta)
	# One first admitted pair per player movement attempt, matching scanner ordering.
	if player_attempted:
		for id in bodies:
			if resolve_contact(id,true): break
	player_attempted=false
	for id in bodies:
		var row: Dictionary=state.actors[id]
		if not row.active: continue
		var body: CharacterBody3D=bodies[id]
		State.advance_animation(row,delta)
		var horizontal:=Vector2.ZERO
		if row.rolling:
			var point: Array=data.path.points[absi(int(row.index))].position
			var distance:=Vector2(point[0]-body.position.x,point[1]-body.position.z)
			if distance.length()<20.0:
				row.index=PathControl.advance_index(data.path,row.index,0).index
				point=data.path.points[absi(int(row.index))].position
				distance=Vector2(point[0]-body.position.x,point[1]-body.position.z)
			horizontal=distance.normalized()*minf(SPEED,distance.length()/delta)
		body.velocity=Vector3(horizontal.x,maxf(-4096.0,float(row.velocity_y)-GRAVITY*delta),horizontal.y)
		var attempted: bool=body.velocity.length_squared()>0.000001
		body.move_and_slide()
		if attempted: resolve_contact(id,false)
		row.position=[body.position.x,body.position.y,body.position.z]
		row.velocity_y=body.velocity.y
		presenters[id].present({"pose":1 if row.rolling else 0,"source_pose":{"selector":1 if row.rolling else 0,"frame":row.frame}})


func resolve_contact(id: String, player_mover: bool) -> bool:
	if state.legacy_retired or get_tree().paused or host.flying or host.get_node("Warriors").health<=0: return false
	var conversation=host.get_node("ConversationReview")
	if conversation.started and not conversation.completed: return false
	var form: int=host.player_form
	# Native scanner excludes candidates <=20 high from a type2 mover's scan.
	if not player_mover and FormBody.HEIGHTS[form]<=20: return false
	var body: CharacterBody3D=bodies[id]
	var feet: float=host.player.position.y-FormBody.FOOT_OFFSET
	# Modern broadphase uses source body extents; native step/ceiling classification is separate.
	if feet>=body.position.y+40 or feet+FormBody.HEIGHTS[form]<=body.position.y: return false
	var offset:=Vector2(host.player.position.x-body.position.x,host.player.position.z-body.position.z)
	var radius: float=20+FormBody.RADII[form]
	var distance:=offset.length()
	if distance>=radius: return false
	var outward:=offset/distance if distance>0.000001 else Vector2(1,0)
	var correction:=Vector3(outward.x,0,outward.y)*(radius-distance+0.01)
	if player_mover: host.player.move_and_collide(correction)
	else: body.move_and_collide(-correction)
	var angle:=posmod(int(atan2(outward.x,-outward.y)*65536.0/TAU),65536)
	var magnitude: int=[130,55,205][form]
	if contact.magnitude>0:
		var combined:=Impulse.combine({"angle":angle,"impulse":magnitude<<16,"previous_angle":contact.angle,"previous_impulse":int(contact.magnitude*65536),"rounding_mode":0})
		assert(not combined.has("error"))
		angle=combined.stored_angle
		magnitude=combined.stored_impulse
	contact={"version":1,"angle":angle,"magnitude":float(magnitude)}
	# State5 rejects the script event even during the remaining terminal animation.
	if not state.actors[id].stopping and not preload("res://scripts/lol2/player_form_rules.gd").protected(host):
		var warriors=host.get_node("Warriors")
		# Existing playable health adapter: normal mode, no equipment descriptors.
		var result:=Damage.calculate({"mode":1,"scalar":0,"current":warriors.health,"descriptors":[]})
		assert(not result.has("error"))
		warriors.health=result.remaining
		if warriors.health==0: host.set_physics_process(false)
	return true
