extends Node3D
## Bounded Spark interaction for prop377. Casting input/range/cost/rate are modern adapters.
const ROOT := "res://assets/lol2/generated/hive_rune_light/"
const COST := 1
var host: Node3D
var sprite: Sprite3D
var textures: Array[Texture2D] = []
var unlit: Texture2D
var elapsed := 0.0
var was_lit := false
var glow: OmniLight3D
func _ready() -> void:
	host = get_parent()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"light.json"))
	position = Vector3(source.position[0],source.position[1],source.position[2])
	unlit = ImageTexture.create_from_image(Image.load_from_file(ROOT+source.states[0].images[0].file))
	for row in source.states[1].images: textures.append(ImageTexture.create_from_image(Image.load_from_file(ROOT+row.file)))
	var bounds: Array = source.states[0].bounds
	sprite = Sprite3D.new()
	sprite.texture = unlit
	sprite.pixel_size = float(bounds[3]-bounds[2])/unlit.get_height()
	sprite.scale.x = float(bounds[1]-bounds[0])/(unlit.get_width()*sprite.pixel_size)
	sprite.position.y = float(bounds[2]+bounds[3])/2.0
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	glow = OmniLight3D.new()
	glow.position.y = sprite.position.y
	glow.light_color = Color(1.0,0.6,0.25)
	glow.omni_range = 90
	glow.light_energy = 0.75
	glow.visible = false
	add_child(glow)
func aim_point() -> Vector3:
	return global_position+Vector3(0,sprite.position.y,0)
func target() -> bool:
	if not preload("res://scripts/lol2/player_form_rules.gd").can_cast(host.player_form): return false
	if host.runes.active() or host.runes.checkpoint.lights or host.flying or get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	if host.interface_hud.cursor_active or host.get_node("Warriors").health <= 0 or host.curse.state.phase in [1,3]: return false
	var actor = host.get_node("ConversationReview")
	if actor.started and not actor.completed: return false
	var offset: Vector3 = aim_point()-host.camera.global_position
	if offset.length() < 0.01 or offset.length() > 256.0 or (-host.camera.global_basis.z).dot(offset.normalized()) < 0.97: return false
	var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position,aim_point(),1,[host.player.get_rid()])
	ray.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func cast() -> bool:
	if not target(): return false
	var initial: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/player_progression_initial.json"))
	var saved: Dictionary = host.player_magic_checkpoint
	if saved.is_empty(): saved = {"version":1,"player":initial.magic}
	var result := preload("res://scripts/lol2/hive_magic_reward.gd").restore(saved)
	if result.has("error") or result.checkpoint.player.mana < COST or float(result.checkpoint.get("cooldown",0))>0: return false
	result.checkpoint.player.mana -= COST
	result.checkpoint.cooldown=0.5
	# Verified native initial durability2 ->0 and mask1 admit state1.
	# F2944 requests kind3 effects on state change, before animation playback.
	host.player_magic_checkpoint = result.checkpoint
	host.runes.checkpoint.lights = true
	elapsed = 0.0
	refresh()
	return true
func refresh() -> void:
	var lit: bool = host.runes.checkpoint.lights
	if lit != was_lit: elapsed = 0.0
	was_lit = lit
	glow.visible = lit
	sprite.texture = textures[int(elapsed*10.0)%textures.size()] if lit else unlit
func _process(delta: float) -> void:
	elapsed += delta
	refresh()
