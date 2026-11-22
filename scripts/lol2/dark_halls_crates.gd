extends Node
## Meta duck: expose the crystals, shove the solid box, step back, Spark, and the steel door is gone.
## The same shove, taken to the seven-o'clock window, is the other way out of the halls.
## Exact: 89 template-20 crates, state 0/1/2, opcode 16, opcode 15 form 101 falloff, child 175 crystal.
## Group 8280 is one opcode 197 arm 10 on region 1413. Arm 10 marks table 0x2B53C byte +9.
## Adapters: E stands in for unhosted kind 3; the shove has no move opcode; level-three Spark is the
## hintbook gate (the kind-5 predicate is caller bytes 0005000001, not "crystals showing"); opcode 9
## arm 0x11 only sets byte +0x15 bit 0x40, so the billboard is the book's visible crystal; opcode 9
## arm 2 is the player-release adapter and does not run on a crate; no crate group names door 84, so a
## nonzero blast at that door is what runs kind-6 group 7656. Opcode 14 arm 3 starts a timer. Hiding
## the door mesh is the book's "door is gone." No crate group names window 246, so a nonzero blast
## there stores the 8280 mark and opens the route. The host does not hold table 0x2B53C.
const SOURCE := "res://scripts/lol2/dark_halls_crates_source.json"
const CRYSTAL := "res://assets/lol2/dark_halls/prop_617.png"
const DOOR := 84
const REACH := 120.0
const CAST_HINT_REACH := 768.0 # Existing level-three Spark ray; presentation only, E stays at REACH.
const FACING := 0.7
const PUSH := 8.0
const SPARK_LAYER := 2
const Rules = preload("res://scripts/lol2/dark_halls_blast_rules.gd")
const Assemblies = preload("res://scripts/lol2/static_assemblies.gd")
const FormBody = preload("res://scripts/lol2/player_form_body.gd")
const PREFIX := ["cc906800f9010300", "c5901e000000", "091056000300"]
const EXIT_WINDOW := 246
const EXIT_GROUP := "c59085050a00"
static var claim_ready := false
static var claimed: Dictionary = {}
var host: Node3D
var source: Dictionary = {}
var blast: Dictionary = {}
var centers: Dictionary = {}
var homes: Dictionary = {}
var halves: Dictionary = {}
var crate_state: Dictionary = {}
var bodies: Dictionary = {}
var visuals: Dictionary = {}
var crystals: Dictionary = {}
var door_body: StaticBody3D
var door_visual: Node3D
var door_center := Vector3.ZERO
var door_half := Vector3.ZERO
var door_state := 0
var last_damage := 0
var last_actor_damage: Dictionary = {}
var hint:Label
var decoration_faces:Array=[]
var decoration_bounds:Array[AABB]=[]
var hint_clock:=0.0
var cached_magic:Node

class Receiver:
	extends RefCounted
	var owner_node: Node
	var control: int
	func _init(node: Node, id: int) -> void:
		owner_node = node
		control = id
	func receive_spark_level(charge: int) -> bool:
		return bool(owner_node.call("on_spark", control, charge))

static func claims(id: int) -> bool:
	if not claim_ready:
		claim_ready = true
		claimed[DOOR] = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
		if parsed is Dictionary:
			var rows: Array = (parsed as Dictionary).get("crates", [])
			for row_v in rows:
				if row_v is Dictionary:
					claimed[int((row_v as Dictionary).control)] = true
	return claimed.has(id)

## Opcode 204 writes 0x22d08:505 word 3 and byte +5 bit 0x40. Opcode 197 arm 0 clears byte +0x1C
## bit 0x01 on region 30. Opcode 9 arm 3 names target 86 and stores nothing while +0x15 bit 0x10
## is unknown. Any other prefix is kept raw so it is not discarded.
static func prefix_fields(commands: Array) -> Dictionary:
	var same := commands.size() == PREFIX.size()
	for i in commands.size():
		if i >= PREFIX.size() or str(commands[i]) != str(PREFIX[i]):
			same = false
	if not same:
		var raw: Array[String] = []
		for command_v in commands:
			raw.append(str(command_v))
		return {"raw": raw}
	return {
		"opcode204_entry": 505,
		"opcode204_word0": 3,
		"opcode204_bit": 0x40,
		"region30_byte_1c_bit01": 0,
		"hole86_target": 86,
		"opcode9_arm3_stored": false,
	}

