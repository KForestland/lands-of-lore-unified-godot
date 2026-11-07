extends SceneTree
const Torches = preload("res://scripts/lol2/museum_torches.gd")
const Props = preload("res://scripts/lol2/museum_props.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

class Host extends Node3D:
	var feedback: Array[String] = []
	var camera: Camera3D
	var player: CharacterBody3D
	var weapon_ready: bool = false
	func save_feedback(text: String) -> void:
		feedback.append(text)
	func melee_ready() -> bool:
		return weapon_ready

func run() -> void:
	var props: Node3D = Props.new()
	root.add_child(props)
	await process_frame
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/museum_props/props.json"))
	var flat: int = 0
	var upright: int = 0
	for record in data.props:
		var flags: int = int(record.get("frame_flags", 0)) & 0xC0
		var inst: MeshInstance3D = props.get_node("MuseumProp_%d" % int(record.record))
		var mat := inst.material_override as StandardMaterial3D
		if flags & 0x80:
			flat += 1
			check(is_equal_approx(inst.rotation.x, -PI / 2.0), "dust %d lies flat" % int(record.record))
			check(mat.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED, "dust %d billboard stays off" % int(record.record))
		else:
			upright += 1
			check(is_equal_approx(inst.rotation.x, 0.0), "prop %d stays upright" % int(record.record))
			check(mat.billboard_mode == BaseMaterial3D.BILLBOARD_FIXED_Y, "prop %d keeps the fixed billboard" % int(record.record))
	check(flat == 13 and upright == 89, "13 ceiling dust quads")
	var host := Host.new()
	host.player = CharacterBody3D.new()
	host.camera = Camera3D.new()
	root.add_child(host)
	host.add_child(host.player)
	host.add_child(host.camera)
	var torches: Node = Torches.new()
	host.add_child(torches)
	var error: String = torches.setup(host, null)
	check(error.is_empty(), error)
	if error.is_empty():
		host.weapon_ready = true
		torches.state.pilot_state = 0
		check(not torches.strike_pilot(), "a strike before the plate stays dark")
		torches.state.pilot_state = 1
		var pilot: Vector3 = torches.bodies[Torches.PILOT].global_position
		host.camera.global_position = pilot + Vector3(0, 0, 40)
		host.camera.look_at(pilot, Vector3.UP)
		await physics_frame
		var before: int = torches.awards
		check(torches.strike_pilot() and torches.state.pilot_spent and torches.state.lit.size() == 35, "one strike lights the niche")
		check(torches.awards == before and torches.state.lit.size() == 35, "the torches light and the level counter stays without a magic bank")
		var messages: int = host.feedback.size()
		check(not torches.strike_pilot() and host.feedback.size() == messages, "a second strike stays spent")
	props.queue_free()
	host.queue_free()
	await process_frame
	if failures == 0: print("PASS museum niche strike and flat ceiling dust")
	quit(1 if failures else 0)
