extends Node3D
## Original actor23 placement/art; modern combat tuning and direct pursuit.
const Model = preload("res://scripts/lol2/cave_encounter_state.gd")
const ActorAnimation = preload("res://scripts/lol2/cave_actor_animation.gd")
const AudioState=preload("res://scripts/lol2/scripted_creature_audio_state.gd")
class State:
	const FPS:=8.0
var src: Dictionary={"actors":[{"actor":23,"definition":5}]}
var state: Dictionary={}
var bodies: Dictionary={}
var clocks: Dictionary={"23":0.0}
var audio: Node3D
var restoring_audio:=false
static func audio_contract() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/cave_roach_audio_source.json"))
func world_active() -> bool:
	return not host.flying and not get_tree().paused and not host.drowning.dead and not is_instance_valid(host.video_overlay) and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and model.player_health>0
var model := Model.new()
var animation := ActorAnimation.new()
var host: Node3D
var body: CharacterBody3D
var mesh: MeshInstance3D
var facing := Vector2.DOWN
var spawn := Vector3.ZERO
var attacking := false
var ready_for_combat := false
var startup_active := false
var startup_elapsed := 0.0

func setup(walkthrough: Node3D) -> void:
	host = walkthrough
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/cave_roach/actor.json"))
	assert(animation.load_assets().is_empty())
	assert(animation.load_extra_roach_actions().is_empty())
	model.configure_attack(animation.attack_impact_frame, animation.action_textures[5].size(), animation.PREVIEW_FPS)
	spawn = host.point(source.position)+host.native_translation
	var angle := float(source.heading_units)*TAU/65536.0
	facing = Vector2(sin(angle),cos(angle))
	body = CharacterBody3D.new()
	body.name = "OriginalRoach23"
	body.position = spawn
	body.collision_layer = 2
	body.collision_mask = 1
	body.safe_margin = 0.05
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 6
	shape.height = 12
	collider.shape = shape
	collider.position.y = 6
	body.add_child(collider)
	add_child(body)
	mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = animation.canvas_size*animation.world_units_per_pixel
	quad.center_offset = animation.centre_offset
	mesh.mesh = quad
	mesh.layers = 2
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/lol2/indexed_surface_review.gdshader")
	material.set_shader_parameter("sprite",true)
	mesh.material_override = material
	body.add_child(mesh)
	host._copy_occluders(mesh)
	host.player.collision_mask |= 2
	ready_for_combat = true
	_sync(0.0,false)
	bodies={"23":body}
	audio=preload("res://scripts/lol2/cave_entrance_roach_audio.gd").new();add_child(audio)
	assert(audio.setup(self,audio_contract(),"res://assets/lol2/generated/cave_roach_audio/audio.json").is_empty())

