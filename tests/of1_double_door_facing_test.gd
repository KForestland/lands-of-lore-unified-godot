extends SceneTree
## OF1. Surface byte +6 bit 0x40 is the horizontal mirror. The bake mirrored box face 3
## on every leaf. Draracle template 11 (leaf 74) and village template 6 (leaf 78) put
## that bit on face 2. From each reported stand the near face of that leaf follows the
## flag, and the paired leaf stays.
const Door = preload("res://scripts/lol2/cave_draracle_door.gd")
const Gate = preload("res://scripts/lol2/jungle_village_gate.gd")
var failures := 0
var door: Node3D
var host: Node3D

class Host:
	extends Node3D
	var quest_state: Dictionary = {}
	var player: Node = null
	var flying: bool = false
	var health: int = 30

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL door facing: ", label)
	return ok

## The Draracle door is built off the tree. Leaving that node alive keeps its script in use at exit.
func release() -> void:
	if is_instance_valid(door):
		door.free()
	door = null
	if is_instance_valid(host):
		host.free()
	host = null
	await process_frame

func _initialize() -> void:
	run.call_deferred()

## 1 when texture u increases toward screen right on the near face, 0 when it decreases, -1 when the edge was not read.
func u_rises_right(mesh: ArrayMesh, camera: Vector3, right: Vector3) -> int:
	var pts: Array[Vector3] = []
	var us: Array[float] = []
	for surface_index in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for i in verts.size():
			var p: Vector3 = verts[i]
			var seen := false
			for j in pts.size():
				if pts[j].distance_squared_to(p) < 0.04:
					seen = true
					break
			if seen:
				continue
			pts.append(p)
			us.append(uvs[i].x)
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var ext: Vector3 = hi - lo
	var axis := 0
	if ext.y <= ext.x and ext.y <= ext.z:
		axis = 1
	elif ext.z <= ext.x and ext.z <= ext.y:
		axis = 2
	var mid := (lo[axis] + hi[axis]) * 0.5
	var near_sign := 1.0 if camera[axis] > mid else -1.0
	var max_y := -INF
	for j in pts.size():
		if (pts[j][axis] - mid) * near_sign <= 0.0:
			continue
		if pts[j].y > max_y:
			max_y = pts[j].y
	var pa := Vector3.ZERO
	var pb := Vector3.ZERO
	var ua := 0.0
	var ub := 0.0
	var count := 0
	for j in pts.size():
		if (pts[j][axis] - mid) * near_sign <= 0.0:
			continue
		if absf(pts[j].y - max_y) > 1.0:
			continue
		if count == 0:
			pa = pts[j]
			ua = us[j]
			count = 1
		elif pts[j].distance_squared_to(pa) > 0.04:
			pb = pts[j]
			ub = us[j]
			count = 2
			break
	if count != 2:
		return -1
	var rises: bool = ua > ub + 0.2 if right.dot(pa) > right.dot(pb) else ub > ua + 0.2
	return 1 if rises else 0

func run() -> void:
	door = Door.new()
	var src: Dictionary = Door.source()
	var cave_yaw := -0.034537598490715
	var cave_right := Vector3(cos(cave_yaw), 0.0, -sin(cave_yaw))
	var cave_cam := Vector3(-57.9715843200684, -251.44384765625, -17637.56640625)
	var left_mesh: ArrayMesh = door._mesh_from(src.leaves["74"].closed, Vector3.ZERO)
	var right_mesh: ArrayMesh = door._mesh_from(src.leaves["77"].closed, Vector3.ZERO)
	if not check(u_rises_right(left_mesh, cave_cam, cave_right) == 1, "Draracle left leaf 74 near face points right"):
		await release()
		quit(1)
		return
	if not check(u_rises_right(right_mesh, cave_cam, cave_right) == 0, "Draracle right leaf 77 keeps its flag"):
		await release()
		quit(1)
		return
	host = Host.new()
	root.add_child(host)
	var gate: Node3D = Gate.new()
	host.add_child(gate)
	await process_frame
	gate.set_physics_process(false)
	if not check(gate.get("available") == true and int(gate.get("pose")) == 0, "village gate closed at pose 0"):
		await release()
		quit(1)
		return
	var raw_leaves: Variant = gate.get("leaves")
	if not check(raw_leaves is Array, "village gate leaves"):
		await release()
		quit(1)
		return
	var mesh78: ArrayMesh = null
	var mesh79: ArrayMesh = null
	for body_v in raw_leaves:
		var body: StaticBody3D = body_v as StaticBody3D
		var id: int = int(body.get_meta("source_movable"))
		var mesh: ArrayMesh = (body.get_child(0) as MeshInstance3D).mesh as ArrayMesh
		if id == 78:
			mesh78 = mesh
		elif id == 79:
			mesh79 = mesh
	var gate_yaw := 1.55038869380951
	var gate_right := Vector3(cos(gate_yaw), 0.0, -sin(gate_yaw))
	var gate_cam := Vector3(-1270.47192382812, 42.047492980957, -5248.58837890625)
	if not check(mesh78 != null and u_rises_right(mesh78, gate_cam, gate_right) == 1, "village leaf 78 near face follows its flag"):
		await release()
		quit(1)
		return
	if not check(mesh79 != null and u_rises_right(mesh79, gate_cam, gate_right) == 0, "village leaf 79 keeps its flag"):
		await release()
		quit(1)
		return
	print("PASS double doors: Draracle leaf 74 and village leaf 78 follow surface byte +6, the matching leaves stay")
	await release()
	quit(0)
