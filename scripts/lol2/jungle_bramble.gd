extends Node3D
const PlayerCombat=preload("res://scripts/lol2/player_combat.gd")
## Jungle bramble walls (L4_HJ controls 101-109, template 10, flags 0x4481).
## The solid bit 0x80 is set, and the assemblies are scripted, so the generic builder
## drew them and left them walk-through. Spark (kind 9 mask 0x0091/0x0003, context 1/1)
## clears that bit, selector 4, owner state 5, and it stays open. A sword (mask
## 0x080E/0x0004, context 2/4) walks states 0, 1, 2; the third cut clears the bit
## (selector 3, state 3). Timer 0, flag 0x10 at 60 ticks/s, then sets the bit again
## (selector 5, state 4). Mode-4 threshold is byte +8 = 5. Placement durability is
## 5 on 109 and 6 on the others. Selector 5 is the open frame. Kind 6 caller 2,
## predicated on state 4, then writes selector 0 and state 0 and leaves the solid
## bit set. Selector 0 is the full roots, so the box comes back with the picture.
## Unread, so not played: mask 0x0200 touch damage (opcode 19), opcode 14 arm 5,
## control 109's extra kind-6 callers 0x14 and 9, opcode 7 in the regrow group,
## opcode 20, and any other effect of flag 0x4000. Who pushes caller byte 2 was
## not traced; the group is the only write back to selector 0.
const Forms := preload("res://scripts/lol2/player_form_rules.gd")
const Assemblies := preload("res://scripts/lol2/static_assemblies.gd")
const IDS: Array[int] = [101, 102, 103, 104, 105, 106, 107, 108, 109]
const THRESHOLD := 5
const TICKS := 60.0
const REACH := 140.0
const SPARK_MASK0 := 0x0091
const SPARK_MASK2 := 0x0003
const CUT_MASK0 := 0x080E
const CUT_MASK2 := 0x0004
const INDEXES: Array[int] = [0, 1, 2]

var host: Node3D
var walls: Dictionary = {}
var hit_bodies: Dictionary = {}

class HitReceiver:
	var wall: Node3D
	var id: int
	func receive_spark() -> bool:
		return bool(wall.call("receive_spark_hit", id, 1))
	func receive_spark_level(level: int) -> bool:
		return bool(wall.call("receive_spark_hit", id, level))

static func durability_of(id: int) -> int:
	return 5 if id == 109 else 6

static func timer_of(id: int, index: int) -> int:
	var table: Dictionary = {
		101: [480, 420, 600],
		102: [540, 300, 360],
		103: [600, 480, 360],
		104: [480, 540, 360],
		105: [300, 600, 300],
		106: [360, 420, 420],
		107: [600, 600, 480],
		108: [540, 360, 540],
		109: [540, 600, 480],
	}
	var row: Array = table[id]
	return int(row[index])

func initial() -> Dictionary:
	var packet := {"version": 1, "walls": {}}
	for id in IDS:
		packet["walls"][str(id)] = _fresh(id)
	return packet

func _fresh(id: int) -> Dictionary:
	return {
		"state": 0, "selector": 0, "durability": durability_of(id),
		"solid": true, "flag_4000": true, "timers": [0.0, 0.0, 0.0],
	}

func checkpoint() -> Dictionary:
	return {"version": 1, "walls": walls.duplicate(true)}

