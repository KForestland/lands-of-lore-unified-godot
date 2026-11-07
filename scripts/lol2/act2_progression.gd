extends Node
## Progression binder for the Act 2/3 map hosts (act2_map.gd), on the shared native script host (native_script_host.gd,
## res://scripts/lol2/native_scripts/<AREA>.json; adapters on). It binds, per level and without hand-written scripts:
##  - regions: the player's region (creature_nav/<AREA>.json quads) fires the region-entry event (kind 12, event 2) once per
##    entry on "region:N" when the level stores events for it;
##  - level changes: the PROVEN opcode-2 arm 0x1C commits the globals 0x223C8 (= byte 5 & 0x1F) and 0x223CC (= byte 5 >> 5);
##    read as level number and arrival selector (adapter, DEVIATIONS 2026-10-31) the node changes to that level's scene at
##    that arrival (meta lol2_map_start_selector) or logs the request when the scene is not staged;
##  - movables: E within reach of a scripted movable fires its kind-4 use (arg_c 0, context = the movable) as the Dark Halls
##    doors do; a rotary movable (mode 6) is drawn on its own hinge at the placement origin and turns by the travel word
##    (adapter: the hinge side and swing are not per-door proven);
##  - everything the host commits (object fields, locals, sounds, movie requests, enqueues) goes to native_log; every fired
##    event with its per-group status (ran PROVEN / ran on adapters / rejected / unhosted + reasons) goes to route_log.
## The host global 0x223D6 is supplied as 0 (adapter). Nothing here is PROVEN play; it is the host's data made visible.
const NativeHost = preload("res://scripts/lol2/native_script_host.gd")
const NATIVE_ROOT := "res://scripts/lol2/native_scripts/"
const NAV_ROOT := "res://assets/lol2/generated/creature_nav/"
const LEVEL_SCENES := {4: "res://scenes/lol2/act2_jungle_return.tscn", 8: "res://scenes/lol2/darker_jungle.tscn", 9: "res://scenes/lol2/dragon_level.tscn",
	10: "res://scenes/lol2/maps/L10_DC.tscn", 12: "res://scenes/lol2/maps/L12_CM.tscn", 13: "res://scenes/lol2/maps/L13_RC.tscn",
	14: "res://scenes/lol2/maps/L14_HT.tscn", 16: "res://scenes/lol2/maps/L16_CA.tscn", 17: "res://scenes/lol2/maps/L17_HC.tscn",
	19: "res://scenes/lol2/maps/L19_BC.tscn", 20: "res://scenes/lol2/maps/L20_BB.tscn"}
