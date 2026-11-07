extends Node3D
## Source support events for the plank bridge, separate from Bacatta's earth causeway.
## Quest state owns the one-time break and contact latch. Presentation reconstructs from that state on load.
const State = preload("res://scripts/lol2/jungle_bridge_break_state.gd")
const Body = preload("res://scripts/lol2/player_form_body.gd")
const KEY := "jungle_bridge"
const ROOT := "res://assets/lol2/generated/jungle_bridge_break/"
var host: Node3D
var src: Dictionary
var debris: Dictionary = {}
var sounds: Dictionary = {}
var effect_log: Array = []
var creature_barrier: StaticBody3D

static func assets_ready() -> bool:
	return FileAccess.file_exists(ROOT+"media.json") and FileAccess.file_exists(ROOT+"sounds/452.wav")

func setup(owner_host: Node3D) -> String:
	host = owner_host
	src = State.source()
	var media: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"media.json"))
	if not media is Dictionary or int(media.get("version",0)) != 1: return "Invalid plank bridge media."
	var materials: Dictionary = {}
	for key in media.materials:
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ROOT+str(media.materials[key])))
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		materials[key] = m
	for row in media.props:
		var quad := QuadMesh.new()
		quad.size = Vector2(float(row.right)-float(row.left),float(row.top)-float(row.bottom))
		quad.center_offset = Vector3((float(row.left)+float(row.right))/2.0,(float(row.top)+float(row.bottom))/2.0,0)
		quad.material = materials[row.material]
		var node := MeshInstance3D.new()
		node.name = "BridgeDebris%d" % int(row.record)
		node.mesh = quad
		node.position = Vector3(row.position[0],row.position[1],row.position[2])
		add_child(node)
		debris[int(row.record)] = node
	for request in [452,777,779,781]:
		var audio := AudioStreamPlayer3D.new()
		audio.stream = AudioStreamWAV.load_from_file(ROOT+"sounds/%d.wav" % request)
		if audio.stream == null: return "Missing plank bridge sound %d." % request
		audio.unit_size = 300
		add_child(audio)
		sounds[request] = audio
	creature_barrier = preload("res://scripts/lol2/creature_region_barrier.gd").new()
	add_child(creature_barrier)
	creature_barrier.setup(host,src.creature_region)
	return restore()

func state() -> Dictionary: return host.quest_state.get(KEY,State.initial())
func broken() -> bool: return bool(state().broken)

func restore() -> String:
	var packet: Variant = host.quest_state.get(KEY,State.initial())
	var error := State.validate(packet,src)
	if not error.is_empty(): return error
	# Preserve legacy quest envelopes exactly until this feature changes state.
	if host.quest_state.has(KEY): host.quest_state[KEY] = State.canonical(packet)
	for audio in sounds.values(): audio.stop()
	present()
	return ""

func present() -> void:
	var done := broken()
	host.static_assemblies.set_mode(int(src.breaks.plank),int(src.breaks.effects.plank_mode) if done else 0)
	host.static_assemblies.set_present(int(src.piece211.id),done)
	for mesh in debris.values(): mesh.visible = done
	creature_barrier.set_enabled(done)

## Called after host movement, once per physics tick. The foot support adapter replaces native vertical classification.
func advance() -> Array:
	var point: Vector3 = host.player.global_position
	point.y -= Body.FOOT_OFFSET
	var packet := state()
	var previous_owner := int(packet.contact.owner)
	var effects := State.advance(packet,src,point,host.player.is_on_floor() and not host.flying,int(host.player_form))
	if previous_owner != int(packet.contact.owner) or not effects.is_empty(): host.quest_state[KEY] = packet
	for effect in effects:
		effect_log.append(effect)
		if effect.type == "sound":
			var audio: AudioStreamPlayer3D = sounds[int(effect.request)]
			var p: Array = src.planks[str(int(effect.owner))].position
			audio.position = Vector3(p[0],p[1],p[2])
			audio.play()
	if not effects.is_empty(): present()
	if effect_log.size()>64: effect_log=effect_log.slice(-64)
	return effects