static func validate(saved: Variant) -> String:
	if not saved is Dictionary or int(saved.get("version", 0)) != 1: return "Invalid bramble packet."
	var rows: Variant = saved.get("walls", null)
	if not rows is Dictionary or (rows as Dictionary).size() != IDS.size(): return "Invalid bramble walls."
	for id in IDS:
		var row: Variant = (rows as Dictionary).get(str(id), null)
		if not row is Dictionary: return "Invalid bramble wall %d." % id
		var state := int(row.get("state", -1))
		var selector := int(row.get("selector", -1))
		if state < 0 or state > 5 or selector < 0 or selector > 5: return "Invalid bramble wall %d." % id
		if not row.get("solid") is bool or not row.get("flag_4000") is bool: return "Invalid bramble wall %d." % id
		var open := state == 3 or state == 5
		if bool(row["solid"]) == open or bool(row["flag_4000"]) == open: return "Invalid bramble wall %d." % id
		var expect := 0
		if state == 3: expect = 3
		elif state == 5: expect = 4
		elif state == 4: expect = 5
		else: expect = state
		if selector != expect: return "Invalid bramble wall %d." % id
		var durability := int(row.get("durability", -1))
		if durability < 0 or durability > durability_of(id): return "Invalid bramble wall %d." % id
		var timers: Variant = row.get("timers", null)
		if not timers is Array or (timers as Array).size() != 3: return "Invalid bramble wall %d." % id
		for index in INDEXES:
			var left := float((timers as Array)[index])
			if left < 0.0 or left > float(timer_of(id, index)) + 0.01: return "Invalid bramble wall %d." % id
		var running := -1
		for index in INDEXES:
			if float((timers as Array)[index]) > 0.0:
				if running >= 0: return "Invalid bramble wall %d." % id
				running = index
		var want := -1
		if state == 1: want = 1
		elif state == 2: want = 2
		elif state == 3: want = 0
		if running != want: return "Invalid bramble wall %d." % id
	return ""

func setup(owner_host: Node3D, saved: Variant = null) -> String:
	host = owner_host
	var assemblies: Node3D = host.static_assemblies
	var ids: Array = []
	for id in IDS:
		ids.append(id)
	var solid_error: String = assemblies.add_scripted_solids("L4_HJ", ids)
	if not solid_error.is_empty(): return solid_error
	for id in IDS:
		var solid: StaticBody3D = assemblies.solid_bodies[id]
		var source_shape := solid.get_child(0) as CollisionShape3D
		var source_box := source_shape.shape as BoxShape3D
		var body := StaticBody3D.new()
		body.name = "BrambleHit%d" % id
		body.collision_layer = 2
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = source_box.size
		shape.shape = box
		body.add_child(shape)
		var receiver := HitReceiver.new()
		receiver.wall = self
		receiver.id = id
		body.set_meta("spark_receiver", receiver)
		add_child(body)
		body.global_transform = solid.global_transform
		# Jungle creatures share layer 2 with Spark receivers. The player must not walk into the aim box.
		if host.get("player") is CollisionObject3D:
			(host.player as CollisionObject3D).add_collision_exception_with(body)
		hit_bodies[id] = body
	return restore(saved)

func restore(saved: Variant) -> String:
	var packet: Variant = initial() if saved == null else saved
	var error := validate(packet)
	if not error.is_empty(): return error
	walls = (packet as Dictionary)["walls"].duplicate(true)
	for id in IDS:
		var row: Dictionary = walls[str(id)]
		if int(row["state"]) == 4:
			_show_regrown(row)
	_present(true)
	return ""

func _physics_process(delta: float) -> void:
	if _active(): advance(delta)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	var ticks := delta * TICKS
	for id in IDS:
		var row: Dictionary = walls[str(id)]
		var timers: Array = row["timers"]
		for index in INDEXES:
			if float(timers[index]) <= 0.0: continue
			var left: float = float(timers[index]) - ticks
			timers[index] = 0.0 if left <= 0.0 else left
			if left <= 0.0: _expire(id, index)
	_present(false)

func _expire(id: int, index: int) -> void:
	var row: Dictionary = walls[str(id)]
	var state := int(row["state"])
	if index == 0 and state == 3:
		# Timer group: opcode 9 arm 7 sets the solid bit, arm 0x11 sets flag 0x4000,
		# opcode 16 stores 4, opcode 5 stores selector 5. Selector 5 draws the open frame.
		# Kind 6 caller 2 (predicate owner state 4) then stores selector 0 and state 0.
		row["solid"] = true
		row["flag_4000"] = true
		_show_regrown(row)
	elif index == 1 and state == 1:
		row["state"] = 0
		row["selector"] = 0
	elif index == 2 and state == 2:
		row["state"] = 1
		row["selector"] = 1
		(row["timers"] as Array)[1] = float(timer_of(id, 1))