## Group 8280 is opcode 197 arm 10 on region 1413 (`c59085050a00`). Arm 10 marks table 0x2B53C byte +9.
## The host does not hold that table. The mark is the record. Opening the route is the book's broken window.
static func exit_group_fields(hex: String) -> Dictionary:
	if hex != EXIT_GROUP:
		return {}
	return {"opcode": 197, "arm": 10, "region": 1413, "list_byte_0x09": 1}

static func validate(value: Variant) -> String:
	if not value is Dictionary: return "Invalid Dark Halls crates."
	var bag: Dictionary = value
	if int(bag.get("version", -1)) != 1: return "Invalid Dark Halls crates."
	if int(bag.get("door", 0)) != 0 and int(bag.get("door", 0)) != 1: return "Invalid Dark Halls crates."
	if not bag.get("crates", {}) is Dictionary: return "Invalid Dark Halls crates."
	var rows: Dictionary = bag.crates
	for key_v in rows.keys():
		var id := int(key_v)
		if id == DOOR or not claims(id): return "Invalid Dark Halls crates."
		var row_v: Variant = rows[key_v]
		if not row_v is Dictionary: return "Invalid Dark Halls crates."
		var row: Dictionary = row_v
		if int(row.get("s", -1)) < 0 or int(row.get("s", -1)) > 2: return "Invalid Dark Halls crates."
		if row.has("x") and not _number(row.x): return "Invalid Dark Halls crates."
		if row.has("z") and not _number(row.z): return "Invalid Dark Halls crates."
	if bag.has("prefix973") and not bag.prefix973 is Dictionary: return "Invalid Dark Halls crates."
	if bag.has("blast_exit") and int(bag.blast_exit) != 0 and int(bag.blast_exit) != 1: return "Invalid Dark Halls crates."
	if bag.has("exit_group") and not bag.exit_group is Dictionary: return "Invalid Dark Halls crates."
	return ""

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func setup(walkthrough: Node3D) -> String:
	host = walkthrough
	name = "DarkHallsCrates"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not parsed is Dictionary: return "Dark Halls crate source missing."
	source = parsed
	var rows: Array = source.get("crates", [])
	if rows.size() != 89: return "Dark Halls crate count is %d." % rows.size()
	var area_v: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(host.get("geometry_file"))))
	if not area_v is Dictionary: return "Dark Halls geometry missing."
	var area: Dictionary = area_v
	var decoration_error:=_cache_decorations(area)
	if not decoration_error.is_empty():return decoration_error
	var faces := _faces(area)
	var crystal := _crystal_material()
	for row_v in rows:
		if not row_v is Dictionary: return "Dark Halls crate row missing."
		var row: Dictionary = row_v
		var id := int(row.control)
		if int(row.template) != 20: return "Dark Halls crate %d is not template 20." % id
		var bucket: Array = faces.get(id, [])
		_build_crate(id, row, bucket, area, crystal)
	if centers.size() != 89: return "Dark Halls built %d crates." % centers.size()
	if not faces.has(DOOR): return "Iron Door faces missing."
	var door_faces: Array = faces[DOOR]
	_build_door(door_faces, area)
	if host.get("player") is CollisionObject3D:
		(host.get("player") as CollisionObject3D).collision_mask |= Assemblies.SCENERY_LAYER
	hint=preload("res://scripts/lol2/interaction_hint_label.gd").attach(self,Vector2(24,455))
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	restore_from_quests()
	return ""

