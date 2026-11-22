extends Node3D
## Centre corridor switches on the way to the mantle bars.
## Movable 84 kind 4, while its byte +0x25 is 0, runs group 49836. That group
## stores 1 at prop 128 +0x25 and slides movables 84 and 85. Movable 85's matching
## group slides the pair and does not store that byte.
## Prop 128 kind 6 value 21 runs group 3632 when predicate 207 passes (its own
## byte +0x25 is 1). Group 3632 stores 1 at prop 127. Prop 127 kind 6 value 21
## then runs group 3600 and sets travel 100 on movables 82 and 83.
## The prop-event caller is unknown. Standing within 40 supplies caller byte 21
## and names the prop as the context. The predicate is not changed, and a byte
## that is still unknown is not written.
const REACH := 40.0
const CALLER := 21
const IDS: Array[int] = [126, 128, 127]
var host: Node3D
var fired: Dictionary = {}

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l16_centre_switches.gd").new()
	n.host = map
	n.name = "L16CentreSwitches"
	map.add_child(n)
	return n

static func relocates_player() -> bool:
	return false

func _physics_process(_delta: float) -> void:
	if host == null or host.flying or host.starting_magic == null or not host.starting_magic.world_active():
		return
	var body: Variant = host.get("player")
	if body == null or not is_instance_valid(body):
		return
	var progression: Variant = host.get("progression")
	if progression == null:
		return
	var native: Variant = progression.get("native")
	if native == null:
		return
	var origin: Vector3 = (body as Node3D).global_position
	var placements: Dictionary = native.get("placements")
	for id in IDS:
		if fired.has(id):
			continue
		var ref := "prop:%d" % id
		if int(native.call("field", ref, "byte_0x25", -1)) != 1:
			continue
		if not placements.has(ref):
			continue
		var raw: PackedByteArray = placements[ref]
		var at := Vector3(float(raw.decode_s16(0)), float(raw.decode_s16(6)), -float(raw.decode_s16(2)))
		if Vector2(origin.x - at.x, origin.z - at.z).length() > REACH:
			continue
		fired[id] = true
		var results: Array = progression.call("fire", ref, 6, {"caller_byte": CALLER, "context": ref})
		for row in results:
			if row is Dictionary:
				print("SWITCH ", id, " ", str((row as Dictionary).get("status", "")))