const REACH := 120.0
const FACING := 0.7
const MODE_ROTARY := 6
## Dev/test-start seeds (DEVIATIONS 2026-10-31, preview adapter, not a gameplay value): opcode-198-array / [0x26E58] locals a
## preview start supplies so a level's own gates can be reached when nothing before it ran. Applied only when the map was
## not entered by a native level change (act2_map.arrived_by_level_change false). Classic gameplay leaves them open.
## [0x26E58 + 52]: its only framed native writer is L20_BB stream 1 group 7704 (opcode 199 `c70000003401`, byte 4 = 52, byte 5 = 1,
## owned by prop 7704's kind-6 record; Grok backlog 4 item 9 LIKELY), so the seed stays until L20 progression is hosted.
const PREVIEW_SEEDS := {"L19_BC": {"e58": {52: 0}}}
## Per-host revert flags (lead 2026-10-31, the mover adapters): host adapter names switched OFF for an area after setup, so one
## host can go back to the refusal without touching the host script. The mover adapters (opcode2_arm18_clear, opcode2_arm3c,
## opcode3_item_grant, opcode12_room, opcode210_arm9, opcode1_other_modes) are the names meant here; every list is empty by default.
const HOST_ADAPTERS_OFF := {"L8_SJ": []}
signal level_change_requested(level: int, selector: int, scene: String)
var host: Node3D
var area_id := ""
var native: RefCounted = null
var regions: Array = []
var current_region := -1
var native_log: Array[Dictionary] = []
var route_log: Array[Dictionary] = []
var level_changes: Array[Dictionary] = []
var change_scene_enabled := true
var seeds_applied: Array[Dictionary] = []
## Rotary scripted movables drawn on hinges (their faces must have left the static mesh before the map's _ready); a host
## that draws its movables statically (darker_jungle.gd) attaches the binder with this off.
var hinges_enabled := true
## The map's RegionBlockers body (region_blockers.gd) when the map attached one: its opcode-197 regions are enabled here and
## toggled from the host's 0x22d0c:N bit_0x1c_0x01 writes (opcode 197 arms 0-5). blocker_log keeps every toggle.
var blockers: Node = null
var dynamic_blockers := 0
var blocker_log: Array[Dictionary] = []
var _pending: Dictionary = {}
var scripted_movables: Array[int] = []
var exit_objects: Dictionary = {}
var graph: Dictionary = {}
var exit_timer_elapsed: Dictionary = {}
var hinges: Dictionary = {}     # movable id -> Node3D
var hinge_origin: Dictionary = {}
var mover_modes: Dictionary = {}
var mover_bodies: Dictionary = {}
var mover_bounds: Dictionary = {}
var mover_targets: Dictionary = {}
var travel: Dictionary = {}     # movable id -> travel word

static func assets_ready(area: String) -> bool:
	return FileAccess.file_exists(NATIVE_ROOT + area + ".json")

## Arrival coordinates/selector are decoded data; floor + 32 and linear heading are the existing camera adapter.
## A transition must use the destination region floor, never the preview arrival's height.
static func arrival_pose(area: String, pack: Dictionary, selector: int) -> Dictionary:
	for arrival in pack.get("arrivals", []):
		if int(arrival.selector) != selector: continue
		if arrival.has("position"):
			var p: Array = arrival.position
			return {"position": Vector3(p[0], p[1], p[2]), "heading": int(arrival.heading), "selector": selector}
		var path := NAV_ROOT + area + ".json"
		if not FileAccess.file_exists(path): return {}
		var nav: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var index := int(arrival.region)
		if index < 0 or index >= nav.get("regions", []).size(): return {}
		return {"position": Vector3(float(arrival.x), float(nav.regions[index][1]) + 32.0, -float(arrival.y)), "heading": int(arrival.heading_units), "selector": selector}
	return {}