func receive_spark_hit(id: int, level: int) -> bool:
	var damage := 16 if level == 3 else 8
	return receive_hit(id, SPARK_MASK0, SPARK_MASK2, damage)

func strike() -> bool:
	if not _active(): return false
	if not PlayerCombat.may_strike(host,false): return false
	var id := aimed_id()
	if id < 0: return false
	var damage: int = PlayerCombat.damage(host,false)
	return receive_hit(id, CUT_MASK0, CUT_MASK2, damage)

func receive_hit(id: int, mask0: int, mask2: int, damage: int) -> bool:
	if damage <= 0 or not walls.has(str(id)): return false
	var spark := (mask0 & SPARK_MASK0) != 0 and (mask2 & SPARK_MASK2) != 0
	var cut := (mask0 & CUT_MASK0) != 0 and (mask2 & CUT_MASK2) != 0
	if not spark and not cut: return false
	var row: Dictionary = walls[str(id)]
	var after: int = maxi(0, int(row["durability"]) - damage)
	row["durability"] = after
	if after > THRESHOLD:
		return true
	if spark:
		row["state"] = 5
		row["selector"] = 4
		row["solid"] = false
		row["flag_4000"] = false
		row["timers"] = [0.0, 0.0, 0.0]
	elif cut:
		var state := int(row["state"])
		var timers: Array = row["timers"]
		if state == 0:
			row["state"] = 1
			row["selector"] = 1
			timers[1] = float(timer_of(id, 1))
		elif state == 1:
			row["state"] = 2
			row["selector"] = 2
			timers[1] = 0.0
			timers[2] = float(timer_of(id, 2))
		elif state == 2:
			row["state"] = 3
			row["selector"] = 3
			row["solid"] = false
			row["flag_4000"] = false
			timers[0] = float(timer_of(id, 0))
			timers[1] = 0.0
			timers[2] = 0.0
		else:
			return true
	_present(false)
	return true

func aimed_id() -> int:
	if not _active(): return -1
	var eye: Vector3 = host.camera.global_position
	var ray := PhysicsRayQueryParameters3D.create(eye, eye - host.camera.global_basis.z * REACH, 2, [host.player.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty(): return -1
	for id in IDS:
		if hit.collider == hit_bodies[id]: return id
	return -1

func solid(id: int) -> bool:
	return bool((walls[str(id)] as Dictionary)["solid"])

func owner_state(id: int) -> int:
	return int((walls[str(id)] as Dictionary)["state"])

func selector(id: int) -> int:
	return int((walls[str(id)] as Dictionary)["selector"])

func _show_regrown(row: Dictionary) -> void:
	row["state"] = 0
	row["selector"] = 0

func _present(force: bool) -> void:
	var assemblies: Node3D = host.static_assemblies
	for id in IDS:
		var row: Dictionary = walls[str(id)]
		var body: StaticBody3D = assemblies.solid_bodies[id]
		var open: bool = not bool(row["solid"])
		body.collision_layer = 0 if open else Assemblies.SCENERY_LAYER
		body.process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
		var shown := int(assemblies.modes.get(id, 0))
		var selector := int(row["selector"])
		if force or shown != selector or (selector != 0 and not assemblies.modes.has(id)):
			if selector != 0 or assemblies.modes.has(id):
				assemblies.set_mode(id, selector)

func _active() -> bool:
	if not is_instance_valid(host) or host.get_tree().paused: return false
	if host.get("starting_magic") != null and is_instance_valid(host.starting_magic):
		return host.starting_magic.world_active()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and strike():
		get_viewport().set_input_as_handled()
