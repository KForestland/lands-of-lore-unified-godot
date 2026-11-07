extends SceneTree
## Cave scenery contract + host (stub walkthrough, no rendering): 58 ambient rows (7 torches with the F1A94 chained
## flame, 8 meat, 12 mist, 8 waterfalls, 20 water pillars, 3 shrinktofit), animated at the 0.1 s owner-trial adapter rate,
## native boxes and 0x40/0x80 flips, records hosted elsewhere or with behaviour of their own excluded, and 18 looping
## emitters (started once the walkthrough is ready; native trigger UNKNOWN) at their owner positions with the stored native volume/range bytes.
const Scenery = preload("res://scripts/lol2/cave_scenery.gd")
const EXCLUDED := [19, 139, 140, 141, 142, 143, 473, 484, 486, 1208, 1209, 1210, 1211]
const TORCHES := ["20", "224", "519", "550", "551", "623", "624"]

class StubHost extends Node3D:
	var native_translation := Vector3(10, 20, 30)
	var walkthrough_ready := false
	var copied: Array = []
	func _indexed_material(path: String) -> ShaderMaterial:
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/lol2/indexed_surface_review.gdshader")
		m.set_shader_parameter("indices", ImageTexture.create_from_image(Image.load_from_file(path)))
		return m
	func _copy_occluders(node: Node) -> void: copied.append(node)

func _initialize() -> void: run.call_deferred()
func v(a: Array) -> Vector3: return Vector3(a[0], a[1], a[2])

func fail(message: String) -> void:
	push_error(message); quit(1)

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Scenery.SOURCE))
	if source.props.size() != 58 or source.emitters.size() != 18: return fail("Row counts differ: %d/%d" % [source.props.size(), source.emitters.size()])
	if source.frame_seconds != 0.1: return fail("Owner trial 2026-10-29: frame_seconds must be the 0.1 s Cave adapter rate (native rate UNKNOWN)")
	var groups := {}
	for id in source.props: groups[source.props[id].group] = int(groups.get(source.props[id].group, 0)) + 1
	if groups != {"wall torch": 7, "meat (hanging)": 8, "jungle mist": 12, "waterfall": 8, "water pillar": 16, "big water pillar": 4, "shrinktofit": 3}:
		return fail("Group counts differ: %s" % groups)
	for r in EXCLUDED:
		if source.props.has(str(r)): return fail("Record %d must not be hosted here" % r)
	for id in source.props:
		if source.props[id].has("chain") != (id in TORCHES): return fail("Chain only on the template73 torches: " + id)
	var t20: Dictionary = source.props["20"]
	if v(t20.position) != Vector3(-1564, 40, -6094) or t20.chain.material != "prop_222" or t20.chain.frames.size() != 38 or t20.material != "prop_219":
		return fail("Torch 20 differs: %s" % t20)
	var e: Dictionary = source.emitters["prop20"]
	if int(e.sound) != 741 or v(e.position) != Vector3(-1564, 40, -6094) or int(e.volume) != 128 or int(e.inner) != 160 or int(e.outer) != 480:
		return fail("Emitter prop20 differs: %s" % e)
	var c: Dictionary = source.emitters["control171"]
	if int(c.sound) != 438 or v(c.position) != Vector3(1334, -215, -11643): return fail("Emitter control171 differs: %s" % c)
	if source.emitters.has("prop383") or source.emitters.has("prop343"): return fail("Commands naming another object are not hosted")

	var host := StubHost.new()
	root.add_child(host)
	var scenery = Scenery.new()
	host.add_child(scenery)
	var error: String = scenery.setup(host)
	if not error.is_empty(): return fail(error)
	if scenery.meshes.size() != 65 or host.copied.size() != 65: return fail("Expected 58 + 7 chain billboards mirrored, got %d/%d" % [scenery.meshes.size(), host.copied.size()])
	for id in scenery.meshes:
		var mesh: MeshInstance3D = scenery.meshes[id]
		var row: Dictionary = source.props[id.trim_suffix("chain")]
		var box: Dictionary = row.chain if id.ends_with("chain") else row
		var quad: QuadMesh = mesh.mesh
		if mesh.layers != 2 or quad.size != Vector2(float(box.right) - float(box.left), float(box.top) - float(box.bottom)):
			return fail("Billboard %s is not the native box on layer 2" % id)
		if mesh.position != Vector3(row.position[0], row.position[1], row.position[2]) + host.native_translation: return fail("Billboard %s misplaced" % id)
		if id.ends_with("chain") != (quad.center_offset.z > 0.0): return fail("Chain depth wrong on " + id)
		if mesh.material_override.get_shader_parameter("indices") != scenery.textures[str(box.material)][0]: return fail("Not on the first frame: " + id)
		var flags := int(box.frame_flags) & 0xC0
		var scale: Vector2 = mesh.material_override.get_shader_parameter("uv_scale")
		if (scale.x < 0.0) != bool(flags & 0x40) or (scale.y < 0.0) != bool(flags & 0x80): return fail("Flip flags not applied on " + id)
	scenery.clock = 12.3
	scenery.present()
	for id in scenery.meshes:
		var box_material := str(scenery.meshes[id].get_meta("material"))
		var expected: int = int(12.3 / 0.1) % scenery.textures[box_material].size()
		if scenery.meshes[id].material_override.get_shader_parameter("indices") != scenery.textures[box_material][expected]: return fail("Frame does not follow the 0.1 s rate: " + id)
	if scenery.voices.size() != 18: return fail("Voices missing")
	for id in scenery.voices:
		var voice: AudioStreamPlayer3D = scenery.voices[id]
		var row: Dictionary = source.emitters[id]
		if (voice.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_FORWARD: return fail("Emitter %s does not loop" % id)
		if voice.position != Vector3(row.position[0], row.position[1], row.position[2]) + host.native_translation: return fail("Emitter %s misplaced" % id)
		if voice.playing: return fail("Emitter %s plays before the walkthrough is ready" % id)
	scenery.start_ambience()
	for id in scenery.voices:
		if not scenery.voices[id].playing: return fail("Emitter %s did not start" % id)
	print("PASS cave_scenery_state: 58 ambient rows + 7 chained torch flames on layer 2, first frame only, native boxes/flips, 13 records excluded, 18 looping emitters started at ready")
	quit()
