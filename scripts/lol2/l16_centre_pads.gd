extends Node3D
## STORY-077 entrance. Control 80, kind 5 value 4, runs group 42152.
## Control 79, kind 5 value 4, runs group 42134. Each group is one opcode 18,
## kind 1, target 0, flags 0x0c04. The host writes the horizontal words and the
## heading. Flag 0x0100 is clear, so the height word is not written and the
## incoming height stays. Standing within 40 still poses Luther on the
## destination region's floor plus the form-0 foot offset. That snap stays
## until a walk passes with the height left as it was. The mantle group still
## does not run, and these pads do not move the mantle props.
const IN_CONTROL := 80
const OUT_CONTROL := 79
const IN_GROUP := 42152
const OUT_GROUP := 42134
const FLAGS := 0x0c04
const FOOT := 32.0
const IN_FLOOR := 0.0
const OUT_FLOOR := -40.0
const IN_AT := Vector2(-3920.0, 7760.0)
const OUT_AT := Vector2(5520.0, 5494.0)
const IN_POSE := Vector3(5517.0, IN_FLOOR + FOOT, 5640.0)
const OUT_POSE := Vector3(-3923.0, OUT_FLOOR + FOOT, 7619.0)
const REACH := 40.0
var host: Node3D
var latch := -1

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l16_centre_pads.gd").new()
	n.host = map
	n.name = "L16CentrePads"
	map.add_child(n)
	return n

static func relocates_player() -> bool:
	return false

func _flat(at: Vector2) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - at.x, p.z - at.y).length()

func _pose(control: int, pose: Vector3) -> void:
	var progression: Variant = host.get("progression")
	if progression != null and progression.has_method("use_exit"):
		progression.use_exit("control:%d" % control)
	host.player.velocity = Vector3.ZERO
	host.player.position = pose
	latch = control

func _process(_delta: float) -> void:
	if host.flying or not host.starting_magic.world_active():
		return
	var near_in: bool = _flat(IN_AT) < REACH
	var near_out: bool = _flat(OUT_AT) < REACH
	if latch == IN_CONTROL and not near_in:
		latch = -1
	elif latch == OUT_CONTROL and not near_out:
		latch = -1
	if near_in and latch != IN_CONTROL:
		_pose(IN_CONTROL, IN_POSE)
	elif near_out and latch != OUT_CONTROL:
		_pose(OUT_CONTROL, OUT_POSE)
