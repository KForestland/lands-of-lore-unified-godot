extends Node3D
## STORY-008. Template 23 Bone Braziers (47 props). Each kind-9 record is mask0 0x0051,
## mask2 0, byte +8 = 1, byte +9 = 0x84 (mode 4, one-shot). Placement durability is 1,
## so a hit that leaves remaining <= 1 is admitted. Spark word0 0x0091 shares bits with
## 0x0051. The sword word0 0x080E shares none. Opcode 5 then stores prop byte +0x30 = 1,
## the lit selector. Opcode 6 arm 1 is not replayed. E inside reach 140 is the older
## adapter and still lights one. A lit basket adds a warm pool; the native light-record
## list was not read, so the colour and the range are a presentation adapter.
const KEY:="l10_braziers"
const MASK0:=0x0051
const SPARK_WORD0:=0x0091
const CUT_WORD0:=0x080E
const THRESHOLD:=1
const REACH:=140.0
const SPARK_REACH:=384.0
const NOTE_REACH:=500.0
const LIGHT_RANGE:=640.0
const LIGHT_CAP:=16
const LIGHT_RGB:=Vector3(1.0,0.62,0.28)
const Night=preload("res://scripts/lol2/l8_night.gd")
var host: Node3D
var flames: Dictionary={}
var aims: Dictionary={}
var bodies: Dictionary={}
var frames: Array[Texture2D]=[]
var material: StandardMaterial3D
var hint: Label
var elapsed:=0.0
var light_sig:=""
static func initial()->Dictionary:return {"version":1,"lit":[]}
static func valid_id(id: Variant)->bool:
	if not id is String or not id.is_valid_int() or id!=str(int(id)):return false
	var n:=int(id)
	return n==153 or (n>=200 and n<=241) or (n>=336 and n<=339)
static func admits(word0: int, remaining: int)->bool:
	if (MASK0 & word0)==0:return false
	if THRESHOLD<remaining:return false
	return true
static func validate(state: Variant)->String:
	if not state is Dictionary or state.size()!=2 or state.get("version")!=1 or not state.get("lit") is Array:return "Invalid Cemetery brazier state."
	var seen:={}
	for id in state.lit:
		if not valid_id(id) or seen.has(id):return "Invalid or duplicate Cemetery brazier."
		seen[id]=true
	return ""
static func attach(map: Node3D)->Node3D:
	var node=load("res://scripts/lol2/l10_braziers.gd").new()
	node.host=map;node.name="L10Braziers";map.add_child(node);return node
func _ready():
	var pack: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
	for path in pack.animations.prop_219.frames:
		frames.append(ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir()+"/"+path)))
	material=StandardMaterial3D.new();material.albedo_texture=frames[0]
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for row in pack.props:
		if row.get("template")!=23 or not row.has("record"):continue
		var id:=str(int(row.record))
		assert(valid_id(id))
		var node:=MeshInstance3D.new();var quad:=QuadMesh.new()
		quad.size=Vector2(64,86);quad.center_offset=Vector3(0,43,0);node.mesh=quad
		node.material_override=material;node.position=Vector3(row.position[0],row.position[1],row.position[2])
		add_child(node);flames[id]=node;aims[id]=node.position+Vector3.UP*43
		_hit_body(id)
	var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas)
	hint=Label.new();hint.position=Vector2(24,420);canvas.add_child(hint)
	restore()
func _hit_body(id: String)->void:
	var body:=StaticBody3D.new()
	body.name="BrazierHit"+id
	body.collision_layer=2
	body.collision_mask=0
	body.position=aims[id]
	body.set_meta("spark_receiver",SparkTarget.new(self,id))
	var shape:=BoxShape3D.new()
	shape.size=Vector3(48,86,48)
	var holder:=CollisionShape3D.new()
	holder.shape=shape
	body.add_child(holder)
	add_child(body)
	bodies[id]=body
	var player: Node=host.get("player")
	if player is CollisionObject3D:
		(player as CollisionObject3D).add_collision_exception_with(body)
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func lit(id: String)->bool:return id in state().lit
func restore():
	for id in flames:
		flames[id].visible=lit(id)
		var entry: Array=host.prop_placements[int(id)]
		entry[0].set_instance_transform(entry[1],Transform3D(Basis().scaled(Vector3.ZERO) if lit(id) else Basis(),entry[2]))
func _aimed(id: String, reach: float)->bool:
	if not aims.has(id):return false
	var delta: Vector3=aims[id]-host.camera.global_position
	if delta.length()>reach or delta.length()<0.01:return false
	return (-host.camera.global_basis.z).dot(delta.normalized())>=0.8