## The faces act2_map must leave out of its static mesh: every face of a rotary scripted movable (drawn on a hinge here).
static func hinge_faces(area: String, pack: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if not assets_ready(area): return out
	var probe: RefCounted = NativeHost.new()
	if not str(probe.call("load_area", NATIVE_ROOT + area + ".json")).is_empty(): return out
	var rotary := mover_ids(probe)
	for index in pack.faces.size():
		var face: Dictionary = pack.faces[index]
		if face.kind == "movable" and str(face.get("placement_kind", "")) == "movable" and rotary.has(int(face.source_index)): out[index] = true
	return out

## All source opcode-1 targets plus kind-4 movable owners; no actor/prop target becomes geometry.
static func mover_ids(probe: RefCounted) -> Dictionary:
	var ids: Dictionary = {}
	for commands in probe.get("groups").values():
		for command in commands:
			if int(command.opcode) == 1 and int(command.kind) == 0x20:
				ids[int(command.target)] = true
	for ref in probe.get("objects"):
		if not str(ref).begins_with("movable:"): continue
		for record in probe.call("object_records", ref):
			if int(record.kind) == 4: ids[int(str(ref).get_slice(":", 1))] = true
	return ids

func setup(map: Node3D, area: String) -> String:
	# Carry the caller's explicit no-seed configuration across native transitions.
	# It is a host option, never a quest flag or a substitute for a native writer.
	if get_tree().has_meta("lol2_adapter_exit_seeds"):
		map.set("adapter_exit_seeds", bool(get_tree().get_meta("lol2_adapter_exit_seeds")))
		get_tree().remove_meta("lol2_adapter_exit_seeds")
	host = map
	area_id = area
	name = "Act2Progression"
	native = NativeHost.new()
	var error: String = str(native.call("load_area", NATIVE_ROOT + area + ".json"))
	if not error.is_empty(): return error
	native.call("set_global", 0x223D6, 0)
	native.call("set_global", 0x223D4, 0)
	for name in HOST_ADAPTERS_OFF.get(area, []):
		native.call("set_adapter_enabled", str(name), false)
	# Per-host: L16 gate groups carry opcode 14 arm 5 (undecoded) before opening the gate (DEVIATIONS 2026-11-05).
	if area == "L16_CA": native.call("register_adapter", "opcode14_arm5_noop", true)
	native.connect("item_request", func(ref: String, identity: int, arg: int) -> void: native_log.append({"type": "item", "ref": ref, "identity": identity, "arg": arg}))
	native.connect("room_request", func(index: int, stem: String, archive: String) -> void: native_log.append({"type": "room", "index": index, "stem": stem, "archive": archive}))
	var arrived: Variant = map.get("arrived_by_level_change")   # null on hosts without the flag (darker_jungle.gd)
	if not (arrived is bool and bool(arrived)) and PREVIEW_SEEDS.has(area):
		var seeds: Dictionary = PREVIEW_SEEDS[area]
		for index in seeds.get("e58", {}):
			native.call("set_local_e58", int(index), int(seeds.e58[index]))
			seeds_applied.append({"table": "0x26E58", "index": int(index), "value": int(seeds.e58[index])})
		for index in seeds.get("local", {}):
			native.call("set_local", int(index), int(seeds.local[index]))
			seeds_applied.append({"table": "0x26E54", "index": int(index), "value": int(seeds.local[index])})
	var tree := get_tree()
	if tree.has_meta("lol2_act2_handoff") and map.has_method("apply_area_handoff"):
		var handoff_error: String = map.apply_area_handoff(tree.get_meta("lol2_act2_handoff"))
		if not handoff_error.is_empty(): return handoff_error
		tree.remove_meta("lol2_act2_handoff")
	var bank: Dictionary = tree.get_meta("lol2_act2_native_bank", {})
	if bank.has(area):
		for field in ["state", "locals", "locals_e58", "record_state"]:
			native.set(field, bank[area].get(field, {}).duplicate(true))
	_apply_arrival_exit_adapters()
	graph = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/act2_travel.json"))
	for edge in graph.get("edges", []):
		if str(edge.area) == area and not str(edge.owner).begins_with("region:"):
			if not exit_objects.has(edge.owner): exit_objects[edge.owner] = []
			exit_objects[edge.owner].append(edge)
	# L10's source writer of local11=1: control150 kind6 caller9/group19732. E is the
	# modern caller adapter; the full group/predicate still belongs to NativeHost.
	if area == "L10_DC":
		var ref := "control:150"
		var placement: PackedByteArray = native.get("placements").get(ref, PackedByteArray())
		for record in native.call("object_records", ref):
			var bytes: PackedByteArray = record.bytes
			if int(record.kind) == 6 and int(bytes[4]) == 9 and placement.size() >= 8:
				# Aim just outside the original panel's courtyard face. Its placement origin
				# lies on the floor inside its own collision and cannot be a visible E target.
				var box: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L10_DC.json")).boxes["150"]
				var heading: float = -TAU * float(box.heading) / 65536.0
				var aim := Vector3(box.x, float(box.h) + float(box.height) * 0.5, -box.y)
				aim += Vector3(sin(heading), 0, cos(heading)) * (float(box.depth) * 0.5 + 2.0)
				exit_objects[ref] = [{"event":{"kind":6,"value":9,"raw_hex":bytes.hex_encode()},
					"position":[aim.x,aim.y,aim.z]}]
	if area == "L9_DR": _bind_source_control("control:82", 5, 4)
	if area == "L17_HC": _bind_source_control("movable:50", 6, 20)
	native.connect("object_state_changed", _on_field)
	native.connect("local_changed", func(index: int, value: int): _log({"type": "local", "index": index, "value": value}))
	native.connect("sound_request", func(request: int): _log({"type": "sound", "request": request}))
	native.connect("movie_request", func(index: int, movie: String, byte5: int): _log({"type": "movie", "index": index, "name": movie, "byte5": byte5}))
	native.connect("event_enqueued", func(ref: String, kind: int, caller_byte: int): _log({"type": "enqueue", "ref": ref, "kind": kind, "caller_byte": caller_byte}))
	native.connect("global_changed", _on_global)
	var nav_path := NAV_ROOT + area + ".json"
	if FileAccess.file_exists(nav_path):
		var nav: Variant = JSON.parse_string(FileAccess.get_file_as_string(nav_path))
		if nav is Dictionary and nav.get("regions") is Array: regions = nav.regions
	for ref in native.get("objects"):
		if str(ref).begins_with("movable:"):
			for rec in native.call("object_records", ref):
				if int(rec.kind) == 4:
					scripted_movables.append(int(str(ref).get_slice(":", 1)))
					break
	if hinges_enabled: _build_hinges()
	blockers = map.get_node_or_null("RegionBlockers")
	if blockers != null and blockers.has_method("enable_dynamic"): dynamic_blockers = int(blockers.enable_dynamic())
	# Arrival is placement, not a new crossing. In L14 selector 3 the arrival itself is exit region 4176.
	# Arm the entry watcher at the initial region so it does not immediately send the player back (adapter).
	var translation: Vector3 = map.native_translation if map.get("native_translation") != null else Vector3.ZERO
	current_region = region_at(map.player.global_position - translation)
	return ""

## Lead14:57:13Z authorizes arrival-only predicate inputs where the writer is UNKNOWN.
## Each maps to a decoded exit; per-host adapter_exit_seeds=false retains the native unresolved gate.
func _apply_arrival_exit_adapters() -> void:
	if host.get("adapter_exit_seeds") != true: return
	var seed: Dictionary = {}
	match area_id:
		"L8_SJ": seed = {"table":"0x26E54","index":13,"value":1,"adapter":"L8_to_L14_pred136"}
		"L14_HT": seed = {"table":"0x26E54","index":22,"value":1,"adapter":"L14_to_L16_pred50"}
		"L17_HC": seed = {"table":"0x26E54","index":0,"value":10,"adapter":"L17_to_L16_prepare_pred0"}
		"L19_BC": seed = {"table":"0x26E58","index":52,"value":1 if int(host.start_selector)==2 else 0,"adapter":"L19_to_L20_pred204_205"}
		"L9_DR":
			native.call("set_field", "control:82", "byte_0x25", 2)
			seeds_applied.append({"object":"control:82","field":"byte_0x25","value":2,"adapter":"L9_to_L8_pred208"})
			return
	if seed.is_empty(): return
	if seed.table == "0x26E58": native.call("set_local_e58", int(seed.index), int(seed.value))
	else: native.call("set_local", int(seed.index), int(seed.value))
	seeds_applied.append(seed)

func _bind_source_control(ref: String, kind: int, caller: int) -> void:
	var placement: PackedByteArray = native.get("placements").get(ref, PackedByteArray())
	if placement.size() < 8: return
	for record in native.call("object_records", ref):
		var bytes: PackedByteArray = record.bytes
		if int(record.kind) != kind or int(bytes[4]) != caller: continue
		if not exit_objects.has(ref): exit_objects[ref] = []
		exit_objects[ref].push_front({"event":{"kind":kind,"value":caller,"raw_hex":bytes.hex_encode()},
			"position":[placement.decode_s16(0),placement.decode_s16(6),-placement.decode_s16(2)]})

## L9's two source timers only. Native records own start/stop and full groups; the modern clock
## interprets the original record counters300/120 as60Hz durations (5/2s), not a proven DOS clock.
func advance_exit_timers(delta: float) -> void:
	if area_id != "L9_DR" or native == null: return
	for record in native.call("object_records", "prop:104"):
		if int(record.kind) != 2: continue
		var offset := int(record.file_offset)
		var bytes: PackedByteArray = record.bytes
		var flags := int(native.get("record_state").get(offset, {}).get("byte5", int(bytes[5])))
		if (flags & 1) != 0:
			exit_timer_elapsed.erase(offset)
			continue
		exit_timer_elapsed[offset] = float(exit_timer_elapsed.get(offset, 0.0)) + maxf(0.0, delta)
		var duration := maxf(1.0/60.0, float(bytes.decode_u16(8))/60.0)
		if float(exit_timer_elapsed[offset]) >= duration:
			fire("prop:104", 2, {})
			exit_timer_elapsed.erase(offset)
			break # A timer started by this expiry begins on the next physics step.

func _log(row: Dictionary) -> void:
	native_log.append(row)

func _on_field(ref: String, field: String, value: int) -> void:
	_log({"type": "field", "ref": ref, "field": field, "value": value})
	if ref.begins_with("0x22d0c:") and field == "bit_0x1c_0x01":
		# Opcode 197 arms 0-5 on region N's word +0x1C bit 0 (the bit the movement check refuses the player on).
		var region := int(ref.get_slice(":", 1))
		var applied := is_instance_valid(blockers) and bool(blockers.set_region_blocked(region, value == 1))
		blocker_log.append({"region": region, "blocked": value == 1, "applied": applied})
	if field == NativeHost.FIELD_TRAVEL and ref.begins_with("movable:"):
		if area_id=="L8_SJ" and ref in ["movable:51","movable:52"] and host.has_node("L8Clubhouse"):return
		var id := int(ref.get_slice(":", 1))
		travel[id] = value
		_pose(id)

func _on_global(address: int, value: int) -> void:
	_log({"type": "global", "address": address, "value": value})
	if address == 0x223C8: _pending["level"] = value
	elif address == 0x223CC: _pending["selector"] = value
	if _pending.has("level") and _pending.has("selector"):
		var change := {"level": int(_pending.level), "selector": int(_pending.selector), "scene": str(LEVEL_SCENES.get(int(_pending.level), ""))}
		_pending = {}
		level_changes.append(change)
		level_change_requested.emit(int(change.level), int(change.selector), str(change.scene))
		call_deferred("_change_level", change)

func _change_level(change: Dictionary) -> void:
	if area_id=="L13_RC" and int(change.level)==12 and host.has_node("L13ExitLock") and not host.get_node("L13ExitLock").can_leave():
		host.save_feedback("Open the wall slot and take back the Dreamstone before leaving.");return
	# The used dose receipt, not the 60 s fall-asleep clock, keeps the passage open (DEVIATIONS 0307).
	if area_id=="L8_SJ" and int(change.level)==12 and not preload("res://scripts/lol2/l8_larkhon_state.gd").used(host.quest_state.get("l8_larkhon",{"slots":{}})):
		var guide: String = host.get_node("L8Larkhon").note_guidance() if host.has_node("L8Larkhon") else ""
		host.save_feedback("The Larkhon guards the cave entrance." + ("" if guide.is_empty() else " " + guide))
		_log({"type":"closed_passage","level":12,"owner":"l8_larkhon"})
		return
	if int(change.level)==9 and preload("res://scripts/lol2/l8_shore.gd").closed(host.quest_state):
		host.save_feedback("The ruins are flooded. This entrance is closed.")
		_log({"type":"closed_passage","level":9,"owner":"l8_shore"})
		return
	var scene: String = str(change.scene)
	if not change_scene_enabled: return
	if area_id=="L12_CM" and int(change.level)==13 and host.has_node("L12Citadel") and not host.get_node("L12Citadel").state().movie_seen:
		host.get_node("L12Citadel").begin_entry(change);return
	if scene.is_empty() or not ResourceLoader.exists(scene):
		if host.has_method("save_feedback"): host.save_feedback("Level change to level %d, arrival %d: that level is not staged in this build." % [int(change.level), int(change.selector)])
		return
	var bank: Dictionary = get_tree().get_meta("lol2_act2_native_bank", {})
	var saved: Dictionary = {}
	for field in ["state", "locals", "locals_e58", "record_state"]: saved[field] = native.get(field).duplicate(true)
	bank[area_id] = saved
	get_tree().set_meta("lol2_act2_native_bank", bank)
	if host.has_method("area_handoff"): get_tree().set_meta("lol2_act2_handoff", host.area_handoff())
	get_tree().set_meta("lol2_map_start_selector", int(change.selector))
	get_tree().set_meta("lol2_map_preview", true)
	get_tree().set_meta("lol2_level_change", true)
	get_tree().set_meta("lol2_adapter_exit_seeds", host.get("adapter_exit_seeds") == true)
	get_tree().change_scene_to_file(scene)

## Fires an event on a host object and keeps the per-group verdicts.
func fire(object_ref: String, event_kind: int, input: Dictionary = {}) -> Array:
	if native == null: return []
	var results: Array = native.call("fire_event", object_ref, event_kind, input)
	var rows: Array = []
	for r in results:
		var row := {"group": int(r.group), "status": str(r.status), "adapters": r.get("adapters", []), "reasons": r.get("reasons", [])}
		rows.append(row)
	route_log.append({"object": object_ref, "event": event_kind, "results": rows})
	return results

# --- regions ---------------------------------------------------------------------------------------
func region_at(point: Vector3) -> int:
	if regions.is_empty(): return -1
	if current_region >= 0 and _inside(current_region, point): return current_region
	if current_region >= 0:
		for edge in regions[current_region][3]:
			var n := int(edge[0])
			if _inside(n, point): return n
	var best := -1
	var best_dy := INF
	for i in regions.size():
		if not _inside(i, point): continue
		var dy := absf(point.y - float(regions[i][1]))
		if dy < best_dy: best_dy = dy; best = i
	return best

func _inside(index: int, point: Vector3) -> bool:
	var quad: Array = regions[index][0]
	if quad.is_empty(): return false
	var poly := PackedVector2Array()
	for v in quad: poly.append(Vector2(float(v[0]), float(v[1])))
	return Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), poly)

