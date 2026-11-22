extends Node3D
## Generic native use/step owners. The VM owns predicates, enqueues and saved
## fields; this bridge supplies player input and source-shaped hit testing.
const WorldInput = preload("res://scripts/lol2/world_input.gd")
const Body = preload("res://scripts/lol2/player_form_body.gd")
const RESTORE_ON := ["load", "arrival"]
const REACH := 256.0
const ROWS := {"L13_RC": [
	{"ref": "prop:192", "event": 4, "record": 192, "label": "Use switch", "feedback": "The switch starts the mechanism.", "input": {"arg_c": 0, "context": "prop:192"}},
	{"ref": "prop:193", "bridge_switch": true, "native_adapters": ["opcode14_arm5_noop"], "event": 4, "record": 193, "label": "Use switch", "feedback": "The switch starts the mechanism.", "input": {"arg_c": 0, "context": "prop:193"}},
	{"ref": "prop:243", "event": 4, "record": 243, "label": "Use vault switch", "feedback": "The switch starts the mechanism.", "input": {"arg_c": 0, "context": "prop:243"}},
	{"ref": "prop:244", "event": 4, "record": 244, "label": "Use vault switch", "feedback": "The switch starts the mechanism.", "input": {"arg_c": 0, "context": "prop:244"}},
	{"ref": "prop:245", "event": 4, "record": 245, "label": "Use vault switch", "feedback": "The switch starts the mechanism.", "input": {"arg_c": 0, "context": "prop:245"}},
	{"ref": "prop:246", "event": 4, "record": 246, "label": "Use vault switch", "feedback": "The switch starts the mechanism.", "input": {"arg_c": 0, "context": "prop:246"}},
	{"ref": "prop:247", "event": 4, "record": 247, "label": "Use vault switch", "feedback": "The switch starts the mechanism.", "input": {"arg_c": 0, "context": "prop:247"}},
	{"ref": "prop:248", "event": 4, "record": 248, "label": "Use vault switch", "feedback": "The switch starts the mechanism.", "input": {"arg_c": 0, "context": "prop:248"}},
	{"ref": "prop:249", "event": 4, "record": 249, "label": "Use vault switch", "feedback": "The switch starts the mechanism.", "input": {"arg_c": 0, "context": "prop:249"}},
	{"ref": "prop:304", "unavailable": "This switch does not work yet.", "event": 4, "record": 304, "label": "Use switch", "feedback": "The switch starts the mechanism.", "input": {"arg_c": 0, "context": "prop:304"}},
	{"ref": "prop:250", "event": 4, "record": 250, "label": "Use vault opener", "feedback": "The vault mechanism moves.", "input": {"arg_c": 0, "context": "prop:250"}},
	{"ref": "control:53", "event": 5, "region": 987, "landing_region": 1166, "near_hint": "Step onto the pad to return upstairs",
	 "input": {"caller_byte": 4, "caller_byte_2": 0, "context": "control:53"}},
], "L19_BC": [
	{"ref":"movable:73", "event":4, "mover":73, "label":"Open door", "feedback":"The door opens.",
	 "raised_floors":{103:-45,100:-45,133:-45}, "guide_group":3264, "stream":1,
	 "opening_group":5858, "opening_input":{"caller_byte":2,"context":"movable:73"}},
]}
var host: Node3D
var binding: Node
var entries: Array[Dictionary] = []
var hint: Label
var last_step_position := Vector2.ZERO
var seed_steps := true

static func attach(map: Node3D) -> Node:
	var node: Node = load("res://scripts/lol2/generic_object_actions.gd").new()
	node.host = map
	node.name = "GenericObjects"
	map.add_child(node)
	return node

func _ready() -> void:
	binding = host.get("progression")
	if binding == null or binding.native == null: return
	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
	for raw: Dictionary in ROWS.get(str(host.area_id), []):
		var row: Dictionary = raw.duplicate(true)
		if not binding.native.placements.has(row.ref):
			push_error("Generic action source is missing: " + str(row.ref))
			continue
		if row.has("mover"):
			if not binding.mover_bodies.has(int(row.mover)):
				push_error("Generic action mover is missing: " + str(row.ref))
				continue
		elif int(row.event) == 4:
			for prop: Dictionary in geometry.props:
				if int(prop.record) == int(row.record): row["sprite"] = prop; break
			if not row.has("sprite") or not host.prop_placements.has(int(row.record)):
				push_error("Generic action sprite is missing: " + str(row.ref))
				continue
		entries.append(row)
	hint = preload("res://scripts/lol2/interaction_hint_label.gd").attach(self, Vector2(24, 365))
	restore()