func reachable(id: String)->bool:
	if not _aimed(id,REACH):return false
	var ray=PhysicsRayQueryParameters3D.create(host.camera.global_position,aims[id],1,[host.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func spark_aimed(id: String)->bool:
	return _aimed(id,SPARK_REACH)
func near_unlit(from: Vector3)->bool:
	for id in flames:
		if lit(id):continue
		var flat: Vector3=aims[id]-from
		flat.y=0.0
		if flat.length()<=NOTE_REACH:return true
	return false
func commit(id: String)->Dictionary:
	if get_tree().paused or host.flying:return {"ok":false,"reason":"Return to the world first."}
	if not aims.has(id):return {"ok":false,"reason":"Approach and face the brazier."}
	if lit(id):return {"ok":false,"reason":"The brazier is already alight."}
	var next: Dictionary=state().duplicate(true)
	next.lit.append(id)
	host.quest_state[KEY]=next
	restore()
	refresh_lights()
	return {"ok":true}
func ignite(id: String)->Dictionary:
	if not reachable(id):return {"ok":false,"reason":"Approach and face the brazier."}
	return commit(id)
func receive_hit(id: String, word0: int, remaining: int)->Dictionary:
	if not admits(word0,remaining):return {"ok":false,"reason":"The sword leaves the brazier cold."}
	var result: Dictionary=commit(id)
	if result.ok and host.has_method("save_feedback"):host.save_feedback("The brazier catches fire.")
	return result
func receive_spark(id: String)->bool:
	return bool(receive_hit(id,SPARK_WORD0,0).ok)
func target()->String:
	for id in flames:
		if not lit(id) and reachable(id):return id
	return ""
func spark_clear(id: String)->bool:
	if not aims.has(id) or not bodies.has(id):return false
	var cam: Variant=host.get("camera")
	if not cam is Camera3D:return false
	var camera:=cam as Camera3D
	var origin: Vector3=camera.global_position
	var aim: Vector3=aims[id]
	if origin.distance_to(aim)<0.01:return false
	var player: Variant=host.get("player")
	var exclude: Array[RID]=[]
	if player is CollisionObject3D:exclude.append((player as CollisionObject3D).get_rid())
	var query:=PhysicsRayQueryParameters3D.create(origin,aim,3,exclude)
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():return false
	return hit.collider==bodies[id]
func _spark_mana()->bool:
	var magic: Variant=host.get("starting_magic")
	if magic==null or not magic is Object:return false
	var node:=magic as Object
	if not is_instance_valid(node) or not node.has_method("magic_state"):return false
	var saved: Variant=node.call("magic_state")
	if not saved is Dictionary:return false
	var stats: Variant=(saved as Dictionary).get("player",{})
	if not stats is Dictionary:return false
	return int((stats as Dictionary).get("mana",0))>=1
func spark_target()->String:
	if not _spark_mana():return ""
	for id in flames:
		var key:=str(id)
		if not lit(key) and spark_aimed(key) and spark_clear(key):return key
	return ""
func nearest_lit(from: Vector3)->Array[String]:
	var ids: Array[String]=[]
	var dist: Array[float]=[]
	for id in flames:
		var key:=str(id)
		if not lit(key):continue
		var gap: float=from.distance_squared_to(aims[key])
		var at:=ids.size()
		for i in ids.size():
			if gap<dist[i]:
				at=i
				break
		ids.insert(at,key)
		dist.insert(at,gap)
	if ids.size()>LIGHT_CAP:ids.resize(LIGHT_CAP)
	return ids
func refresh_lights()->void:
	var lighting: Node=host.get("sector_lighting") as Node
	if lighting==null or not is_instance_valid(lighting):return
	var raw: Variant=lighting.get("materials")
	if not raw is Array:return
	var mats: Array=raw
	var from:=Vector3.ZERO
	var camera: Node=host.get("camera") as Node
	if camera is Node3D:from=(camera as Node3D).global_position
	var chosen: Array[String]=nearest_lit(from)
	var positions:=PackedVector3Array()
	var colors: Array[Vector4]=[]
	var sig:=str(mats.size())
	for id in chosen:
		positions.append(aims[id])
		colors.append(Vector4(LIGHT_RGB.x,LIGHT_RGB.y,LIGHT_RGB.z,LIGHT_RANGE))
		sig+="|"+id
	if sig==light_sig:return
	light_sig=sig
	Night.apply_lights(mats,positions,colors)
func _process(delta):
	elapsed+=delta;material.albedo_texture=frames[int(elapsed*10)%frames.size()]
	restore();refresh_lights();hint.text=""
	if get_tree().paused or host.flying:return
	var e_line:=not target().is_empty()
	var spark_line:=not spark_target().is_empty()
	if e_line and spark_line:hint.text="E — Light brazier\nSpark — Light brazier"
	elif e_line:hint.text="E — Light brazier"
	elif spark_line:hint.text="Spark — Light brazier"
func _unhandled_input(event: InputEvent):
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
	if get_tree().paused or host.flying or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory):return
	if host.has_method("actor_input_locked") and host.actor_input_locked():return
	var id:=target()
	if id.is_empty():return
	var result:=ignite(id)
	host.save_feedback("The brazier catches fire." if result.ok else result.reason)
	get_viewport().set_input_as_handled()
class SparkTarget extends RefCounted:
	var owner_node: Node
	var id: String
	func _init(node: Node, prop_id: String)->void:
		owner_node=node
		id=prop_id
	func receive_spark()->bool:
		return bool(owner_node.call("receive_spark",id))
	func receive_spark_level(_level: int)->bool:
		return bool(owner_node.call("receive_spark",id))