func enter_region(index: int) -> Array:
	current_region = index
	if native == null or not native.get("objects").has("region:%d" % index): return []
	return fire("region:%d" % index, 2, {})

func _physics_process(_delta: float) -> void:
	advance_movers(_delta)
	advance_exit_timers(_delta)
	if host == null or native == null or not is_instance_valid(host.get("player")): return
	var p: Vector3 = host.player.global_position - (host.native_translation if host.get("native_translation") != null else Vector3.ZERO)
	var here := region_at(p)
	if here >= 0 and here != current_region: enter_region(here)

# --- movables ---------------------------------------------------------------------------------------
func _build_hinges() -> void:
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
	var attributes: Dictionary = native.get("attributes")
	var placements: Dictionary = native.get("placements")
	for id in mover_ids(native):
		if area_id=="L14_HT" and id in [0,1,55,56,57,72,73,74,75,76,77,78,80,81,85,86,87]:continue # Dedicated bedroom headboard owner.
		if area_id=="L8_SJ" and id==50:continue # Tree shard-slot owner draws and collides this door.
		if area_id=="L12_CM" and id in [50,51,55]:continue # Dedicated original river raft owner.
		if area_id=="L13_RC" and id>=50 and id<=68:continue # L13Altar owns the earned boss gate and its collision.
		var ref := "movable:%d" % id
		if not attributes.has(ref) or not placements.has(ref): continue
		mover_modes[id] = int(attributes[ref].mode)
		var p: PackedByteArray = placements[ref]
		var origin := Vector3(p.decode_s16(0), p.decode_s16(6), -p.decode_s16(2))
		var hinge := Node3D.new()
		hinge.name = "Movable%d" % id
		hinge.position = origin
		var groups: Dictionary = {}
		for face in pack.faces:
			if face.kind != "movable" or str(face.get("placement_kind", "")) != "movable" or int(face.source_index) != id: continue
			if not groups.has(face.material):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[face.material] = surface
			for i in [0, 1, 2, 0, 2, 3]:
				groups[face.material].set_uv(Vector2(face.uv[i][0], face.uv[i][1]))
				groups[face.material].add_vertex(Vector3(face.points[i][0], face.points[i][1], face.points[i][2]) - origin)
		if groups.is_empty(): continue
		var body := AnimatableBody3D.new()
		body.name = "MoverCollision"
		body.collision_layer = 1
		body.collision_mask = 0
		body.sync_to_physics = false
		hinge.add_child(body)
		mover_bodies[id] = body
		var bounds := AABB()
		var first_mesh := true
		for key in groups:
			var mesh := MeshInstance3D.new()
			mesh.mesh = groups[key].commit()
			bounds = mesh.mesh.get_aabb() if first_mesh else bounds.merge(mesh.mesh.get_aabb())
			first_mesh = false
			var shape := CollisionShape3D.new()
			shape.shape = mesh.mesh.create_trimesh_shape()
			body.add_child(shape)
			var material := StandardMaterial3D.new()
			material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir() + "/" + pack.materials[key]))
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			if str(key) in pack.get("alpha_cutout_materials", []):
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mesh.material_override = material
			hinge.add_child(mesh)
		add_child(hinge)
		hinges[id] = hinge
		hinge_origin[id] = origin
		mover_bounds[id] = bounds
		travel[id] = int(native.call("field", ref, NativeHost.FIELD_TRAVEL, 0))
		_pose(id)