func clear_ray(start: Vector3, end: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(start,end,1,[host.player.get_rid(),body.get_rid()])
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func strike() -> bool:
	if host.flying or host.get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or (host.player_form == 0 and host.equipped_item == ""): return false
	var target := body.global_position+Vector3.UP*6
	var delta: Vector3 = target-host.camera.global_position
	var aimed: bool = delta.length()>0.01 and (-host.camera.global_basis.z).dot(delta.normalized())>=0.9
	return receive_strike(delta.length()<=96,aimed,clear_ray(host.camera.global_position,target),preload("res://scripts/lol2/player_form_rules.gd").melee_damage(host.player_form,host.equipped_item != ""))

func receive_strike(in_reach: bool, aimed: bool, unobstructed: bool, damage: int) -> bool:
	if damage<=0: return false
	var before:=snapshot()
	var hit := model.strike(in_reach,aimed,unobstructed,damage)
	if hit:
		var reward:=preload("res://scripts/lol2/cave_melee_reward.gd").apply(host.quest_state,int(before.enemy_health),damage,2)
		if reward.has("error"):
			restore(before)
			return false
		host.quest_state=reward.quests
		host._save_feedback("Creature defeated." if model.enemy_health == 0 else "Strike landed.")
		body.collision_layer = 0 if model.enemy_health == 0 else 2
		_sync(0.0,false)
	return hit

func receive_magic(damage: int, effect: int = 20) -> bool:
	if damage<=0 or model.enemy_health<=0: return false
	if not is_instance_valid(host.starting_magic) or not host.starting_magic.award_hit(mini(model.enemy_health,damage),effect,2): return false
	model.enemy_health=maxi(0,model.enemy_health-damage)
	if model.enemy_health==0:
		model.phase=Model.Phase.DEFEATED
		model.phase_remaining=0.0
		body.collision_layer=0
	_sync(0.0,false)
	return true

func tick(delta: float) -> void:
	if not ready_for_combat: return
	var running: bool = not host.flying and not host.get_tree().paused and not host.drowning.dead and not is_instance_valid(host.video_overlay) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and model.player_health>0
	if not running:
		if is_instance_valid(audio): audio.pause()
		body.velocity = Vector3.ZERO
		return
	var separation: Vector3 = host.player.global_position-body.global_position
	var distance := Vector2(separation.x,separation.z).length()
	var sight := absf(separation.y)<72 and clear_ray(body.global_position+Vector3.UP*12,host.player.global_position+Vector3.UP*8)
	if model.advance(delta,distance,sight,preload("res://scripts/lol2/player_form_rules.gd").protected(host),preload("res://scripts/lol2/player_defense.gd").scalar(host))>0:
		host._save_feedback("You fell. R returns to the checkpoint; F9 loads your save." if model.player_health==0 else "You were hit.")
	body.velocity.x = 0
	body.velocity.z = 0
	if model.phase == Model.Phase.PURSUING:
		var direction := Vector3(separation.x,0,separation.z).normalized()
		body.velocity.x = direction.x*42
		body.velocity.z = direction.z*42
	var previous := body.global_position
	if model.enemy_health>0:
		body.velocity.y = 0 if body.is_on_floor() else body.velocity.y-128*delta
		body.move_and_slide()
	var travel := body.global_position-previous
	var moving := Vector2(travel.x,travel.z).length()>0.001
	if moving: facing = Vector2(travel.x,-travel.z)
	_sync(delta,moving)

func _sync(delta: float, moving: bool) -> void:
	var relative: Vector3 = host.camera.global_position-body.global_position
	animation.select_direction(Vector2(relative.x,-relative.z),facing)
	if model.enemy_health<=0: animation.play_action(14)
	elif model.phase in [Model.Phase.WINDUP,Model.Phase.RECOVERY]: animation.play_action(5)
	elif startup_active and model.phase==Model.Phase.IDLE: animation.play_action(9)
	else: animation.clear_action()
	if model.enemy_health<=0 or model.phase!=Model.Phase.IDLE: startup_active=false
	if animation.action_key==9:
		startup_elapsed=minf(startup_elapsed+delta,8.0/animation.PREVIEW_FPS)
		animation.set_action_elapsed(startup_elapsed)
		if animation.action_finished():
			startup_active=false
			animation.clear_action()
	if animation.action_key<0 and model.phase==Model.Phase.IDLE: animation.set_view(0)
	if animation.action_key==5: animation.set_action_elapsed(model.attack_elapsed())
	elif animation.action_key!=9: animation.advance(delta,model.phase==Model.Phase.PURSUING and moving)
	mesh.visible = model.enemy_health>0 or not animation.action_finished()
	var texture: Texture2D = animation.textures[animation.frame_index]
	mesh.material_override.set_shader_parameter("indices",texture)
	for pair in host.occluder_pairs+host.light_pairs:
		if pair[0]==mesh:
			pair[1].global_transform = mesh.global_transform
			pair[1].visible = mesh.visible
			pair[1].material_override.set_shader_parameter("indices",texture)

	if is_instance_valid(audio) and not restoring_audio: audio.sync(delta)

func recover() -> void:
	model.player_health = Model.PLAYER_HEALTH
	model.strike_remaining = 0.0
	if model.enemy_health>0:
		model.phase = Model.Phase.IDLE
		model.phase_remaining = 0.0
	body.velocity = Vector3.ZERO

func snapshot() -> Dictionary:
	var p := body.position
	var result: Dictionary={"actor":23,"position":[p.x,p.y,p.z],"facing":[facing.x,facing.y],
		"player_health":model.player_health,"enemy_health":model.enemy_health,
		"phase":model.phase,"phase_remaining":model.phase_remaining,"strike_remaining":model.strike_remaining,
		"animation_elapsed":animation.elapsed,"startup_active":startup_active,"startup_elapsed":startup_elapsed}
	if state.has("audio"): result.audio=state.audio.duplicate(true)
	return result

static func validate(value: Variant) -> bool:
	if not value is Dictionary or value.get("actor") != 23: return false
	for key in ["position","facing"]:
		var vector = value.get(key)
		if not vector is Array or vector.size() != (3 if key=="position" else 2): return false
		for number in vector:
			if not _number(number) or absf(float(number))>1000000: return false
	for entry in [["player_health",30],["enemy_health",24],["phase",4]]:
		var number = value.get(entry[0])
		if not _number(number) or number != floorf(float(number)) or number<0 or number>entry[1]: return false
	for entry in [["phase_remaining",1.5],["strike_remaining",0.45],["animation_elapsed",1000000.0]]:
		var number = value.get(entry[0])
		if not _number(number) or number<0 or number>entry[1]: return false
	if (value.enemy_health==0) != (value.phase==Model.Phase.DEFEATED): return false
	if value.phase==Model.Phase.RECOVERY and value.phase_remaining>0.5: return false
	if value.phase in [Model.Phase.IDLE,Model.Phase.PURSUING,Model.Phase.DEFEATED] and value.phase_remaining!=0: return false
	if value.has("startup_active") or value.has("startup_elapsed"):
		if not value.get("startup_active") is bool or not _number(value.get("startup_elapsed")): return false
		if value.startup_elapsed<0 or value.startup_elapsed>8.0/ActorAnimation.PREVIEW_FPS: return false
		if value.startup_active and (value.phase!=Model.Phase.IDLE or value.enemy_health<=0 or value.startup_elapsed>=8.0/ActorAnimation.PREVIEW_FPS): return false
	if value.has("audio") and not AudioState.validate(value.audio,[{"actor":23,"definition":5}],audio_contract()).is_empty(): return false
	return true

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func restore(value: Dictionary) -> void:
	assert(validate(value))
	restoring_audio=true
	state={}
	if value.has("audio"): state.audio=AudioState.canonical(value.audio)
	body.position = Vector3(value.position[0],value.position[1],value.position[2])
	body.velocity = Vector3.ZERO
	facing = Vector2(value.facing[0],value.facing[1])
	for key in ["player_health","enemy_health","phase","phase_remaining","strike_remaining"]: model.set(key,value[key])
	# Legacy saves already represent a running encounter; do not replay startup.
	startup_active=value.get("startup_active",false)
	startup_elapsed=float(value.get("startup_elapsed",8.0/ActorAnimation.PREVIEW_FPS))
	animation.reset()
	_sync(0.0,false)
	animation.elapsed = float(value.animation_elapsed)
	_sync(0.0,model.phase==Model.Phase.PURSUING)
	body.collision_layer = 2 if model.enemy_health>0 else 0

	restoring_audio=false
	if is_instance_valid(audio): audio.sync(0.0,true)