func _faces(area: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var face_list: Array = area.get("faces", [])
	for face_v in face_list:
		if not face_v is Dictionary: continue
		var face: Dictionary = face_v
		if str(face.get("placement_kind", "")) != "static_assembly": continue
		var id := int(face.get("source_index", -1))
		if not claims(id): continue
		if not out.has(id): out[id] = []
		var bucket: Array = out[id]
		bucket.append(face)
	return out

func _crystal_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.albedo_color = Color(0.55, 0.47, 0.40)
	if FileAccess.file_exists(CRYSTAL):
		var image := Image.load_from_file(CRYSTAL)
		if image != null and not image.is_empty():
			material.albedo_texture = ImageTexture.create_from_image(image)
	return material

func _build_crate(id: int, row: Dictionary, bucket: Array, area: Dictionary, crystal_mat: Material) -> void:
	var bounds := _bounds(bucket)
	var pos: Array = row.position
	var dim: Array = row.dimensions
	var center := Vector3(float(pos[0]), float(pos[1]) + float(dim[1]) * 0.5, float(pos[2]))
	var half := Vector3(float(dim[0]) * 0.5, float(dim[1]) * 0.5, float(dim[2]) * 0.5)
	if bounds.size != Vector3.ZERO:
		center = bounds.position + bounds.size * 0.5
		half = bounds.size * 0.5
	var visual := Node3D.new()
	visual.name = "Crate%d" % id
	add_child(visual)
	_add_meshes(visual, bucket, area)
	var spec: Dictionary = row.get("crystal", {})
	var crystal := MeshInstance3D.new()
	crystal.name = "Crystal"
	var quad := QuadMesh.new()
	quad.size = Vector2(float(spec.get("right", 7.5)) - float(spec.get("left", -7.5)), float(spec.get("top", 20.0)) - float(spec.get("bottom", 0.0)))
	quad.center_offset = Vector3(0, float(spec.get("bottom", 0.0)) + quad.size.y * 0.5, 0)
	quad.material = crystal_mat
	crystal.mesh = quad
	var cpos: Array = spec.get("position", [center.x, center.y, center.z])
	crystal.position = Vector3(float(cpos[0]), float(cpos[1]), float(cpos[2]))
	crystal.visible = false
	visual.add_child(crystal)
	var body := StaticBody3D.new()
	body.name = "CrateBody%d" % id
	body.collision_layer = Assemblies.SCENERY_LAYER | SPARK_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = half * 2.0
	shape.shape = box
	body.add_child(shape)
	body.position = center
	body.set_meta("spark_receiver", Receiver.new(self, id))
	body.set_meta("dark_halls_crate", id)
	add_child(body)
	centers[id] = center
	homes[id] = center
	halves[id] = half
	crate_state[id] = 0
	bodies[id] = body
	visuals[id] = visual
	crystals[id] = crystal

func _build_door(bucket: Array, area: Dictionary) -> void:
	var bounds := _bounds(bucket)
	door_center = bounds.position + bounds.size * 0.5
	door_half = bounds.size * 0.5
	door_visual = Node3D.new()
	door_visual.name = "IronDoor"
	add_child(door_visual)
	_add_meshes(door_visual, bucket, area)
	door_body = StaticBody3D.new()
	door_body.name = "IronDoorBody"
	door_body.collision_layer = Assemblies.SCENERY_LAYER
	door_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = door_half * 2.0
	shape.shape = box
	door_body.add_child(shape)
	door_body.position = door_center
	add_child(door_body)

func _bounds(bucket: Array) -> AABB:
	var found := false
	var box := AABB()
	for face_v in bucket:
		if not face_v is Dictionary: continue
		var face: Dictionary = face_v
		var points: Array = face.get("points", [])
		for point_v in points:
			var point: Array = point_v
			var vertex := Vector3(float(point[0]), float(point[1]), float(point[2]))
			if not found:
				box = AABB(vertex, Vector3.ZERO)
				found = true
			else:
				box = box.expand(vertex)
	return box

func _add_meshes(visual: Node3D, bucket: Array, area: Dictionary) -> void:
	var groups: Dictionary = {}
	var cutouts: Dictionary = {}
	var cut_list: Array = area.get("alpha_cutout_materials", [])
	for cut_v in cut_list:
		cutouts[str(cut_v)] = true
	var materials: Dictionary = area.get("materials", {})
	for face_v in bucket:
		if not face_v is Dictionary: continue
		var face: Dictionary = face_v
		var key := "%s|%d" % [str(face.get("material", "")), int(face.get("child_mask",0xffffffff))]
		if not groups.has(key): groups[key] = []
		var group: Array = groups[key]
		group.append(face)
	var root := str(host.get("geometry_file")).get_base_dir()
	for key_v in groups.keys():
		var group_key:=str(key_v)
		var key:=str((groups[key_v] as Array)[0].get("material", ""))
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var group: Array = groups[group_key]
		for face_v in group:
			var face: Dictionary = face_v
			var order := [0, 1, 2, 0, 2, 3]
			for i in order:
				var uv: Array = face.uv[i]
				var point: Array = face.points[i]
				surface.set_uv(Vector2(float(uv[0]), float(uv[1])))
				surface.add_vertex(Vector3(float(point[0]), float(point[1]), float(point[2])))
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.albedo_color = Color(0.55, 0.47, 0.40)
		if cutouts.has(key):
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		if materials.has(key):
			var image := Image.load_from_file(root + "/" + str(materials[key]))
			if image != null and not image.is_empty():
				material.albedo_texture = ImageTexture.create_from_image(image)
		mesh.material_override = material
		mesh.set_meta("source_child_mask",int(group[0].get("child_mask",0xffffffff)))
		visual.add_child(mesh)

func center_of(id: int) -> Vector3:
	return centers[id]

func half_of(id: int) -> Vector3:
	return halves[id]

func state_of(id: int) -> int:
	return int(crate_state.get(id, 0))

func crystal_on(id: int) -> bool:
	var mesh: MeshInstance3D = crystals[id]
	return mesh != null and mesh.visible

func door_blocking() -> bool:
	return door_state == 0 and door_body != null and door_body.collision_layer != 0

func door_center_of() -> Vector3:
	return door_center

func door_half_of() -> Vector3:
	return door_half

func aimed_id() -> int:
	return _aimed()

func on_spark(control: int, charge: int) -> bool:
	# Hintbook gate. Native kind 9 value 17 does not encode a charge, and its predicate is not "crystals showing."
	if int(crate_state.get(control, 0)) == 0:
		host.save_feedback("Press E to expose the crystals first.");return false
	if int(crate_state.get(control, 0)) != 1:return false
	if charge != 3:
		host.save_feedback("A stronger Spark is needed (1, then Control+Q)."+_blood_advice() if outside_blast(control) else _exposed_advice(control));return false
	return _detonate(control)

## Modern Dragon's Blood bridge, authorised by the owner's 17 Nov report.
## The shared bomb owns its radius/fuse/occlusion; this owner keeps native
## crate blast damage, persistence and door/window effects in one path.
func exposed_targets() -> Dictionary:
	var result:Dictionary={}
	for id in centers:
		if state_of(id)==1:result[id]={"point":centers[id],"body":bodies[id]}
	return result

func blood_targets(origin:Vector3,reach:float) -> Dictionary:
	var result:Dictionary={}
	for id in centers:
		if state_of(id)!=1:continue
		var center:Vector3=centers[id]
		var half:Vector3=halves[id]
		var near:=origin.clamp(center-half+Vector3.ONE,center+half-Vector3.ONE)
		for point in [near,center+Vector3.UP*(half.y-1),center]:
			if origin.distance_to(point)>reach:continue
			var ray:=PhysicsRayQueryParameters3D.create(origin,point,259,[host.player.get_rid()])
			ray.hit_from_inside=true
			var hit:=host.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and hit.collider==bodies[id]:
				result[id]={"point":point,"body":bodies[id]};break
	return result

## Both Spark and Blood use the same protection and health owner.
func apply_player_blast(amount:int)->void:
	var magic:Node=host.get("starting_magic")
	if amount>0 and is_instance_valid(magic) and not magic.protected():
		magic.call("set_health",maxi(0,int(magic.call("health"))-amount))

## Surface placement remains outside the collider even when its top is aimed.
func blood_placement(id:int,point:Vector3,normal:Vector3)->Vector3:
	var result:=point+normal*5.0
	if absf(normal.y)>0.5:
		var center:Vector3=centers[id]
		var half:Vector3=halves[id]
		var toward:Vector3=host.camera.global_position-center
		if absf(toward.x)/half.x>=absf(toward.z)/half.z:result.x=center.x+signf(toward.x)*(half.x+5.0)
		else:result.z=center.z+signf(toward.z)*(half.z+5.0)
	return result

func blood_player_damage(ids:Array)->int:
	var damage:=0
	for id in ids:damage=maxi(damage,Rules.damage(centers[id],host.player.global_position,_blast_source()))
	return damage

func receive_dragon_blood(id:int,damage_player:=true) -> bool:
	return _detonate(id,damage_player) if centers.has(id) and state_of(id)==1 else false

func open_crate(id: int) -> bool:
	if not centers.has(id) or int(crate_state[id]) != 0:
		return false
	crate_state[id] = 1
	var mesh: MeshInstance3D = crystals[id]
	mesh.visible = true
	_present(id)
	_remember(id)
	return true

func _detonate(id: int, damage_player:=true) -> bool:
	if int(crate_state.get(id, 0)) == 2:
		return false
	var commands: Array = []
	for row_v in source.get("crates", []):
		if row_v is Dictionary and int((row_v as Dictionary).control) == id:
			var got: Variant = (row_v as Dictionary).get("native_before_blast", [])
			if got is Array:
				commands = got
	if id == 973 and not commands.is_empty():
		_bag()["prefix973"] = prefix_fields(commands)
	var source_blast := _blast_source()
	var player_at := Vector3.ZERO
	if host.get("player") is Node3D:
		player_at = (host.get("player") as Node3D).global_position
	last_damage = Rules.damage(centers[id], player_at, source_blast)
	if damage_player:apply_player_blast(last_damage)
	var population := host.get("creatures") as Node
	last_actor_damage = population.receive_blast(centers[id], source_blast) if population != null else {}
	var at_door := Rules.damage(centers[id], door_center, source_blast)
	if at_door > 0 and door_state == 0:
		_remove_door()
	_try_exit(id, source_blast)
	crate_state[id] = 2
	var body: StaticBody3D = bodies[id]
	body.collision_layer = 0
	var visual: Node3D = visuals[id]
	visual.visible = false
	var mesh: MeshInstance3D = crystals[id]
	mesh.visible = false
	_remember(id)
	return true

## Group 7656: opcode 14 arm 3 on target 74, opcode 16 state 1, opcode 5 byte 4 = 1, opcode 9 arm 8
## clears byte +0x14 bit 0x80. The mesh hide is the hintbook result, not a decoded opcode 14 effect.
func _remove_door() -> void:
	door_state = 1
	_present_door()
	var bag := _bag()
	bag["door"] = 1
	bag["door_group"] = {"opcode14_target": 74, "opcode14_arm": 3, "opcode16": 1, "opcode5": 1, "opcode9_arm8_bit80": 0}

## No crate group names window 246. A nonzero blast at that window is what runs group 8280.
func _try_exit(id: int, source_blast: Dictionary) -> void:
	if int(_bag().get("blast_exit", 0)) == 1: return
	var windows := host.get_node_or_null("DarkHallsWindows")
	if windows == null: return
	var src_v: Variant = windows.get("source")
	if not src_v is Dictionary: return
	var exit_row: Dictionary = (src_v as Dictionary).get("exit", {})
	if int(exit_row.get("window", -1)) != EXIT_WINDOW: return
	var at_v: Variant = windows.call("exit_center")
	if not at_v is Vector3: return
	var at: Vector3 = at_v
	if Rules.damage(centers[id], at, source_blast) <= 0: return
	var bag := _bag()
	bag["blast_exit"] = 1
	bag["exit_group"] = exit_group_fields(EXIT_GROUP)
	windows.call("break_exit")

func _blast_source() -> Dictionary:
	if blast.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Rules.SOURCE))
		if parsed is Dictionary:
			blast = parsed
	return blast