func _pose(id: int) -> void:
	if not hinges.has(id): return
	var target := Transform3D(Basis(), hinge_origin[id])
	if int(mover_modes.get(id, MODE_ROTARY)) == MODE_ROTARY:
		target.basis = Basis(Vector3.UP, -float(travel.get(id, 0)) / 65536.0 * TAU)
	else:
		# Motion axes are not yet traced: vertical panels retract upward, horizontal platforms slide along
		# their placement heading. Native travel word is observed only after the shared host accepts the group.
		var attrs: Dictionary = native.get("attributes")["movable:%d" % id]
		var scale := maxf(1.0, absf(float(attrs.get("angle_word", 1))))
		var fraction := clampf(float(travel.get(id, 0)) / scale, -1.0, 1.0)
		var bounds: AABB = mover_bounds[id]
		var displacement := Vector3.UP * (bounds.size.y + 8.0)
		if bounds.size.y < minf(bounds.size.x, bounds.size.z):
			var placement: PackedByteArray = native.get("placements")["movable:%d" % id]
			var heading := -float(placement.decode_u16(4)) / 65536.0 * TAU
			displacement = Vector3(sin(heading), 0, cos(heading)) * (maxf(bounds.size.x, bounds.size.z) + 8.0)
		target.origin += displacement * fraction
	mover_targets[id] = target

