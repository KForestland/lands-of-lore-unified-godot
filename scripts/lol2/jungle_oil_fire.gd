extends Node3D
## Vine-clearing oil pool fire (L4_HJ prop1350, scripts/lol2/jungle_oil_fire_source.json; longplay 39:44): the rock
## pile in the oil takes a Spark hit at state 0 (kind9 value 0x11, group 14784), which links the 15 dormant flames for
## good. State: quests.jungle_oil_fire {"lit": bool}. Modern adapters (docs/DEVIATIONS.md): Spark through the shared
## spark_receiver path; 100 magic experience once; sound and shake not hosted; flames are animated billboards in three phases.
const SOURCE := "res://scripts/lol2/jungle_oil_fire_source.json"
var host: Node3D
var source: Dictionary = {}
var pile: MeshInstance3D
var flames: Array[MeshInstance3D] = []
var pile_material: StandardMaterial3D
var flame_materials: Array[StandardMaterial3D] = []
var pile_frames: Array[Texture2D] = []
var flame_frames: Array[Texture2D] = []
var clock := 0.0

class Receiver:
	extends RefCounted
	var owner_node: Node
	func _init(node: Node) -> void: owner_node = node
	func receive_spark() -> bool: return owner_node.ignite()

static func assets_ready() -> bool:
	if not FileAccess.file_exists(SOURCE): return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	return data is Dictionary and FileAccess.file_exists(str(data.pile.frames[0]))

func setup(walkthrough: Node3D) -> String:
	name = "JungleOilFire"
	host = walkthrough
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not parsed is Dictionary: return "Jungle oil fire source missing."
	source = parsed
	for path in source.pile.frames: pile_frames.append(ImageTexture.create_from_image(Image.load_from_file(path)))
	for path in source.flames[0].frames: flame_frames.append(ImageTexture.create_from_image(Image.load_from_file(path)))
	pile_material = _material(pile_frames[0])
	pile = _billboard(source.pile, pile_material)
	for i in 3: flame_materials.append(_material(flame_frames[0]))
	for k in source.flames.size():
		var flame := _billboard(source.flames[k], flame_materials[k % 3])
		flames.append(flame)
	# Spark receiver at the pile (layer 2, as creatures: the Spark ray mask is 1|2).
	var body := StaticBody3D.new()
	body.name = "PileReceiver"
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var p: Dictionary = source.pile
	box.size = Vector3((float(p.right) - float(p.left)) * 0.6, float(p.top) - float(p.bottom), 80.0)
	shape.shape = box
	body.add_child(shape)
	body.set_meta("spark_receiver", Receiver.new(self))
	add_child(body)
	body.position = Vector3(p.position[0], float(p.position[1]) + (float(p.bottom) + float(p.top)) / 2.0, p.position[2])
	present()
	return ""

func _material(texture: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m

func _billboard(row: Dictionary, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(float(row.right) - float(row.left), float(row.top) - float(row.bottom))
	mesh.center_offset = Vector3((float(row.left) + float(row.right)) / 2.0, (float(row.bottom) + float(row.top)) / 2.0, 0)
	mesh.material = material
	var node := MeshInstance3D.new()
	node.name = "Prop%d" % int(row.prop)
	node.mesh = mesh
	node.position = Vector3(row.position[0], row.position[1], row.position[2])
	add_child(node)
	return node

func state() -> Dictionary:
	var quests: Dictionary = host.quest_state
	if not quests.get("jungle_oil_fire") is Dictionary: quests.jungle_oil_fire = {"lit": false}
	return quests.jungle_oil_fire

static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != 1 or not value.get("lit") is bool: return "Invalid jungle oil fire."
	return ""

## Read without creating the entry: loading the Jungle must not change the quests (hand-offs compare them).
func lit() -> bool:
	var saved: Variant = host.quest_state.get("jungle_oil_fire")
	return saved is Dictionary and bool(saved.get("lit", false))

## Group 14784 at state 0: the flames are linked for good.
func ignite() -> bool:
	if lit(): return false
	# Native group14784 command020100000c01: player property0C value1, magic100.
	# Compute before committing the once-only lit flag, so a refused reward remains retryable.
	var magic = host.get("starting_magic")
	if magic == null: return false
	var reward: Dictionary = preload("res://scripts/lol2/player_property_rewards.gd").magic(magic.magic_state(), 100)
	if reward.has("error"): return false
	magic.commit(reward.checkpoint)
	state().lit = true
	present()
	if host.has_method("save_feedback"): host.save_feedback("The oil catches fire!")
	return true

func present() -> void:
	for flame in flames: flame.visible = lit()

func _process(delta: float) -> void:
	if pile == null: return
	clock += delta
	var frame := int(clock * float(source.fps))
	pile_material.albedo_texture = pile_frames[frame % pile_frames.size()]
	if lit():
		for i in flame_materials.size(): flame_materials[i].albedo_texture = flame_frames[(frame + i * 2) % flame_frames.size()]