func generic_owned_movers() -> Array:
	var result:Array=[]
	for row:Dictionary in entries:
		if row.has("mover"):result.append(int(row.mover))
	return result

func active() -> bool:
	return binding != null and binding._interaction_active() and WorldInput.available() and host.starting_magic.health() > 0

## The source sprite is a fixed-Y billboard. Intersect its published rectangle,
## then test the map's existing solids; no new walk/attack collision is added.
func aimed() -> Dictionary:
	if not active(): return {}
	var origin: Vector3 = host.camera.global_position
	var direction: Vector3 = -host.camera.global_basis.z
	var nearest: Dictionary = {}
	for row: Dictionary in entries:
		if int(row.event) != 4: continue
		if row.has("mover"):
			# The actual first world hit supplies both reach and occlusion. No
			# invisible use volume and no additional walk collision body.
			var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*REACH,1,[host.player.get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider == binding.mover_bodies[int(row.mover)]:
				var distance := origin.distance_to(hit.position)
				if nearest.is_empty() or distance < float(nearest.distance): nearest={"row":row,"distance":distance}
			continue
		var sprite: Dictionary = row.sprite
		var placement: Array = host.prop_placements[int(row.record)]
		var point: Vector3 = host.to_global(placement[2])
		var normal := Vector3(origin.x - point.x, 0, origin.z - point.z).normalized()
		var denominator := direction.dot(normal)
		if absf(denominator) < 0.0001: continue
		var distance := (point - origin).dot(normal) / denominator
		if distance <= 0 or distance > REACH: continue
		var hit: Vector3 = origin + direction * distance
		var right := Vector3(normal.z, 0, -normal.x)
		var x := (hit - point).dot(right)
		var y := hit.y - point.y
		if x < float(sprite.left) or x > float(sprite.right) or y < float(sprite.bottom) or y > float(sprite.top): continue
		var query := PhysicsRayQueryParameters3D.create(origin, hit, 1, [host.player.get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		if nearest.is_empty() or distance < float(nearest.distance): nearest = {"row": row, "distance": distance}
	return nearest

func would_use() -> bool:
	var shared:Node=get_node_or_null("GenericWorld")
	return not aimed().is_empty() or (shared!=null and shared.would_use())

func _unhandled_input(event: InputEvent) -> void:
	var use_key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not use_key and not click: return
	var target := aimed()
	if target.is_empty(): return
	var ran := fire(target.row)
	host.save_feedback(use_feedback(target.row,ran))
	get_viewport().set_input_as_handled() # Eligible use wins over a sword attack.

func use_feedback(row:Dictionary,ran:bool)->String:
	if row.has("unavailable"):return str(row.unavailable)
	if row.get("bridge_switch",false):
		var bridge:Node=host.get_node("L13Bridge")
		if bridge.state().started:return "The bridge above is already running." if not ran or bridge_was_running else "The switch hums; the bridge above wakes."
	return str(row.feedback) if ran else "The mechanism is busy."

var bridge_was_running:=false

func _process(_delta: float) -> void:
	if hint == null: return
	var target := aimed()
	hint.text = "" if target.is_empty() else "E — " + str(target.row.label)
	if hint.text.is_empty() and active():
		for row: Dictionary in entries:
			if row.has("near_hint") and near_pad(row): hint.text = str(row.near_hint); break

## A step-on pad's own line (lead 2026-11-15, L13 control:53): shown while the player stands within 60 of the pad,
## on its floor, so a silent teleporter says what it does. It never fires the pad.
func near_pad(row: Dictionary) -> bool:
	var region: Array = binding.regions[int(row.region)]
	var point: Vector3 = host.player.position
	if absf(point.y - Body.FOOT_OFFSET - float(region[1])) > 6: return false
	var polygon := PackedVector2Array()
	for vertex: Array in region[0]: polygon.append(Vector2(vertex[0], vertex[1]))
	var at := Vector2(point.x, point.z)
	if Geometry2D.is_point_in_polygon(at, polygon): return true
	for i in polygon.size():
		if Geometry2D.get_closest_point_to_segment(at, polygon[i], polygon[(i + 1) % polygon.size()]).distance_to(at) <= 60.0: return true
	return false

func on_pad(row: Dictionary, grounded := true) -> bool:
	if grounded and not host.player.is_on_floor(): return false
	var region: Array = binding.regions[int(row.region)]
	var point: Vector3 = host.player.position
	if absf(point.y - Body.FOOT_OFFSET - float(region[1])) > 6: return false
	var polygon := PackedVector2Array()
	for vertex: Array in region[0]: polygon.append(Vector2(vertex[0], vertex[1]))
	return Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), polygon)

func _physics_process(_delta: float) -> void:
	if binding == null: return
	var point := Vector2(host.player.position.x, host.player.position.z)
	if seed_steps:
		last_step_position = point
		seed_steps = false
		return # Restore seeds position; standing on the pad does not teleport.
	var walked := point.distance_squared_to(last_step_position) > 0.0625
	last_step_position = point # Never credit movement accumulated while inactive.
	if not active() or not walked: return
	for row: Dictionary in entries:
		if int(row.event) == 5 and on_pad(row): fire(row)

## This existing no-op is approved only for193 ->306 during this synchronous
## use. No area-wide adapter flag, including after a busy/refused event.
static func dispatch_native(target_binding:Node,row:Dictionary)->Array:
	var previous:Dictionary={}
	for name:String in row.get("native_adapters",[]):
		previous[name]=bool(target_binding.native.adapters_enabled.get(name,false))
		target_binding.native.set_adapter_enabled(name,true)
	var results:Array=target_binding.fire(row.ref,int(row.event),row.input)
	for name:String in previous:target_binding.native.set_adapter_enabled(name,previous[name])
	return results

func fire(row: Dictionary) -> bool:
	if row.has("unavailable"):return false # Known unsupported word-select path; no guessed floor/ceiling mutation.
	if row.has("guide_group"): return fire_guide_door(row)
	bridge_was_running=bool(host.get_node("L13Bridge").state().started) if row.get("bridge_switch",false) else false
	var results: Array = dispatch_native(binding,row)
	var ran := false
	for result: Dictionary in results:
		if result.status != "ran": continue
		ran = true
		for effect: Dictionary in result.get("effects", []):
			if effect.get("type") != "player_pose" or bool(effect.get("apply_height", false)) or not row.has("landing_region"): continue
			# Native flags0x0485 keep the previous height. The port's player
			# origin must land above the named destination floor, not below it.
			# Per-row world adapter; the opcode18 consumer stays unchanged.
			var region: Array = binding.regions[int(row.landing_region)]
			var previous := float(host.player.position.y)
			host.player.position.y = float(region[1]) + Body.FOOT_OFFSET
			host.player.force_update_transform()
			binding._log({"type": "generic_landing_floor", "ref": row.ref, "region": int(row.landing_region), "old_height": previous, "floor": region[1], "origin_offset": Body.FOOT_OFFSET})
	if ran and row.get("bridge_switch",false):host.get_node("L13Bridge").activate_from_switch()
	return ran

static func floors_raised(regions: Array, expected: Dictionary) -> bool:
	for key in expected:
		var id := int(key)
		if id < 0 or id >= regions.size() or float(regions[id][1]) < float(expected[key])-0.01: return false
	return true

## Lead's guide-behaviour adapter: the original caller for prop223 is UNKNOWN.
## Group3264 marks/sounds only, so the separately approved native door callback
## supplies the actual opening. Persistent state remains in the native bank.
func fire_guide_door(row: Dictionary) -> bool:
	if not floors_raised(binding.regions,row.raised_floors): return false
	if binding.native.field(row.ref,binding.NativeHost.FIELD_TRAVEL,0) > 0: return true
	var source: Dictionary = binding.native.execute_group(int(row.stream),int(row.guide_group))
	if source.status != "ran": return false
	var results: Array = binding.fire(row.ref,6,row.opening_input)
	for result: Dictionary in results:
		if result.status == "ran" and int(result.group) == int(row.opening_group):
			binding._log({"type":"guide_door_adapter","ref":row.ref,"guide_group":row.guide_group,"opening_group":row.opening_group,"raised_floors":row.raised_floors})
			return true
	return false

func restore() -> void:
	last_step_position = Vector2.ZERO
	seed_steps = true

func sync() -> void:
	# The native bank owns these actions; a registered shared child owns any
	# free generic motion fields. Keep one public root for HUD/saves/pad state.
	var shared:Node=get_node_or_null("GenericWorld")
	if shared!=null:shared.sync()