func _bag() -> Dictionary:
	var quests: Dictionary = host.quest_state
	if not quests.get("dark_halls_crates") is Dictionary:
		quests["dark_halls_crates"] = {"version": 1, "crates": {}, "door": door_state}
	return quests["dark_halls_crates"]

func _remember(id: int) -> void:
	var bag := _bag()
	var rows: Dictionary = bag.crates
	var row := {"s": int(crate_state[id])}
	var now: Vector3 = centers[id]
	var home: Vector3 = homes[id]
	if now.distance_squared_to(home) > 0.01:
		row["x"] = now.x
		row["z"] = now.z
	if int(row.s) == 0 and not row.has("x"):
		rows.erase(str(id))
	else:
		rows[str(id)] = row
	bag["door"] = door_state

func restore_from_quests() -> void:
	var saved_v: Variant = host.quest_state.get("dark_halls_crates") if host != null else null
	var saved: Dictionary = saved_v if saved_v is Dictionary else {}
	door_state = int(saved.get("door", 0))
	_present_door()
	if int(saved.get("blast_exit", 0)) == 1:
		var windows := host.get_node_or_null("DarkHallsWindows")
		if windows != null: windows.call("break_exit")
	var rows: Dictionary = saved.get("crates", {})
	for id in centers:
		var row: Dictionary = rows.get(str(id), {})
		crate_state[id] = int(row.get("s", 0))
		var home: Vector3 = homes[id]
		_place(id, Vector3(float(row.get("x", home.x)), home.y, float(row.get("z", home.z))))
		_present(id)
	last_actor_damage.clear()