func advance_movers(delta: float) -> void:
	for id in mover_targets:
		var node: Node3D = hinges[id]
		var before := node.transform
		var target: Transform3D = mover_targets[id]
		var weight := minf(1.0, maxf(0.0, delta) * 4.0)
		node.transform = before.interpolate_with(target, weight)
		if node.transform.is_equal_approx(before): continue
		# Carry a player standing on this platform through its transform (adapter, no native lift physics claim).
		if is_instance_valid(host.player) and host.player.is_on_floor():
			var point: Vector3 = host.player.global_position
			var ray := PhysicsRayQueryParameters3D.create(point, point - Vector3.UP * 64.0, 1)
			var hit: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and hit.collider == mover_bodies[id]:
				host.player.position = node.transform * (before.affine_inverse() * host.player.position)

func movable_position(id: int) -> Vector3:
	if hinge_origin.has(id): return hinge_origin[id]
	var placements: Dictionary = native.get("placements")
	var ref := "movable:%d" % id
	if not placements.has(ref): return Vector3.INF
	var p: PackedByteArray = placements[ref]
	return Vector3(p.decode_s16(0), p.decode_s16(6), -p.decode_s16(2))

func aimed() -> int:
	var cam: Camera3D = host.camera
	var best := -1
	var best_dot := FACING
	var t: Vector3 = host.native_translation if host.get("native_translation") != null else Vector3.ZERO
	for id in scripted_movables:
		var point := movable_position(id)
		if point == Vector3.INF: continue
		var offset := point + t - cam.global_position
		if offset.length() > REACH: continue
		var dot := (-cam.global_basis.z).dot(offset.normalized())
		if dot > best_dot: best_dot = dot; best = id
	return best

func use(id: int) -> Array:
	if area_id=="L8_SJ" and id in [51,52]:return [] # Clubhouse guard owns these doors.
	return fire("movable:%d" % id, 4, {"arg_c": 0, "context": "movable:%d" % id})

## Modern E input for travel controls/props whose original caller is UNKNOWN. It supplies the event's
## declared caller bytes but never alters its predicate, record bits, or native command group.
func use_exit(object_ref: String) -> Array:
	if area_id=="L8_SJ" and object_ref=="prop:1198" and host.has_node("L8TempleDoor"):
		if not host.get_node("L8TempleDoor").can_leave():return []
		#0280: earned Kit receipt supplies the unresolved original predicate writer.
		native.call("set_local",13,1)
	var results: Array = []
	var seen: Dictionary = {}
	for edge in exit_objects.get(object_ref, []):
		var record: Dictionary = edge.event
		var kind := int(record.kind)
		if kind == 2: continue # Timer expiries belong to the clock, not manual E input.
		var key := "%d:%d" % [kind, int(record.get("value", 0))]
		if seen.has(key): continue
		seen[key] = true
		var input := {"context": object_ref, "arg_c": 0}
		if kind in [5, 6]: input["caller_byte"] = int(record.value)
		if kind == 5: input["caller_byte_2"] = int(str(record.raw_hex).hex_decode()[5])
		results.append_array(fire(object_ref, kind, input))
	return results