func _present_door() -> void:
	var up := door_state == 0
	if door_body != null:
		door_body.collision_layer = Assemblies.SCENERY_LAYER if up else 0
	if door_visual != null:
		door_visual.visible = up

func _present(id: int) -> void:
	var state := int(crate_state.get(id, 0))
	var body: StaticBody3D = bodies[id]
	body.collision_layer = 0 if state == 2 else Assemblies.SCENERY_LAYER | SPARK_LAYER
	var visual: Node3D = visuals[id]
	visual.visible = state != 2
	for part in visual.get_children():
		if part.has_meta("source_child_mask"):
			part.visible=(int(part.get_meta("source_child_mask")) & (1<<state))!=0
	var mesh: MeshInstance3D = crystals[id]
	mesh.visible = state == 1

func _aimed(include_primed:=false, reach:float=REACH, primed_only:=false) -> int:
	if host == null or not host.get("camera") is Camera3D:
		return -1
	var camera := host.get("camera") as Camera3D
	var best := -1
	var best_dot := FACING
	var space := host.get_world_3d().direct_space_state
	# Prefer the actual visible crate hit. Its centre can lie below a window
	# lip even when the original top is under the crosshair (owner slot973).
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position-camera.global_basis.z*reach, Assemblies.SCENERY_LAYER | 1)
	if host.get("player") is CollisionObject3D: ray.exclude=[host.player.get_rid()]
	var visible := space.intersect_ray(ray)
	if not visible.is_empty() and visible.collider.has_meta("dark_halls_crate"):
		var target := int(visible.collider.get_meta("dark_halls_crate"))
		if crate_state.has(target) and state_of(target)!=2 and (include_primed or state_of(target)==0) and (not primed_only or state_of(target)==1):return target
	for id_v in centers.keys():
		var id := int(id_v)
		if int(crate_state.get(id, 0)) == 2 or (not include_primed and int(crate_state.get(id,0))!=0) or (primed_only and state_of(id)!=1):
			continue
		var center: Vector3 = centers[id]
		var offset := center - camera.global_position
		if offset.length() > reach or offset.length() < 0.01:
			continue
		var dot := (-camera.global_basis.z).dot(offset.normalized())
		if dot <= best_dot or (state_of(id)==1 and dot<0.98):
			continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, center, Assemblies.SCENERY_LAYER | 1)
		if host.get("player") is CollisionObject3D:
			query.exclude = [(host.get("player") as CollisionObject3D).get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var body: StaticBody3D = bodies[id]
			if hit.collider != body and float(hit.position.distance_to(camera.global_position)) + 1.0 < offset.length():
				continue
		best_dot = dot
		best = id
	return best

func _radius() -> float:
	var form := 0
	if host != null and host.get("player_form") != null:
		form = int(host.get("player_form"))
	if form < 0 or form >= FormBody.RADII.size():
		form = 0
	return float(FormBody.RADII[form])

func _push(id: int, player_pos: Vector3) -> Vector3:
	if int(crate_state.get(id, 0)) == 2:
		return Vector3.ZERO
	var center: Vector3 = centers[id]
	var half: Vector3 = halves[id]
	var feet := player_pos.y - FormBody.FOOT_OFFSET
	if feet > center.y + half.y or feet + 64.0 < center.y - half.y:
		return Vector3.ZERO
	var away := Vector3(center.x - player_pos.x, 0, center.z - player_pos.z)
	var reach := _radius() + Vector2(half.x, half.z).length() + 1.0
	if away.length() < 0.01 or away.length() > reach:
		return Vector3.ZERO
	return away.normalized() * minf(PUSH, reach - away.length())

func _blocked(id: int, center: Vector3) -> bool:
	var half: Vector3 = halves[id]
	var box := AABB(center - half + Vector3(0.2, 0.2, 0.2), half * 2.0 - Vector3(0.4, 0.4, 0.4))
	if box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
		return true
	for other_v in centers.keys():
		var other := int(other_v)
		if other == id or int(crate_state.get(other, 0)) == 2:
			continue
		var oh: Vector3 = halves[other]
		var other_center: Vector3 = centers[other]
		if box.intersects(AABB(other_center - oh, oh * 2.0)):
			return true
	if door_state == 0 and box.intersects(AABB(door_center - door_half, door_half * 2.0)):
		return true
	return false

func _place(id: int, center: Vector3) -> void:
	var delta := center - (homes[id] as Vector3)
	centers[id] = center
	var body: StaticBody3D = bodies[id]
	body.position = center
	var visual: Node3D = visuals[id]
	visual.position = delta

func _physics_process(_delta: float) -> void:
	if host == null or not host.get("player") is Node3D:
		return
	var player_pos := (host.get("player") as Node3D).global_position
	var moves: Dictionary = {}
	for id_v in centers.keys():
		var id := int(id_v)
		var push := _push(id, player_pos)
		if push.length_squared() < 0.0001:
			continue
		var step := push
		var accepted := Vector3.ZERO
		var guard := 0
		while step.length() >= 0.25 and guard < 5:
			guard += 1
			if not _blocked(id, (centers[id] as Vector3) + step):
				accepted = step
				break
			step *= 0.5
		if accepted.length_squared() > 0.0:
			moves[id] = (centers[id] as Vector3) + accepted
	for id_v in moves.keys():
		var id := int(id_v)
		_place(id, moves[id])
		_remember(id)

static func decoration_data(path:String)->Dictionary:
	if not FileAccess.file_exists(path):return {"error":"Dark Halls decoration collision data is missing."}
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("boxes") is Dictionary:return {"error":"Dark Halls decoration collision data is invalid."}
	for row in parsed.boxes.values():
		if not row is Dictionary:return {"error":"Dark Halls decoration collision row is invalid."}
	return {"error":"","boxes":parsed.boxes}

func _cache_decorations(area:Dictionary)->String:
	var collision:=decoration_data("res://scripts/lol2/static_collision_L7_DH.json")
	if not collision.error.is_empty():return collision.error
	var bounds:Dictionary={}
	decoration_faces.clear();decoration_bounds.clear()
	var ids:Dictionary={}
	for id in collision.get("boxes",{}):
		if int(collision.boxes[id].get("template",-1))==21:ids[int(id)]=true
	for face in area.get("faces",[]):
		if str(face.get("placement_kind",""))=="static_assembly" and ids.has(int(face.get("source_index",-1))) and (int(face.get("child_mask",0xffffffff))&1)!=0:
			var points:Array=face.get("points",[])
			if points.size()==4:
				var verts:Array=[]
				for p in points:verts.append(Vector3(p[0],p[1],p[2]))
				decoration_faces.append(verts)
				var id:=int(face.source_index)
				var box:AABB=bounds.get(id,AABB(verts[0],Vector3.ZERO))
				for vertex:Vector3 in verts:box=box.expand(vertex)
				bounds[id]=box
	for box:AABB in bounds.values():decoration_bounds.append(box)
	return ""

func _decoration_aimed()->bool:
	var camera:Camera3D=host.camera
	var start:=camera.global_position
	var nearby:=false
	for box:AABB in decoration_bounds:
		if start.distance_squared_to(start.clamp(box.position,box.end))<=REACH*REACH:nearby=true;break
	if not nearby:return false
	var direction:Vector3=-camera.global_basis.z
	var nearest:=REACH+1.0
	for points in decoration_faces:
		for tri in [[0,1,2],[0,2,3]]:
			var hit:Variant=Geometry3D.ray_intersects_triangle(start,direction,points[tri[0]],points[tri[1]],points[tri[2]])
			if hit is Vector3:nearest=minf(nearest,start.distance_to(hit))
	if nearest>REACH:return false
	var query:=PhysicsRayQueryParameters3D.create(start,start+direction*nearest,259,[host.player.get_rid()])
	var blocker:=host.get_world_3d().direct_space_state.intersect_ray(query)
	return blocker.is_empty() or start.distance_to(blocker.position)+1.0>=nearest

func _has_blood()->bool:
	var pack:Variant=host.get("carried_collected")
	if not pack is Array:return false
	for id in pack:
		if id in preload("res://scripts/lol2/dragon_blood_state.gd").ITEMS:return true
	return false

func _blood_advice()->String:
	return " Or place Dragon's Blood near the exposed crystals and run." if _has_blood() else ""

func outside_blast(id:int)->bool:
	if not centers.has(id):return false
	var source:Dictionary=_blast_source()
	if not source.has("radius"):return false
	var center:Vector3=centers[id]
	var player:Vector3=host.player.global_position
	var distance:int=Rules.distance_fixed(Vector2(center.x,center.z),Vector2(player.x,player.z))
	return distance >= (int(source.radius) << 16)

static func slot_blast_advice(damage:int,health:int)->String:
	var cost:="Spark from here would kill you." if damage>=health else "Spark from here costs about %d health."%damage
	return "The blast reaches you here. Dragon's Blood through the slot gives you time to get clear; "+cost

func _exposed_advice(id:int)->String:
	if not outside_blast(id):
		# Owner973's slot has no proven safe aimed retreat. Blast damage ignores
		# that wall; do not pretend it shelters the player or invite a hurtful cast.
		if id==973:return slot_blast_advice(Rules.damage(centers[id],host.player.global_position,_blast_source()),host.starting_magic.health())
		return "Too close - step further back."
	return "The crystals are exposed. Spark (1, then Control+Q)."+_blood_advice()+" Push the crate if it needs moving."


func _unhandled_input(event: InputEvent) -> void:
	if (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless") or get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		var id := _aimed(true)
		if id>=0:
			if open_crate(id):
				host.save_feedback(_exposed_advice(id))
				get_viewport().set_input_as_handled()
			else:host.save_feedback(_exposed_advice(id)) # Echo must not consume another target's E.
		elif _decoration_aimed():
			host.save_feedback("This crate holds no crystals.") # Inspection must also pass E onward.

func _process(delta:float)->void:
	if not is_instance_valid(hint):return
	hint.size.x=maxf(1.0,get_viewport().get_visible_rect().size.x-48.0)
	hint_clock-=delta
	if hint_clock>0:return
	hint_clock=0.1
	if not is_instance_valid(cached_magic):cached_magic=host.get("starting_magic")
	hint.text=""
	if not is_instance_valid(cached_magic) or not cached_magic.world_active():return
	var nearby:=false
	for id in centers:
		if state_of(id)!=2 and host.camera.global_position.distance_squared_to(centers[id])<pow((CAST_HINT_REACH if state_of(id)==1 else REACH)+(halves[id] as Vector3).length(),2):nearby=true;break
	if not nearby and decoration_faces.is_empty():return
	var id:int=_aimed(true) if nearby else -1
	if id<0 and nearby:id=_aimed(true,CAST_HINT_REACH,true)
	hint.text="E — Expose the crystals" if id>=0 and state_of(id)==0 else (("Spark (1, then Control+Q)"+("; or place Dragon's Blood and run" if _has_blood() else "")) if outside_blast(id) else _exposed_advice(id)) if id>=0 else "E — Inspect crate" if _decoration_aimed() else ""