func aimed_exit() -> String:
	var best := ""
	var best_dot := FACING
	for ref in exit_objects:
		var edge: Dictionary = exit_objects[ref][0]
		if not edge.has("position"): continue
		var p: Array = edge.position
		var aim:=Vector3(p[0],p[1],p[2])
		if area_id=="L12_CM" and ref=="control:74" and host.has_node("L12Citadel"):aim=host.get_node("L12Citadel").entrance_aim()
		var offset: Vector3 = aim - host.camera.global_position
		if offset.length() > REACH: continue
		var dot: float = (-host.camera.global_basis.z).dot(offset.normalized())
		if dot <= best_dot: continue
		var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position, host.camera.global_position + offset, 1)
		if not host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		best = ref
		best_dot = dot
	return best

func _unhandled_input(event: InputEvent) -> void:
	if host == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or get_tree().paused or host.get("flying"): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		var object_ref := aimed_exit()
		if not object_ref.is_empty():
			var result := use_exit(object_ref)
			if host.has_method("save_feedback"):
				var pending := false
				for row in result: if str(row.status) == "unhosted": pending = true
				host.save_feedback("This passage is not available yet." if pending else "You use the passage control.")
			get_viewport().set_input_as_handled()
			return
		var id := aimed()
		if id >= 0:
			use(id)
			get_viewport().set_input_as_handled()
