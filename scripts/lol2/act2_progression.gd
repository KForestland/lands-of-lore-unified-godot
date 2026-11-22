extends Node
const ItemGrants=preload("res://scripts/lol2/item_grants.gd")
const GenericCatalog=preload("res://scripts/lol2/generic_object_catalog.gd")
const GenericRules=preload("res://scripts/lol2/generic_object_rules.gd")
const GenericPrimitives=preload("res://scripts/lol2/generic_attached_primitives.gd")
const PlayerCombat=preload("res://scripts/lol2/player_combat.gd")
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
##  - struck: a captured melee click on a mover body fires kind 9. The ray is mask 1. Control solids are layer 256,
##    so the ray does not reach them. The binder indexes L9 movables 72-85, 131, and 132. Movables 80-85, 131, and 132
##    have mover bodies, and the first sword hit fires a kind-9 record on each. Movables 72-79 have no mover faces.
##    The sword masks, the remaining-durability reading of dword_26, and global 0x23331 = 0 are adapters. Bramble and
##    the L12 bow and crevasse stay on their own hosts.
##  - everything the host commits (object fields, locals, sounds, movie requests, enqueues) goes to native_log; every fired
##    event with its per-group status (ran PROVEN / ran on adapters / rejected / unhosted + reasons) goes to route_log.
## The host global 0x223D6 is supplied as 0 (adapter). Nothing here is PROVEN play; it is the host's data made visible.
const NativeHost = preload("res://scripts/lol2/native_script_host.gd")
const Motion = preload("res://scripts/lol2/floor_motion_step.gd")
const NATIVE_ROOT := "res://scripts/lol2/native_scripts/"
const NAV_ROOT := "res://assets/lol2/generated/creature_nav/"
const LEVEL_SCENES := {4: "res://scenes/lol2/act2_jungle_return.tscn", 8: "res://scenes/lol2/darker_jungle.tscn", 9: "res://scenes/lol2/dragon_level.tscn",
	10: "res://scenes/lol2/maps/L10_DC.tscn", 12: "res://scenes/lol2/maps/L12_CM.tscn", 13: "res://scenes/lol2/maps/L13_RC.tscn",
	14: "res://scenes/lol2/maps/L14_HT.tscn", 16: "res://scenes/lol2/maps/L16_CA.tscn", 17: "res://scenes/lol2/maps/L17_HC.tscn",
	19: "res://scenes/lol2/maps/L19_BC.tscn", 20: "res://scenes/lol2/maps/L20_BB.tscn"}
const REACH := 120.0
const FACING := 0.7
const MODE_ROTARY := 6
## [0x26E58] stays unknown until opcode 199 stores byte 5 in 0..2, or the arrival adapter
## L19_to_L20_pred204_205 writes index 52. The old L19 preview seed of 0 is retired. An unread cell is not 0.
## Per-host revert flags (lead 2026-10-31, the mover adapters): host adapter names switched OFF for an area after setup, so one
## host can go back to the refusal without touching the host script. The mover adapters (opcode2_arm18_clear, opcode2_arm3c,
## opcode3_item_grant, opcode12_room, opcode210_arm9, opcode1_other_modes) are the names meant here; every list is empty by default.
const HOST_ADAPTERS_OFF := {"L8_SJ": []}
const STRIKE_REACH := PlayerCombat.REACH_PROP
## Sword cut pair from the bramble host. Kind-9 mask checks are native; choosing this pair for a melee click is an adapter.
const CUT_WORD0 := 0x080E
const CUT_WORD2 := 0x0004
const STRUCK_KEY := "act2_struck"
## These controls already have bespoke strike hosts. The binder must not fire their kind-9 records as well.
const STRUCK_SKIP: Array[String] = ["control:89", "control:91", "control:101", "control:102", "control:103", "control:104", "control:105", "control:106", "control:107", "control:108", "control:109"]
## Same id, two hosts. L19 movable 77 is the bars (kind 6 only). L9 movable 77 keeps its kind-9 record.
const STRUCK_AREA_SKIP: Dictionary = {"L19_BC": ["movable:77"]}
const Forms := preload("res://scripts/lol2/player_form_rules.gd")
const FormBody := preload("res://scripts/lol2/player_form_body.gd")
signal level_change_requested(level: int, selector: int, scene: String)
var host: Node3D
var area_id := ""
var native: RefCounted = null
var regions: Array = []
var current_region := -1
var _item_context_stack:Array[Dictionary]=[]
var native_log: Array[Dictionary] = []
var route_log: Array[Dictionary] = []
## Load re-arms (load_region_rule.gd): kept apart from route_log, which records only events the player's walk ran.
var load_rearm_log: Array[Dictionary] = []
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
var interaction_hint: Label
var winged_statue: Dictionary = {}
var graph: Dictionary = {}
var exit_timer_elapsed: Dictionary = {}
var hinges: Dictionary = {}     # movable id -> Node3D
var hinge_origin: Dictionary = {}
var mover_modes: Dictionary = {}
var mover_bodies: Dictionary = {}
var mover_attached:Dictionary={}
var mover_bounds: Dictionary = {}
var mover_targets: Dictionary = {}
var struck_refs: Dictionary = {}       # ref -> kind-9 file offsets
var struck_bodies: Dictionary = {}     # CollisionObject3D -> ref
var struck_durability: Dictionary = {} # ref -> remaining, seeded from placement byte +0x1E
var travel: Dictionary = {}     # movable id -> travel word
## Opcode 196 decks. region -> Node3D whose meshes sit at the native floor; position.y is the rise.
var floor_decks: Dictionary = {}
var floor_motion: Dictionary = {}
var floor_clock := 0.0
const FLOOR_FOOT := 32.0
## Opcode-18 room-mouth poses. L9Statue, L10Emperor, and L9Tower already play these.
## Consuming the pose still clears the 0xB7D5E slot. Luther stays where the walk put him.
## L9 4634 and its siblings are the tower landings in l9_tower_source.json (same raw bytes).
const ROOM_MOUTH_POSES := {
	"L9_DR": [3774, 4634, 4664, 4694, 4724, 4972, 4990, 5008, 5026, 5164, 5200, 5230, 5260],
	"L10_DC": [922],
}

static func assets_ready(area: String) -> bool:
	return FileAccess.file_exists(NATIVE_ROOT + area + ".json")

## The fifteen levels tools/prepare_native_scripts.py exports. A worktree or build that lacks one of them has no
## progression for that level (doors, lifts, movies, level changes stay dead), so it must say so loudly (lead 2026-11-15).
const NATIVE_AREAS := ["L1_DC", "L3_DH", "L4_HJ", "L5_HC", "L7_DH", "L8_SJ", "L9_DR", "L10_DC", "L12_CM", "L13_RC", "L14_HT", "L16_CA", "L17_HC", "L19_BC", "L20_BB"]
static func native_missing(area: String, root: String = NATIVE_ROOT) -> String:
	if not area in NATIVE_AREAS or FileAccess.file_exists(root + area + ".json"): return ""
	return "%s native scripts are not staged (%s%s.json): doors, lifts, movies and level changes will not work. Stage the build with tools/prepare_lane_worktree.py." % [area, root, area]

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

## Regions whose opcode-196 commands have byte 6 = 0. Other byte 6 values stay unhosted.
static func moving_floor_regions(area: String) -> Dictionary:
	var out: Dictionary = {}
	if not assets_ready(area):
		return out
	var probe := NativeHost.new()
	if not str(probe.call("load_area", NATIVE_ROOT + area + ".json")).is_empty():
		return out
	var table: Dictionary = probe.groups
	for key in table.keys():
		var commands: Array = table[key]
		for raw in commands:
			var command: Dictionary = raw
			if int(command.get("opcode", -1)) != 196:
				continue
			var bytes: PackedByteArray = command["bytes"]
			if bytes.size() < 8 or int(bytes[6]) != 0:
				continue
			out[int(bytes.decode_u16(2))] = true
	return out


## Floor faces of those regions that no dedicated host has already claimed. Kept for a caller that
## still wants the eager list. The map builders do not exclude these faces at load.
static func moving_floor_faces(area: String, pack: Dictionary, claimed: Dictionary) -> Dictionary:
	var regions := moving_floor_regions(area)
	var out: Dictionary = {}
	if regions.is_empty():
		return out
	var faces: Array = pack.get("faces", [])
	for index in faces.size():
		if claimed.has(index):
			continue
		var face: Dictionary = faces[index]
		if str(face.get("kind", "")) != "floor":
			continue
		var region: Variant = face.get("region", -1)
		if not ((region is int) or (region is float)):
			continue
		if regions.has(int(region)):
			out[index] = true
	return out


## The map builders still call this before the static mesh. A region stays in that mesh, with its
## collision, until an opcode 196 command with byte 6 = 0 for that region runs. Loading every
## targeted region as a deck removed L10 faces the static mesh still owns.
static func claim_moving_floors(_map: Node, _area: String, _pack: Dictionary, _excluded: Dictionary) -> void:
	pass


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
	var ids: Dictionary = GenericCatalog.movables(str(probe.get("area"))).duplicate()
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
	var session: Node = preload("res://scripts/lol2/game_session.gd").for_tree(get_tree())
	var option: Variant = session.take_seed_override()
	if option != null: map.set("adapter_exit_seeds", option)
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
	connect_item_sources()
	native.connect("room_request", func(index: int, stem: String, archive: String) -> void: native_log.append({"type": "room", "index": index, "stem": stem, "archive": archive}))
	var tree := get_tree()
	if tree.has_meta("lol2_act2_handoff") and map.has_method("apply_area_handoff"):
		var handoff_error: String = map.apply_area_handoff(tree.get_meta("lol2_act2_handoff"))
		if not handoff_error.is_empty(): return handoff_error
		tree.remove_meta("lol2_act2_handoff")
	var bank: Dictionary = session.snapshot_bank()
	if bank.has(area):
		var restore_error: String = native.restore(NativeHost.snapshot_fields(bank[area]))
		if not restore_error.is_empty(): return restore_error
	# The original 0x26E58 buffer is game-wide. The per-level bank keeps
	# only locals/record/object state; current global cells win over old copies.
	native.locals_e58=preload("res://scripts/lol2/game_native_globals.gd").runtime(session.native_globals)
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
				winged_statue = box
				var heading: float = -TAU * float(box.heading) / 65536.0
				var aim := Vector3(box.x, float(box.h) + float(box.height) * 0.5, -box.y)
				aim += Vector3(sin(heading), 0, cos(heading)) * (float(box.depth) * 0.5 + 2.0)
				exit_objects[ref] = [{"event":{"kind":6,"value":9,"raw_hex":bytes.hex_encode()},
					"position":[aim.x,aim.y,aim.z]}]
	if area == "L9_DR": _bind_source_control("control:82", 5, 4)
	if area == "L17_HC": _bind_source_control("movable:50", 6, 20)
	# Prop 98 is the Dawn-shaft lever. Kind 6 caller 20. The original caller on that
	# record is 20, so this bind is the same E adapter as the other source controls.
	if area == "L19_BC": _bind_source_control("prop:98", 6, 20)
	# Prop 100 (2477, -968, at the south end of corridor 2010) opens the slot 1932 into the elevator cab: kind 6 caller 20
	# runs group 2166 (1932 floor -100; ceilings by the opcode196_word_select adapter). Same E adapter as prop 98
	# (lead 2026-11-14, Grok dawn3: every stand stopped on the slot's riser).
	if area == "L19_BC": _bind_source_control("prop:100", 6, 20, 24.0)
	native.connect("object_state_changed", _on_field)
	native.connect("local_changed", func(index: int, value: int): _log({"type": "local", "index": index, "value": value}))
	native.connect("sound_request", func(request: int): _log({"type": "sound", "request": request}))
	native.connect("movie_request", func(index: int, movie: String, byte5: int): _log({"type": "movie", "index": index, "name": movie, "byte5": byte5}))
	native.connect("event_enqueued", func(ref: String, kind: int, caller_byte: int): _log({"type": "enqueue", "ref": ref, "kind": kind, "caller_byte": caller_byte}))
	native.connect("global_changed", _on_global)
	var nav_path: String = preload("res://scripts/lol2/geometry_move.gd").nav_path(area, NAV_ROOT + area + ".json")
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
	_build_floor_decks()
	blockers = map.get_node_or_null("RegionBlockers")
	if blockers != null and blockers.has_method("enable_dynamic"): dynamic_blockers = int(blockers.enable_dynamic())
	# Arrival is placement, not a new crossing. In L14 selector 3 the arrival itself is exit region 4176.
	# Arm the entry watcher at the initial region so it does not immediately send the player back (adapter).
	var translation: Vector3 = map.native_translation if map.get("native_translation") != null else Vector3.ZERO
	current_region = region_at(map.player.global_position - translation)
	_collect_struck()
	_overlay_struck_bank()
	_index_struck_bodies()
	if bank.has(area) and bank[area].has("world"):
		error=preload("res://scripts/lol2/act2_world_checkpoint.gd").restore(self,bank[area].world)
		if not error.is_empty():return error
	# Native.restore deliberately emits no signals. Project saved region bits
	# into the dynamic collision owner without re-running their script groups.
	if is_instance_valid(blockers):
		for ref:String in native.state:
			if ref.begins_with("0x22d0c:") and native.state[ref].has("bit_0x1c_0x01"):
				blockers.set_region_blocked(int(ref.get_slice(":",1)),int(native.state[ref]["bit_0x1c_0x01"])==1)
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

## `lift` raises the aim point above the placement base (a floor-level prop: an aim on the floor surface is never clear).
func _bind_source_control(ref: String, kind: int, caller: int, lift: float = 0.0) -> void:
	var placement: PackedByteArray = native.get("placements").get(ref, PackedByteArray())
	if placement.size() < 8: return
	for record in native.call("object_records", ref):
		var bytes: PackedByteArray = record.bytes
		if int(record.kind) != kind or int(bytes[4]) != caller: continue
		if not exit_objects.has(ref): exit_objects[ref] = []
		exit_objects[ref].push_front({"event":{"kind":kind,"value":caller,"raw_hex":bytes.hex_encode()},
			"position":[placement.decode_s16(0),placement.decode_s16(6)+lift,-placement.decode_s16(2)]})

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

func write_generic_motion(id:int,row:Dictionary):
	for field in GenericRules.FIELDS:native.set_field("movable:%d"%id,field,int(row[field]))
func _on_field(ref: String, field: String, value: int) -> void:
	_log({"type": "field", "ref": ref, "field": field, "value": value})
	if ref.begins_with("0x22d0c:") and field == NativeHost.FIELD_FLOOR_TARGET:
		_start_floor(int(ref.get_slice(":", 1)), value, int(native.field(ref, NativeHost.FIELD_FLOOR_RATE, 0)))
	if ref.begins_with("0x22d0c:") and field == "bit_0x1c_0x01":
		# Opcode 197 arms 0-5 on region N's word +0x1C bit 0 (the bit the movement check refuses the player on).
		var region := int(ref.get_slice(":", 1))
		var applied := is_instance_valid(blockers) and bool(blockers.set_region_blocked(region, value == 1))
		blocker_log.append({"region": region, "blocked": value == 1, "applied": applied})
	if field == NativeHost.FIELD_TRAVEL and ref.begins_with("movable:"):
		if area_id=="L8_SJ" and ref in ["movable:51","movable:52"] and host.has_node("L8Clubhouse"):return
		var id := int(ref.get_slice(":", 1))
		travel[id] = value
		if GenericCatalog.movables(area_id).has(id):
			var position:int=native.field(ref,GenericRules.POSITION,0)
			var target:int=value*GenericRules.FIXED
			native.set_field(ref,GenericRules.PHASE,2 if position<target else (3 if position>target else (1 if position>0 else 0)))
			native.set_field(ref,GenericRules.FRACTION,0)
		_pose(id)
	if field == "bit_0x15_0x80" and ref.begins_with("movable:"):
		_apply_open_bit(int(ref.get_slice(":", 1)))

var transition_pending := false

func _on_global(address: int, value: int) -> void:
	_log({"type": "global", "address": address, "value": value})
	if address == 0x223C8: _pending["level"] = value
	elif address == 0x223CC: _pending["selector"] = value
	if _pending.has("level") and _pending.has("selector"):
		var change := {"level": int(_pending.level), "selector": int(_pending.selector), "scene": str(LEVEL_SCENES.get(int(_pending.level), ""))}
		_pending = {}
		level_changes.append(change)
		transition_pending = true
		level_change_requested.emit(int(change.level), int(change.selector), str(change.scene))
		call_deferred("_change_level", change)

func _change_level(change: Dictionary) -> void:
	transition_pending = false
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
	var session: Node = preload("res://scripts/lol2/game_session.gd").for_tree(get_tree())
	session.store_current(self)
	if host.has_method("area_handoff"): get_tree().set_meta("lol2_act2_handoff", host.area_handoff())
	get_tree().set_meta("lol2_map_start_selector", int(change.selector))
	get_tree().set_meta("lol2_map_preview", true)
	get_tree().set_meta("lol2_level_change", true)
	session.set_seed_override(host.get("adapter_exit_seeds") == true)
	get_tree().change_scene_to_file(scene)

## Direct opcode-18 player pose. Native (x, y) is Godot (x, z = -y). Flag 0x0100 supplies the height word;
## otherwise the current height stays. Floor reconciliation was not entered, so a clear 0x0100 does not snap to a floor.
static func player_pose_position(effect: Dictionary, current: Vector3) -> Vector3:
	var y: float = current.y
	if bool(effect.get("apply_height", false)):
		y = float(int(effect.get("height", 0)))
	return Vector3(float(int(effect.get("x", 0))), y, -float(int(effect.get("y", 0))))


static func player_pose_yaw(heading: int) -> float:
	return -TAU * float(heading & 65535) / 65536.0


## Applies player_pose effects in order. Returns true when a pose was consumed, so the caller can
## clear the 0xB7D5E slot. skip_groups consumes those groups' poses without moving Luther.
static func apply_player_pose_effects(results: Array, player: Node3D, skip_groups: Array = []) -> bool:
	var posed: bool = false
	for result in results:
		if not result is Dictionary:
			continue
		var record: Dictionary = result
		var group_id: int = int(record.get("group", -1))
		var effects: Variant = record.get("effects", [])
		if not effects is Array:
			continue
		for effect in effects as Array:
			if not effect is Dictionary:
				continue
			var row: Dictionary = effect
			if str(row.get("type", "")) != "player_pose":
				continue
			if group_id in skip_groups:
				posed = true
				continue
			player.position = player_pose_position(row, player.position)
			player.rotation.y = player_pose_yaw(int(row.get("heading", 0)))
			if player is CharacterBody3D:
				(player as CharacterBody3D).velocity = Vector3.ZERO
			posed = true
	return posed


func consume_player_poses(results: Array) -> void:
	if host == null:
		return
	var player: Variant = host.get("player")
	if not is_instance_valid(player) or not player is Node3D:
		return
	var listed: Variant = ROOM_MOUTH_POSES.get(area_id, [])
	var skip_groups: Array = listed if listed is Array else []
	if not apply_player_pose_effects(results, player as Node3D, skip_groups):
		return
	if native != null:
		native.call("set_field", "0xb7d5e", "command_file_offset", 0)


## Fires an event on a host object and keeps the per-group verdicts.
func fire(object_ref: String, event_kind: int, input: Dictionary = {}) -> Array:
	if native == null: return []
	_item_context_stack.append({"object":object_ref,"event":event_kind})
	var results: Array = native.call("fire_event", object_ref, event_kind, input)
	_item_context_stack.pop_back()
	consume_player_poses(results)
	var rows: Array = []
	for r in results:
		var row := {"group": int(r.group), "status": str(r.status), "adapters": r.get("adapters", []), "reasons": r.get("reasons", [])}
		rows.append(row)
	route_log.append({"object": object_ref, "event": event_kind, "results": rows})
	return results

## Used by full map setup and isolated native dispatch components.
func connect_item_sources() -> void:
	if not native.is_connected("item_request",_record_item_request):native.connect("item_request",_record_item_request)
	if not native.is_connected("item_source",_receive_item_source):native.connect("item_source",_receive_item_source)
func _record_item_request(ref:String,identity:int,arg:int) -> void:
	native_log.append({"type":"item","ref":ref,"identity":identity,"arg":arg})
func _receive_item_source(raw:Dictionary) -> void:
	var source:=raw.duplicate(true)
	# The VM knows its internally enqueued object's context. Never overwrite it
	# with an outer binding call; missing fields alone use the bridge fallback.
	if not source.has("object") and not _item_context_stack.is_empty():source.merge(_item_context_stack.back())
	source["area"]=area_id
	ItemGrants.native(host,source)

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
	if area_id == "L19_BC" and index == L20_DOOR_REGION: _l20_door_cell()
	if native == null or not native.get("objects").has("region:%d" % index): return []
	return fire("region:%d" % index, 2, {})

## Compatibility only when no actual global cell exists: new live writes now
## follow the player across all areas. The initial/legacy unknown byte still
## needs the already-approved story fallback; no native initial writer is known.
## L19 -> L20 door (adapter L19_to_L20_history, lead 2026-11-14 after Grok e21599e-dawn). Region 2369's two entry records
## pick the L20 arrival by [0x26E58] cell 52: pred 204 (== 0) -> arrival 1, pred 205 (== 1) -> arrival 2 (opcode 2 arm
## 0x1C bytes 0x34/0x54). Only L20 writes it: prop 242 (the mother, Frank's Placenta) kind 6 caller 21 -> group 7704 stores
## 1, behind opcode-2 arms 0x23/0x25/0x35 that are not decoded. The arrival seed L19_to_L20_pred204_205 runs only with
## adapter_exit_seeds, which F2 checkpoints set false, so on those starts and on saves without it the cell stayed unknown
## and the door did nothing. At the door, an unknown cell is taken from the player's own L20 history: 1 once the curse
## has been cast into the mother (l19_dawn_curse.glob_entered, the port's prop-242 beat), else 0 (never written).
const L20_DOOR_REGION := 2369
func _l20_door_cell() -> void:
	if native == null or (native.get("locals_e58") as Dictionary).has(52): return
	var curse: Variant = host.get("quest_state").get("l19_dawn_curse", {}) if host.get("quest_state") is Dictionary else {}
	var value := 1 if curse is Dictionary and bool((curse as Dictionary).get("glob_entered", false)) else 0
	native.call("set_local_e58", 52, value)
	seeds_applied.append({"table": "0x26E58", "index": 52, "value": value, "adapter": "L19_to_L20_history"})

func _physics_process(delta: float) -> void:
	advance_floors(delta)
	advance_movers(delta)
	advance_exit_timers(delta)
	if host == null or native == null or not is_instance_valid(host.get("player")): return
	var p: Vector3 = host.player.global_position - (host.native_translation if host.get("native_translation") != null else Vector3.ZERO)
	var here := region_at(p)
	if here >= 0 and here != current_region: enter_region(here)
	_walk_into_winged_statue()

func _interaction_active() -> bool:
	if host == null or get_tree().paused or host.get("flying") or is_instance_valid(host.get("inventory")): return false
	var hud: Variant = host.get("interface_hud")
	if is_instance_valid(hud) and hud.cursor_active: return false
	if host.has_method("actor_input_locked") and host.actor_input_locked(): return false
	return true

## Closed doors and gates name their E (lead 2026-11-17 rule, after Grok's silent L16 canal doors and L19 gate 69 / Golden
## Door 51): on every level, when the same aimed() picker E uses rests on a scripted movable that has a native E record
## (event kind 4 - what use() fires) and is closed (travel 0), the line reads 'E — Open the door' ('the gate' where named).
## Movables whose E another owner hosts are left to that owner's own line.
const GATES := {"L19_BC": [69]}
const CITADEL_ENTRANCE_PROMPT := "E — Enter the Citadel"
var _e_movables: Variant = null

func e_movables() -> Dictionary:
	if _e_movables == null:
		_e_movables = {}
		var objects: Variant = native.get("objects") if native != null else null
		if objects is Dictionary:
			for ref in objects:
				if not str(ref).begins_with("movable:"): continue
				for raw in objects[ref]:
					if raw is Dictionary and int((raw as Dictionary).get("kind", -1)) == 4:
						_e_movables[int(str(ref).get_slice(":", 1))] = true; break
	return _e_movables

func door_prompt(id: int) -> String:
	if id < 0 or not e_movables().has(id) or int(travel.get(id, 0)) != 0: return ""
	if area_id == "L8_SJ" and id in [51, 52]: return "" # the Clubhouse guard owns these doors (use())
	if area_id == "L16_CA" and id >= CITY_CANAL_LEAVES.x and id <= CITY_CANAL_LEAVES.y and int(travel.get(id ^ 1, 0)) != 0: return ""
	return "E — Open the gate" if id in GATES.get(area_id, []) else "E — Open the door"

func _process(_delta: float) -> void:
	if native == null: return
	if interaction_hint == null:
		interaction_hint = preload("res://scripts/lol2/interaction_hint_label.gd").attach(self, Vector2(24, 275))
	interaction_hint.text = ""
	if not _interaction_active(): return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless":
		interaction_hint.text = door_prompt(aimed())
		if not interaction_hint.text.is_empty(): return
	# The Citadel entrance is an exit control, not a door movable, so door_prompt never sees it (Grok 2026-11-18, deck
	# 3643,-19275: the aimed E on control 74 entered the Citadel and the screen named no E). Same picker as E.
	if area_id == "L12_CM":
		if aimed_exit() == "control:74": interaction_hint.text = CITADEL_ENTRANCE_PROMPT
		return
	if area_id != "L10_DC": return
	var ref := aimed_exit()
	if ref == "control:150" and area_id == "L10_DC":
		interaction_hint.text = "E — Touch the winged statue"

## Book entry uses the already-bound native caller, just like E. Only a physical
## approach into the source box's courtyard face admits it; loading nearby is idle.
func _walk_into_winged_statue() -> void:
	if winged_statue.is_empty() or not _interaction_active() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if not host.starting_magic.world_active() or int(native.get("locals").get(11, 0)) == 1: return
	var basis := Basis(Vector3.UP, -TAU * float(winged_statue.heading) / 65536.0)
	var direction := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if (host.player.basis * direction).dot(basis.z) >= -0.5: return
	var shape: Shape3D = host.player.get_child(0).shape
	var radius := float(shape.radius)
	var half_height := float(shape.height) * 0.5
	var p: Vector3 = host.player.global_position
	var local := basis.inverse() * (p - Vector3(winged_statue.x, winged_statue.h, -winged_statue.y))
	if absf(local.x) > float(winged_statue.width) * 0.5 + radius: return
	if local.z < float(winged_statue.depth) * 0.5 or local.z > float(winged_statue.depth) * 0.5 + radius + 4.0: return
	if local.y + half_height < 0 or local.y - half_height > float(winged_statue.height): return
	if aimed_exit() != "control:150": return
	use_exit("control:150")
	# Contact can be inside the mirror's actual region already. Its earlier entry
	# tested local11 before the statue supplied it; re-evaluate that same source
	# region now, rather than requiring the player to leave and walk back in.
	if current_region == 42: enter_region(42)

# --- movables ---------------------------------------------------------------------------------------
func _build_floor_decks() -> void:
	var indices: Array = host.get_meta("lol2_moving_floor_faces", [])
	if indices.is_empty() or not host.get("geometry_file") is String:
		return
	var pack: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(host.geometry_file)))
	if not pack is Dictionary:
		return
	var faces: Array = (pack as Dictionary).get("faces", [])
	var by_region: Dictionary = {}
	for raw in indices:
		var index := int(raw)
		if index < 0 or index >= faces.size():
			continue
		var face: Dictionary = faces[index]
		var region := int(face.get("region", -1))
		if not by_region.has(region):
			by_region[region] = []
		(by_region[region] as Array).append(face)
	var root := Node3D.new()
	root.name = "FloorMotions"
	add_child(root)
	var materials: Dictionary = {}
	var base := str(host.geometry_file).get_base_dir() + "/"
	var images: Dictionary = (pack as Dictionary).get("materials", {})
	for region in by_region.keys():
		var region_id := int(region)
		var deck := Node3D.new()
		deck.name = "Floor%d" % region_id
		var native_floor := 0
		if region_id >= 0 and region_id < regions.size():
			native_floor = int(regions[region_id][1])
		deck.set_meta("native_floor", native_floor)
		var grouped: Dictionary = {}
		var points := PackedVector3Array()
		for raw_face in by_region[region]:
			var face: Dictionary = raw_face
			var material_key := str(face.get("material", ""))
			var tool: SurfaceTool
			if grouped.has(material_key):
				tool = grouped[material_key]
			else:
				tool = SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				grouped[material_key] = tool
			var order := [0, 1, 2, 0, 2, 3]
			for corner in order:
				var point: Array = face.points[corner]
				var vertex := Vector3(float(point[0]), float(point[1]), float(point[2]))
				if face.has("uv"):
					var uv: Array = face.uv[corner]
					tool.set_uv(Vector2(float(uv[0]), float(uv[1])))
				tool.add_vertex(vertex)
				points.append(vertex)
		for material_key in grouped.keys():
			var surface: SurfaceTool = grouped[material_key]
			surface.generate_normals()
			var mesh := MeshInstance3D.new()
			mesh.mesh = surface.commit()
			if not materials.has(material_key) and images.has(material_key):
				var image := Image.load_from_file(base + str(images[material_key]))
				var material := StandardMaterial3D.new()
				if image != null:
					material.albedo_texture = ImageTexture.create_from_image(image)
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				materials[material_key] = material
			if materials.has(material_key):
				mesh.material_override = materials[material_key]
			deck.add_child(mesh)
		if points.is_empty():
			continue
		var body := AnimatableBody3D.new()
		body.name = "Collision"
		body.collision_layer = 1
		body.collision_mask = 0
		body.sync_to_physics = false
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(points)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		deck.add_child(body)
		root.add_child(deck)
		floor_decks[region_id] = deck


static func _floor_point_key(point: Vector3) -> String:
	return "%d,%d,%d" % [int(round(point.x * 1000.0)), int(round(point.y * 1000.0)), int(round(point.z * 1000.0))]


## The first opcode 196 for this region lifts its floor faces out of the static mesh and onto a deck.
## Faces another host already excluded stay with that host.
## `target` is that command's floor. The command does not write a ceiling. On L19, a corridor whose
## ceiling would then clear less than a standing Human keeps the clearance it had: the ceiling, and a
## source wall standing on that ceiling, ride the same deck. The cab and the bars stay put; their
## clearance never drops under the Human.
## Owner F10 2026-11-16T16-30-04 (r19o8): the L12 lake switch starts ten floor regions at once and each claim parsed the
## 5.2 MB geometry pack again and re-cut the whole static floor collision (111 ms + 87 ms each here): a 3-7 s freeze.
## Claims made in one frame share one parse and one static-floor cut, both at the end of that frame.
var _claim_pack: Variant = null
var _claim_strip_keys: Dictionary = {}

func _claim_geometry_pack() -> Variant:
	if _claim_pack == null:
		_claim_pack = JSON.parse_string(FileAccess.get_file_as_string(str(host.geometry_file)))
		_drop_claim_pack.call_deferred()
	return _claim_pack

func _drop_claim_pack() -> void:
	_claim_pack = null
	if not _claim_strip_keys.is_empty():
		var keys := _claim_strip_keys
		_claim_strip_keys = {}
		_strip_static_floor(keys)

func _claim_region_floor(region: int, target: int = 2147483647) -> void:
	if floor_decks.has(region) or not is_instance_valid(host):
		return
	if not host.get("geometry_file") is String:
		return
	var pack: Variant = _claim_geometry_pack()
	if not pack is Dictionary:
		return
	var faces: Array = (pack as Dictionary).get("faces", [])
	var excluded: Variant = host.get("excluded_faces")
	var chosen: Array = []
	var ceiling_y: float = INF
	var ceiling_edges: Array = []
	for index in faces.size():
		if excluded is Dictionary and (excluded as Dictionary).has(index):
			continue
		var raw: Variant = faces[index]
		if not raw is Dictionary:
			continue
		var face: Dictionary = raw
		var kind := str(face.get("kind", ""))
		var face_region := _face_region(face)
		if kind == "floor" and face_region == region:
			chosen.append(face)
			if excluded is Dictionary:
				(excluded as Dictionary)[index] = true
		elif kind == "ceiling" and face_region == region:
			var low := INF
			var poly: Array = face.get("points", [])
			for point in poly:
				low = minf(low, float(point[1]))
			if low < ceiling_y:
				ceiling_y = low
			var edge_count := poly.size()
			for edge in edge_count:
				var a: Array = poly[edge]
				var b: Array = poly[(edge + 1) % edge_count]
				ceiling_edges.append([Vector2(float(a[0]), float(a[2])), Vector2(float(b[0]), float(b[2]))])
	var old_floor := 0
	if region >= 0 and region < regions.size():
		old_floor = int(regions[region][1])
	var human: float = float(FormBody.HEIGHTS[0])
	var follow: bool = area_id == "L19_BC" and ceiling_y < INF and target != 2147483647 and ceiling_y - float(target) < human and ceiling_y - float(old_floor) >= human
	if follow:
		for index in faces.size():
			if excluded is Dictionary and (excluded as Dictionary).has(index):
				continue
			var raw_follow: Variant = faces[index]
			if not raw_follow is Dictionary:
				continue
			var follow_face: Dictionary = raw_follow
			var follow_kind := str(follow_face.get("kind", ""))
			var take := false
			if follow_kind == "ceiling" and _face_region(follow_face) == region:
				take = true
			elif follow_kind == "source_wall" and _wall_on_ceiling(follow_face, ceiling_y, ceiling_edges):
				take = true
			if not take:
				continue
			chosen.append(follow_face)
			if excluded is Dictionary:
				(excluded as Dictionary)[index] = true
	# A closed slot (floor = ceiling) whose floor goes down takes the risers standing on its old floor along its edges
	# (any region's source wall whose top is that floor and whose bottom is not below the target): in the original they
	# shrink as the floor comes down (L19 slot 1932: walls 8646 of 2010 and 8552 of 1931, -100..0). Riding the deck,
	# they sink under the floor. Rooms that keep their height (the cab 1943 riding its shaft) keep their walls.
	if area_id == "L19_BC" and target != 2147483647 and target < old_floor and ceiling_y < INF and absf(ceiling_y - float(old_floor)) < 0.5:
		var floor_edges: Array = []
		for raw_floor in chosen:
			var fp: Array = (raw_floor as Dictionary).get("points", [])
			if str((raw_floor as Dictionary).get("kind", "")) != "floor": continue
			for e in fp.size():
				floor_edges.append([Vector2(float(fp[e][0]), float(fp[e][2])), Vector2(float(fp[(e + 1) % fp.size()][0]), float(fp[(e + 1) % fp.size()][2]))])
		for index in faces.size():
			if excluded is Dictionary and (excluded as Dictionary).has(index):
				continue
			var raw_riser: Variant = faces[index]
			if not raw_riser is Dictionary or str((raw_riser as Dictionary).get("kind", "")) != "source_wall":
				continue
			if not _wall_under_floor(raw_riser, float(old_floor), float(target), floor_edges):
				continue
			chosen.append(raw_riser)
			if excluded is Dictionary:
				(excluded as Dictionary)[index] = true
	var slot_shell: Array = []
	if area_id == "L19_BC" and target != 2147483647 and target < old_floor and ceiling_y < INF and absf(ceiling_y - float(old_floor)) < 0.5:
		slot_shell = _slot_shell_faces(region, faces, float(target), ceiling_y, ceiling_edges)
	if chosen.is_empty():
		return
	_add_region_deck(region, chosen, pack as Dictionary)
	if not slot_shell.is_empty(): _add_slot_shell(region, slot_shell, pack as Dictionary)
	var keys: Dictionary = {}
	for raw_face in chosen:
		var deck_face: Dictionary = raw_face
		for point in deck_face.get("points", []):
			keys[_floor_point_key(Vector3(float(point[0]), float(point[1]), float(point[2])))] = true
	_claim_strip_keys.merge(keys)


func _wall_on_ceiling(face: Dictionary, ceiling_y: float, edges: Array) -> bool:
	var low := INF
	var high := -INF
	var ends: Array = []
	for point in face.get("points", []):
		var y := float(point[1])
		low = minf(low, y)
		high = maxf(high, y)
		var spot := Vector2(float(point[0]), float(point[2]))
		var seen := false
		for have in ends:
			if (have as Vector2).distance_to(spot) < 1.0:
				seen = true
				break
		if not seen:
			ends.append(spot)
	if ends.size() != 2 or absf(low - ceiling_y) > 1.0 or high <= ceiling_y + 1.0:
		return false
	return _end_near_edges(ends[0] as Vector2, edges) and _end_near_edges(ends[1] as Vector2, edges)


## A source wall whose top is `floor_y` and bottom not below `target`, with both ends on `edges`: a riser up to that floor.
func _wall_under_floor(face: Dictionary, floor_y: float, target: float, edges: Array) -> bool:
	var low := INF
	var high := -INF
	var ends: Array = []
	for point in face.get("points", []):
		var y := float(point[1])
		low = minf(low, y)
		high = maxf(high, y)
		var spot := Vector2(float(point[0]), float(point[2]))
		var seen := false
		for have in ends:
			if (have as Vector2).distance_to(spot) < 1.0:
				seen = true
				break
		if not seen:
			ends.append(spot)
	if ends.size() != 2 or absf(high - floor_y) > 1.0 or low < target - 1.0 or high - low < 1.0:
		return false
	return _end_near_edges(ends[0] as Vector2, edges) and _end_near_edges(ends[1] as Vector2, edges)


## The look of a closed slot that opens (L19 1932, lead 2026-11-14 after Grok cab2): at zero height the pack has no walls
## on its null-neighbour edges, its ceiling shares every point with its floor (so the floor strip took it too), and the
## upper wall standing on its ceiling faces only the neighbour (8553, 1931 edge 1, 0..60). The shell puts back the
## ceiling, closes the null edges from the new floor to the ceiling (material 113, the corridor's) and repeats the upper
## walls for the slot side. Static, drawn both sides, colliding.
func _slot_shell_faces(region: int, faces: Array, floor_y: float, ceiling_y: float, ceiling_edges: Array) -> Array:
	var out: Array = []
	for raw in faces:
		if not raw is Dictionary: continue
		var face: Dictionary = raw
		var kind := str(face.get("kind", ""))
		if kind == "ceiling" and _face_region(face) == region: out.append(face)
		elif kind == "source_wall" and _wall_on_ceiling(face, ceiling_y, ceiling_edges): out.append(face)
	var poly: Array = regions[region][0]
	for i in poly.size():
		var a := Vector2(float(poly[i][0]), float(poly[i][1])); var b := Vector2(float(poly[(i + 1) % poly.size()][0]), float(poly[(i + 1) % poly.size()][1]))
		var mid := (a + b) * 0.5
		var shared := false
		for other in regions.size():
			if other == region: continue
			var q: Array = regions[other][0]
			if q.size() < 3: continue
			var box := Rect2(Vector2(float(q[0][0]), float(q[0][1])), Vector2.ZERO)
			for v in q: box = box.expand(Vector2(float(v[0]), float(v[1])))
			if not box.grow(1.0).has_point(mid): continue
			for j in q.size():
				if _near_segment(mid, Vector2(float(q[j][0]), float(q[j][1])), Vector2(float(q[(j + 1) % q.size()][0]), float(q[(j + 1) % q.size()][1])), 0.5): shared = true; break
			if shared: break
		if shared: continue
		var length := a.distance_to(b) / 128.0
		var tall := (ceiling_y - floor_y) / 128.0
		out.append({"kind": "source_wall", "region": region, "material": "113__front",
			"points": [[a.x, floor_y, a.y], [a.x, ceiling_y, a.y], [b.x, ceiling_y, b.y], [b.x, floor_y, b.y]],
			"uv": [[0.0, tall], [0.0, 0.0], [length, 0.0], [length, tall]]})
	return out

func _add_slot_shell(region: int, face_list: Array, pack: Dictionary) -> void:
	var root: Node3D = get_node_or_null("FloorMotions") as Node3D
	var keep: Variant = floor_decks.get(region)
	floor_decks.erase(region)
	_add_region_deck(region, face_list, pack)
	var shell: Node3D = floor_decks.get(region)
	if keep != null: floor_decks[region] = keep
	else: floor_decks.erase(region)
	if shell == null: return
	shell.name = "Slot%d" % region
	shell.set_meta("slot_shell", true)
	if root != null and shell.get_parent() != root: shell.reparent(root)


func _end_near_edges(point: Vector2, edges: Array) -> bool:
	for edge in edges:
		var pair: Array = edge
		if _near_segment(point, pair[0] as Vector2, pair[1] as Vector2, 2.0):
			return true
	return false


static func _face_region(face: Dictionary) -> int:
	var value: Variant = face.get("region", -1)
	if value is int or value is float:
		return int(value)
	return -1


static func _near_segment(p: Vector2, a: Vector2, b: Vector2, limit: float) -> bool:
	var along := b - a
	var len2 := along.length_squared()
	if len2 < 0.001:
		return p.distance_to(a) <= limit
	var t := clampf((p - a).dot(along) / len2, 0.0, 1.0)
	return p.distance_to(a + along * t) <= limit


func _add_region_deck(region_id: int, face_list: Array, pack: Dictionary) -> void:
	var root: Node3D = get_node_or_null("FloorMotions") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "FloorMotions"
		add_child(root)
	var deck := Node3D.new()
	deck.name = "Floor%d" % region_id
	var native_floor := 0
	if region_id >= 0 and region_id < regions.size():
		native_floor = int(regions[region_id][1])
	deck.set_meta("native_floor", native_floor)
	var grouped: Dictionary = {}
	var points := PackedVector3Array()
	for raw_face in face_list:
		var face: Dictionary = raw_face
		var material_key := str(face.get("material", ""))
		var tool: SurfaceTool
		if grouped.has(material_key):
			tool = grouped[material_key]
		else:
			tool = SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			grouped[material_key] = tool
		for corner in [0, 1, 2, 0, 2, 3]:
			var point: Array = face.points[corner]
			var vertex := Vector3(float(point[0]), float(point[1]), float(point[2]))
			if face.has("uv"):
				var uv: Array = face.uv[corner]
				tool.set_uv(Vector2(float(uv[0]), float(uv[1])))
			tool.add_vertex(vertex)
			points.append(vertex)
	var materials: Dictionary = {}
	var base := str(host.geometry_file).get_base_dir() + "/"
	var images: Dictionary = pack.get("materials", {})
	for material_key in grouped.keys():
		var surface: SurfaceTool = grouped[material_key]
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		if not materials.has(material_key) and images.has(material_key):
			var image := Image.load_from_file(base + str(images[material_key]))
			var material := StandardMaterial3D.new()
			if image != null:
				material.albedo_texture = ImageTexture.create_from_image(image)
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			materials[material_key] = material
		if materials.has(material_key):
			mesh.material_override = materials[material_key]
		deck.add_child(mesh)
	if points.is_empty():
		deck.queue_free()
		return
	var body := AnimatableBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = false
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(points)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	deck.add_child(body)
	root.add_child(deck)
	floor_decks[region_id] = deck


func _strip_static_floor(keys: Dictionary) -> void:
	for child in host.get_children():
		if not child is StaticBody3D or str(child.name) == "ProjectileWalls":
			continue
		for node in child.get_children():
			if not node is CollisionShape3D:
				continue
			var shape_node := node as CollisionShape3D
			if not shape_node.shape is ConcavePolygonShape3D:
				continue
			var source: PackedVector3Array = (shape_node.shape as ConcavePolygonShape3D).get_faces()
			var kept := PackedVector3Array()
			var dropped := false
			var index := 0
			while index + 2 < source.size():
				if keys.has(_floor_point_key(source[index])) and keys.has(_floor_point_key(source[index + 1])) and keys.has(_floor_point_key(source[index + 2])):
					dropped = true
				else:
					kept.append(source[index])
					kept.append(source[index + 1])
					kept.append(source[index + 2])
				index += 3
			if dropped:
				var shape := ConcavePolygonShape3D.new()
				shape.backface_collision = true
				shape.set_faces(kept)
				shape_node.shape = shape
	var meshes: Variant = host.get("static_meshes")
	if not meshes is Array:
		return
	for raw in meshes:
		if raw is MeshInstance3D:
			_strip_floor_mesh(raw as MeshInstance3D, keys)


func _strip_floor_mesh(mesh_instance: MeshInstance3D, keys: Dictionary) -> void:
	var source: Mesh = mesh_instance.mesh
	if source == null or source.get_surface_count() == 0:
		return
	var rebuilt := ArrayMesh.new()
	var changed := false
	for surface_index in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index_raw: Variant = arrays[Mesh.ARRAY_INDEX]
		var indices := PackedInt32Array()
		if index_raw is PackedInt32Array:
			indices = index_raw
		var uv_raw: Variant = arrays[Mesh.ARRAY_TEX_UV]
		var custom_raw: Variant = arrays[Mesh.ARRAY_CUSTOM0]
		var uvs := PackedVector2Array()
		if uv_raw is PackedVector2Array:
			uvs = uv_raw
		var custom := PackedColorArray()
		if custom_raw is PackedColorArray:
			custom = custom_raw
		var use_uv := uvs.size() == vertices.size()
		var use_custom := custom.size() == vertices.size()
		var tool := SurfaceTool.new()
		if use_custom:
			tool.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var material: Material = source.surface_get_material(surface_index)
		if material != null:
			tool.set_material(material)
		var count := indices.size() if not indices.is_empty() else vertices.size()
		var step := 0
		var kept := 0
		while step + 2 < count:
			var ia := indices[step] if not indices.is_empty() else step
			var ib := indices[step + 1] if not indices.is_empty() else step + 1
			var ic := indices[step + 2] if not indices.is_empty() else step + 2
			var a := vertices[ia]
			var b := vertices[ib]
			var c := vertices[ic]
			if keys.has(_floor_point_key(a)) and keys.has(_floor_point_key(b)) and keys.has(_floor_point_key(c)):
				changed = true
			else:
				if use_uv:
					tool.set_uv(uvs[ia])
				if use_custom:
					tool.set_custom(0, custom[ia])
				tool.add_vertex(a)
				if use_uv:
					tool.set_uv(uvs[ib])
				if use_custom:
					tool.set_custom(0, custom[ib])
				tool.add_vertex(b)
				if use_uv:
					tool.set_uv(uvs[ic])
				if use_custom:
					tool.set_custom(0, custom[ic])
				tool.add_vertex(c)
				kept += 1
			step += 3
		if kept == 0:
			continue
		var piece: ArrayMesh = tool.commit()
		var dest := rebuilt.get_surface_count()
		rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, piece.surface_get_arrays(0), [], {}, piece.surface_get_format(0))
		rebuilt.surface_set_material(dest, material)
	if not changed:
		return
	if rebuilt.get_surface_count() == 0:
		mesh_instance.visible = false
		return
	mesh_instance.mesh = rebuilt


func _start_floor(region: int, target: int, rate: int) -> void:
	_claim_region_floor(region, target)
	var current := target
	if floor_motion.has(region):
		current = int((floor_motion[region] as Dictionary).height)
	elif region >= 0 and region < regions.size():
		current = int(regions[region][1])
	var remaining := target - current
	if remaining == 0:
		return
	var motion := {"height": current, "remaining": remaining, "fraction": 0, "speed": maxi(rate, 0)}
	floor_motion[region] = motion
	if rate <= 0:
		motion.height = target
		motion.remaining = 0
		_apply_floor(region, current, target)


func _apply_floor(region: int, old_h: int, new_h: int) -> void:
	if region >= 0 and region < regions.size():
		regions[region][1] = new_h
	if floor_decks.has(region):
		var deck: Node3D = floor_decks[region]
		deck.position.y = float(new_h - int(deck.get_meta("native_floor", old_h)))
	_carry_floor(region, old_h, new_h)


func _carry_floor(region: int, old_h: int, new_h: int) -> void:
	var delta := float(new_h - old_h)
	if delta == 0.0 or host == null or not is_instance_valid(host.get("player")):
		return
	if host.get("flying") == true:
		return
	var player: Node3D = host.player
	var shift: Vector3 = host.native_translation if host.get("native_translation") != null else Vector3.ZERO
	var feet := player.position.y - FLOOR_FOOT
	var on_region := region_at(player.global_position - shift) == region and absf(feet - float(old_h)) < 12.0
	var on_deck := false
	if floor_decks.has(region) and player is CharacterBody3D and (player as CharacterBody3D).is_on_floor():
		var body: Node = (floor_decks[region] as Node3D).get_node_or_null("Collision")
		var point := player.global_position
		var ray := PhysicsRayQueryParameters3D.create(point, point - Vector3.UP * 64.0, 1)
		var hit: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(ray)
		on_deck = body != null and not hit.is_empty() and hit.collider == body
	if on_region or on_deck:
		player.position.y += delta


func floor_checkpoint() -> Dictionary:
	var motions: Dictionary={}
	for region in floor_motion: motions[str(region)]=(floor_motion[region] as Dictionary).duplicate(true)
	return {"version":1,"clock":floor_clock,"motions":motions}

func restore_floor_checkpoint(packet: Dictionary) -> void:
	# Claimed decks stay claimed, but their transforms and navigation heights are
	# reset to the source baseline even when an older save has no floor packet.
	for raw in floor_decks:
		var region:=int(raw)
		var deck: Node3D=floor_decks[region]
		regions[region][1]=int(deck.get_meta("native_floor"))
		deck.position.y=0.0
		deck.force_update_transform()
		var fields: Dictionary=(native.get("state") as Dictionary).get("0x22d0c:%d"%region,{})
		fields.erase(NativeHost.FIELD_FLOOR_TARGET);fields.erase(NativeHost.FIELD_FLOOR_RATE)
	floor_motion.clear();floor_clock=float(packet.get("clock",0.0))
	for key in packet.get("motions",{}):
		var region:=int(str(key))
		var row: Dictionary=packet.motions[key].duplicate(true)
		for field in row: row[field]=int(row[field])
		_claim_region_floor(region,int(row.height)+int(row.remaining))
		floor_motion[region]=row
		regions[region][1]=int(row.height)
		if floor_decks.has(region):
			var deck: Node3D=floor_decks[region]
			deck.position.y=float(int(row.height)-int(deck.get_meta("native_floor")))
			deck.force_update_transform()
		native.set_field("0x22d0c:%d"%region,NativeHost.FIELD_FLOOR_TARGET,int(row.height)+int(row.remaining))
		native.set_field("0x22d0c:%d"%region,NativeHost.FIELD_FLOOR_RATE,int(row.speed))

func advance_floors(delta: float) -> void:
	if floor_motion.is_empty():
		return
	floor_clock += maxf(0.0, delta) * 60.0
	var steps := 0
	while floor_clock >= 1.0 and steps < 8:
		floor_clock -= 1.0
		steps += 1
		for raw in floor_motion.keys():
			var region := int(raw)
			var motion: Dictionary = floor_motion[region]
			if int(motion.remaining) == 0:
				continue
			var old_h := int(motion.height)
			if int(motion.speed) <= 0:
				motion.height = old_h + int(motion.remaining)
				motion.remaining = 0
			else:
				# advance_one is true only when remaining hits 0. Earlier ticks still change height.
				Motion.advance_one(motion, 65536)
			if int(motion.height) != old_h:
				_apply_floor(region, old_h, int(motion.height))
			if int(motion.remaining) == 0 and area_id == "L19_BC" and region == CAB_PLATFORM:
				_cab_arrived(int(motion.height))


## L19 Dawn-shaft cab arrival (adapter l19_cab_arrival, lead 2026-11-14 after Grok da81ea3-dawn: at -1000 the body could
## not leave the cab, the ring's blocker bits stood). The ride groups 1762 (down) and 1964 (up) close doors 51-54, set
## bit 0 (opcode 197 arm 2) on the ring 1935-1942 and move the floors. Stream-0 groups 1118 and 1200 are the two ends:
## each clears those bits (arm 0) and opens its own doors (1118: 51/52 at the top, 1200: 53/54 at the bottom); no record
## in the staged script calls them (their caller is not located - LIKELY the engine's floor-stop). The host runs the
## end's group when the cab's floor motion reaches its target.
const CAB_PLATFORM := 1943
const CAB_ARRIVAL := {-1000: 1200, -100: 1118}
func _cab_arrived(height: int) -> void:
	if native == null or not CAB_ARRIVAL.has(height): return
	# The end groups enqueue prop 97 by opcode 9 arm 0x10, which is not decoded; prop 97's only record is kind 6 caller 6,
	# so that enqueue reaches no record here. The adapter runs the end group without it.
	var group := int(CAB_ARRIVAL[height])
	var commands: Array = []
	for command in native.groups.get(native.group_key(0, group), []):
		var bytes: PackedByteArray = command["bytes"]
		if int(command["opcode"]) == 9 and bytes.size() > 4 and int(bytes[4]) == 0x10: continue
		commands.append(command)
	native.groups[native.group_key(2, group)] = commands
	var result: Dictionary = native.call("execute_group", 2, group)
	route_log.append({"object": "cab_arrival", "event": height, "results": [{"group": int(CAB_ARRIVAL[height]), "status": str(result.get("status", "")), "reasons": result.get("reasons", [])}]})

func _build_hinges() -> void:
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
	var attributes: Dictionary = native.get("attributes")
	var placements: Dictionary = native.get("placements")
	var attached:Dictionary=GenericPrimitives.collect(host,pack,GenericCatalog.movables(area_id))
	for id in mover_ids(native):
		if area_id=="L14_HT" and id in [0,1,55,56,57,72,73,74,75,76,77,78,80,81,85,86,87]:continue # Dedicated bedroom headboard owner.
		if area_id=="L8_SJ" and id==50:continue # Tree shard-slot owner draws and collides this door.
		if area_id=="L12_CM" and id in [50,51,55]:continue # Dedicated original river raft owner.
		if area_id=="L13_RC" and id>=50 and id<=68:continue # L13Altar owns the earned boss gate and its collision.
		var ref := "movable:%d" % id
		if not attributes.has(ref) or not placements.has(ref): continue
		if GenericCatalog.movables(area_id).has(id):
			var initial: Dictionary = GenericRules.initial(placements[ref])
			for field in GenericRules.FIELDS:
				if not native.state.get(ref,{}).has(field):native.set_field(ref,field,int(initial[field]))
		mover_modes[id] = int(attributes[ref].mode)
		var p: PackedByteArray = placements[ref]
		var origin := Vector3(p.decode_s16(0), p.decode_s16(6), -p.decode_s16(2))
		var hinge := Node3D.new()
		hinge.name = "Movable%d" % id
		hinge.position = origin
		var groups: Dictionary = {}
		var room_faces: Array = []
		# Collision is built apart from the drawn mesh (G-05 spot 06-58-50, lead 2026-11-12): a standable flat face (a body
		# height of open space above it within the mover) collides as a thin convex slab; everything else stays a trimesh. On a flush
		# trimesh top Godot's move_and_slide spent all its slides on zero-depth floor contacts and the player could not walk
		# (Citadel vault, Movable83). Meta lol2_mover_trimesh_tops restores the old all-trimesh collision for A/B.
		var flat: Array = []
		var solid := PackedVector3Array()
		var trimesh_tops: bool = host.get_tree().has_meta("lol2_mover_trimesh_tops")
		for face in pack.faces:
			if face.kind != "movable" or str(face.get("placement_kind", "")) != "movable" or int(face.source_index) != id: continue
			room_faces.append(face.points)
			if not groups.has(face.material):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[face.material] = surface
			var local: Array = []
			for point in face.points: local.append(Vector3(point[0], point[1], point[2]) - origin)
			for i in [0, 1, 2, 0, 2, 3]:
				groups[face.material].set_uv(Vector2(face.uv[i][0], face.uv[i][1]))
				groups[face.material].add_vertex(local[i])
			var ys: Array = local.map(func(v: Vector3) -> float: return v.y)
			if not trimesh_tops and local.size() == 4 and float(ys.max()) - float(ys.min()) < 0.5: flat.append(local)
			else:
				for i in [0, 1, 2, 0, 2, 3]: solid.append(local[i])
		var primitives:Array=attached.get(int(id),[])
		if groups.is_empty() and primitives.is_empty():continue
		if not primitives.is_empty():mover_attached[id]=primitives
		var body:AnimatableBody3D
		if not groups.is_empty():
			body=AnimatableBody3D.new()
			body.name="MoverCollision";body.collision_layer=1;body.collision_mask=0;body.sync_to_physics=false
			hinge.add_child(body);mover_bodies[id]=body
		var bounds := AABB()
		var first_mesh := true
		for key in groups:
			var mesh := MeshInstance3D.new()
			mesh.mesh = groups[key].commit()
			bounds = mesh.mesh.get_aabb() if first_mesh else bounds.merge(mesh.mesh.get_aabb())
			first_mesh = false
			if trimesh_tops:
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
		if first_mesh:bounds=GenericPrimitives.bounds(primitives,origin)
		if not trimesh_tops:
			# A flat face is standable when the mover leaves at least a body height above it (STAND_CLEARANCE, the human
			# capsule): the top of a lid, or a cab floor under a roof (R107 m2). A flat face with mover material close above it
			# is an underside (a lintel's soffit, R107 m1) and stays in the trimesh. Only the same mover's flat faces whose
			# footprint covers this face's centre count as "above"/"below".
			for quad in flat:
				var top: float = (quad[0] as Vector3).y
				var centre: Vector3 = ((quad[0] as Vector3) + (quad[1] as Vector3) + (quad[2] as Vector3) + (quad[3] as Vector3)) / 4.0
				var above := INF
				var below := INF
				for other in flat:
					if other == quad or not _flat_covers(other, centre): continue
					var y: float = (other[0] as Vector3).y
					if y > top + 0.5: above = minf(above, y - top)
					elif y < top - 0.5: below = minf(below, top - y)
				if above < STAND_CLEARANCE:
					for i in [0, 1, 2, 0, 2, 3]: solid.append(quad[i])
					continue
				# Down into the mover by up to 4 units, never through the next flat face below or the mover's bottom.
				var depth: float = clampf(minf(top - bounds.position.y, below * 0.5), 0.5, 4.0)
				var slab := ConvexPolygonShape3D.new()
				var points := PackedVector3Array()
				for v in quad: points.append(v); points.append(v - Vector3(0, depth, 0))
				slab.points = points
				var slab_shape := CollisionShape3D.new()
				slab_shape.name = "TopSlab"
				slab_shape.shape = slab
				body.add_child(slab_shape)
			if not solid.is_empty():
				var trimesh := ConcavePolygonShape3D.new()
				trimesh.set_faces(solid)
				var solid_shape := CollisionShape3D.new()
				solid_shape.name = "Sides"
				solid_shape.shape = trimesh
				body.add_child(solid_shape)
		add_child(hinge)
		hinges[id] = hinge
		# Generic parts follow their native room wherever the host draws by rooms.
		# This draw registration does not alter the mover or its collision body.
		if GenericCatalog.movables(area_id).has(id):
			preload("res://scripts/lol2/object_room_visibility.gd").bind(host,hinge,p,room_faces)
		hinge_origin[id] = origin
		mover_bounds[id] = bounds
		travel[id] = int(native.call("field", ref, NativeHost.FIELD_TRAVEL, 0))
		_pose(id)
		project_attached(id)
		_apply_open_bit(id)

## Opcode 9 arm 0x0E sets byte +0x15 bit 0x80. The native continuation that clears the leaf was not entered.
## Only L20 leaves 50 and 51 stay across the opening after travel, so only those two drop collision.
## Other levels keep the body they already had until each door is checked against the longplay.
func _apply_open_bit(id: int) -> void:
	if area_id != "L20_BB" or (id != 50 and id != 51):
		return
	if not mover_bodies.has(id) or native == null:
		return
	var open := int(native.call("field", "movable:%d" % id, "bit_0x15_0x80", 0)) == 1
	mover_bodies[id].collision_layer = 0 if open else 1

## City canal door pairs (template 44, leaves 122-169, pairs 2k/2k+1, each leaf 50 long along z). The placement origin is the
## leaf's middle, so a pair turned there left 25 / 50 / 25 gaps across the 100-wide doorway and the body wedged between an
## open leaf and the frame (Grok 2026-11-16 12:38Z, point 137). Like L10 leaf 127, each leaf turns at its outer end (the
## frame) instead; native travel is unchanged. The hinge side is our choice, not proven (DEVIATIONS 2026-11-16 canal leaves).
const CITY_CANAL_LEAVES := Vector2i(122, 169)
func _canal_leaf_pivot(id: int) -> Vector3:
	# Read the partner from its placement: on a load with open doors the first leaf is posed before its partner is built.
	var placements: Dictionary = native.get("placements")
	var ref := "movable:%d" % (id ^ 1)
	if not placements.has(ref) or not mover_bounds.has(id): return Vector3.ZERO
	var partner_z := -float((placements[ref] as PackedByteArray).decode_s16(2))
	var bounds: AABB = mover_bounds[id]
	return Vector3(0, 0, bounds.end.z if hinge_origin[id].z > partner_z else bounds.position.z)

func _pose(id: int) -> void:
	if not hinges.has(id): return
	var target := Transform3D(Basis(), hinge_origin[id])
	if GenericCatalog.movables(area_id).has(id):
		target = generic_transform(id,native.field("movable:%d"%id,GenericRules.POSITION,0))
	elif int(mover_modes.get(id, MODE_ROTARY)) == MODE_ROTARY:
		target.basis = Basis(Vector3.UP, -float(travel.get(id, 0)) / 65536.0 * TAU)
		if area_id == "L16_CA" and id >= CITY_CANAL_LEAVES.x and id <= CITY_CANAL_LEAVES.y:
			var pivot := _canal_leaf_pivot(id)
			target.origin += pivot - target.basis * pivot
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

const STAND_CLEARANCE := 46.0

## True when the flat quad's footprint (x/z) contains the point's x/z.
static func _flat_covers(quad: Array, point: Vector3) -> bool:
	var polygon := PackedVector2Array()
	for v in quad: polygon.append(Vector2((v as Vector3).x, (v as Vector3).z))
	return Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), polygon)

var generic_legacy_axes:Dictionary={}
func generic_transform(id:int,position:int)->Transform3D:
	if generic_legacy_axes.has(id):
		var row:Dictionary=GenericCatalog.movables(area_id)[id]
		var span:int=GenericRules.distance_word(int(row.mode),int(row.span))
		return Transform3D(Basis(),hinge_origin[id]+generic_legacy_axes[id]*(float(position)/(maxi(1,span)*65536.0)))
	# Owner03-45-34: retain the source closed pose/native travel, but pivot
	# leaf127 at its published edge so its narrow passage stays clear.
	var target := GenericRules.transform_for(int(mover_modes[id]),position,hinge_origin[id])
	if area_id == "L10_DC" and id == 127:
		var pivot := Vector3(0,0,mover_bounds[id].end.z)
		target.origin += pivot - target.basis * pivot
	return target
func project_attached(id:int):
	if mover_attached.has(id) and hinges.has(id):GenericPrimitives.project(mover_attached[id],hinges[id].transform,hinge_origin[id])
var generic_contact_pauses:Dictionary={}
var generic_mover_blocked:Dictionary={}

func advance_movers(delta: float) -> void:
	for id in mover_targets:
		var node: Node3D = hinges[id]
		var before := node.transform
		var generic: bool = GenericCatalog.movables(area_id).has(id)
		if generic:
			var ref: String = "movable:%d"%id
			var state: Dictionary = {}
			for field in GenericRules.FIELDS:state[field]=native.field(ref,field,0)
			var result: Dictionary = GenericRules.tick(state,native.placements[ref],delta)
			generic_mover_blocked[id]=false
			var proposed:Transform3D=generic_transform(id,int(result.state[GenericRules.POSITION]))
			if mover_bodies.has(id) and not proposed.is_equal_approx(before):
				var body_target:Transform3D=node.global_transform*before.affine_inverse()*proposed*mover_bodies[id].transform
				if not preload("res://scripts/lol2/generic_mover_contact.gd").may_advance(host,mover_bodies[id],body_target):
					generic_mover_blocked[id]=true
					generic_contact_pauses[id]=int(generic_contact_pauses.get(id,0))+1
					continue # Keep position/phase/fraction and completion hooks at the last safe pose.
			write_generic_motion(id,result.state)
			if int(result.state[GenericRules.POSITION])==0 and int(result.state[GenericRules.PHASE]) in [0,5]:generic_legacy_axes.erase(id)
			_pose(id)
			for caller in result.callers:fire(ref,6,{"caller_byte":caller,"context":ref})
		var target: Transform3D = mover_targets[id]
		var weight := minf(1.0, maxf(0.0, delta) * 4.0)
		node.transform = target if generic else before.interpolate_with(target, weight)
		if node.transform.is_equal_approx(before): continue
		project_attached(id)
		# The mover body is a child of the hinge. A parent move does not reach the physics server
		# until a later sync, so a walk in this step still hits the old pose.
		if mover_bodies.has(id):
			var body: AnimatableBody3D = mover_bodies[id]
			body.force_update_transform()
			PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, body.global_transform)
		# A convex TopSlab already supplies CharacterBody platform velocity.
		# Carrying the generic lid's rider manually too doubles its displacement.
		# Keep the established manual adapter for the old trimesh-only pilot.
		if generic and mover_bodies.has(id) and mover_bodies[id].has_node("TopSlab"): continue
		# Carry a player standing on this platform through its transform (adapter, no native lift physics claim).
		if mover_bodies.has(id) and is_instance_valid(host.player) and host.player.is_on_floor():
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

static func struck_skipped(ref: String, area: String = "") -> bool:
	if ref in STRUCK_SKIP:
		return true
	if area == "" or not STRUCK_AREA_SKIP.has(area):
		return false
	var rows: Array = STRUCK_AREA_SKIP[area]
	return ref in rows

func _collect_struck() -> void:
	struck_refs.clear()
	struck_durability.clear()
	for ref_v in native.get("objects"):
		var ref := str(ref_v)
		if not (ref.begins_with("movable:") or ref.begins_with("control:")): continue
		if struck_skipped(ref, area_id) or GenericCatalog.rows(area_id).get(ref,{}).get("in_57",false): continue
		var offsets: Array[int] = []
		for rec in native.call("object_records", ref):
			if int(rec.kind) != 9: continue
			offsets.append(int(rec.file_offset))
		if offsets.is_empty(): continue
		struck_refs[ref] = offsets
		struck_durability[ref] = int(native.call("field", ref, NativeHost.FIELD_BYTE26, 0))

func _overlay_struck_bank() -> void:
	var session: Node = preload("res://scripts/lol2/game_session.gd").for_tree(get_tree())
	var row: Dictionary = session.bank_for(area_id)
	if row.is_empty(): return
	var saved: Dictionary = row.get("struck_durability", {})
	for ref_v in saved:
		var ref := str(ref_v)
		if struck_refs.has(ref): struck_durability[ref] = int(saved[ref_v])

func _index_struck_bodies() -> void:
	struck_bodies.clear()
	for id in mover_bodies:
		var ref := "movable:%d" % int(id)
		if struck_refs.has(ref): struck_bodies[mover_bodies[id]] = ref
	var assemblies: Variant = host.get("preview_assemblies")
	if assemblies == null or not is_instance_valid(assemblies): return
	var solids: Dictionary = assemblies.solid_bodies
	for id in solids:
		var ref := "control:%d" % int(id)
		if struck_refs.has(ref): struck_bodies[solids[id]] = ref

## Camera ray of STRIKE_REACH on layer 1. Mover bodies only. Control solids are layer 256.
## A closer layer-2 body stands down so a creature in front keeps the click.
func aimed_struck() -> String:
	if host == null or not is_instance_valid(host.camera): return ""
	var cam: Camera3D = host.camera
	var origin: Vector3 = cam.global_position
	var door_hit: Dictionary = PlayerCombat.aim_ray(host,STRIKE_REACH,1)
	if door_hit.is_empty() or not struck_bodies.has(door_hit.collider): return ""
	var creature_hit: Dictionary = PlayerCombat.aim_ray(host,STRIKE_REACH,2)
	if not creature_hit.is_empty() and origin.distance_to(creature_hit.position) + 0.5 < origin.distance_to(door_hit.position):
		return ""
	return str(struck_bodies[door_hit.collider])

## Human with an empty hand does not strike. Other forms do. The cut masks, remaining durability, and global 0 are adapters.
func strike_ref(ref: String) -> Array:
	if not struck_refs.has(ref): return []
	if not PlayerCombat.may_strike(host,false): return []
	var damage: int = PlayerCombat.damage(host,true)
	if damage <= 0: return []
	var remaining: int = int(struck_durability.get(ref, 0)) - damage
	struck_durability[ref] = remaining
	var results: Array = fire(ref, 9, {
		"word0": CUT_WORD0, "word2": CUT_WORD2, "dword_1e": damage, "dword_26": remaining,
		"global_23331": 0, "context": ref})
	var ran := false
	for row in results:
		if str(row.get("status", "")) == "ran": ran = true
	preload("res://scripts/lol2/combat_feedback.gd").landed(ran)
	_store_struck()
	return results

func _store_struck() -> void:
	var records_out: Dictionary = {}
	var bank: Dictionary = native.get("record_state")
	for ref_v in struck_refs:
		for offset_v in struck_refs[ref_v]:
			var offset := int(offset_v)
			if not bank.has(offset): continue
			var copy: Dictionary = {}
			for field_name in bank[offset]:
				copy[str(field_name)] = int(bank[offset][field_name])
			records_out[str(offset)] = copy
	var fields_out: Dictionary = {}
	var live: Dictionary = native.get("state")
	for ref_v in struck_refs:
		var ref := str(ref_v)
		if not live.has(ref): continue
		var copy: Dictionary = {}
		for field_name in live[ref]:
			copy[str(field_name)] = int(live[ref][field_name])
		fields_out[ref] = copy
	var durability_out: Dictionary = {}
	for ref_v in struck_durability:
		durability_out[str(ref_v)] = int(struck_durability[ref_v])
	var areas: Dictionary = {}
	if host.quest_state.has(STRUCK_KEY) and host.quest_state[STRUCK_KEY] is Dictionary:
		var prior: Dictionary = host.quest_state[STRUCK_KEY]
		if prior.get("areas") is Dictionary: areas = (prior["areas"] as Dictionary).duplicate(true)
	areas[area_id] = {"durability": durability_out, "records": records_out, "fields": fields_out}
	host.quest_state[STRUCK_KEY] = {"version": 1, "areas": areas}

func restore_struck() -> String:
	# Full VM state was restored before geometry build. Keep the old partial packet only for legacy saves.
	var session: Node = preload("res://scripts/lol2/game_session.gd").for_tree(get_tree())
	if session != null and not session.bank_for(area_id).is_empty(): return ""
	if host == null or not host.quest_state.has(STRUCK_KEY): return ""
	var blob: Dictionary = host.quest_state[STRUCK_KEY]
	var areas: Dictionary = blob.get("areas", {})
	if not areas.has(area_id): return ""
	var area: Dictionary = areas[area_id]
	for ref_v in area.get("durability", {}):
		struck_durability[str(ref_v)] = int(area["durability"][ref_v])
	var bank: Dictionary = native.get("record_state")
	var records: Dictionary = area.get("records", {})
	for offset_text in records:
		var rewritten: Dictionary = {}
		for field_name in records[offset_text]:
			rewritten[str(field_name)] = int(records[offset_text][field_name])
		bank[int(offset_text)] = rewritten
	for ref_v in area.get("fields", {}):
		var ref := str(ref_v)
		var fields: Dictionary = area["fields"][ref_v]
		for field_name in fields:
			var value := int(fields[field_name])
			native.call("set_field", ref, str(field_name), value)
			if str(field_name) == NativeHost.FIELD_TRAVEL and ref.begins_with("movable:"):
				var id := int(ref.get_slice(":", 1))
				travel[id] = value
				_pose(id)
	return ""

static func _number(value: Variant) -> bool:
	return value is int or value is float

static func validate_struck(state: Variant, _quests: Variant) -> String:
	if typeof(state) != TYPE_DICTIONARY: return "Invalid struck state."
	var blob: Dictionary = state
	if int(blob.get("version", -1)) != 1 or blob.size() != 2 or typeof(blob.get("areas")) != TYPE_DICTIONARY:
		return "Invalid struck state."
	for area_v in blob["areas"]:
		var area: Variant = blob["areas"][area_v]
		if typeof(area) != TYPE_DICTIONARY: return "Invalid struck state."
		var row: Dictionary = area
		if row.size() != 3 or not row.has("durability") or not row.has("records") or not row.has("fields"):
			return "Invalid struck state."
		if typeof(row["durability"]) != TYPE_DICTIONARY or typeof(row["records"]) != TYPE_DICTIONARY or typeof(row["fields"]) != TYPE_DICTIONARY:
			return "Invalid struck state."
		for ref_v in row["durability"]:
			if not _number(row["durability"][ref_v]): return "Invalid struck state."
		for offset_v in row["records"]:
			var rewritten: Variant = row["records"][offset_v]
			if typeof(rewritten) != TYPE_DICTIONARY: return "Invalid struck state."
			for field_name in rewritten:
				if not _number(rewritten[field_name]): return "Invalid struck state."
		for ref_v in row["fields"]:
			var fields: Variant = row["fields"][ref_v]
			if typeof(fields) != TYPE_DICTIONARY: return "Invalid struck state."
			for field_name in fields:
				if not _number(fields[field_name]): return "Invalid struck state."
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if host == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or get_tree().paused or host.get("flying"): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit_ref := aimed_struck()
		if hit_ref != "":
			# A real swing at a struck body consumes the click. An empty hand returns nothing and leaves the click.
			if not strike_ref(hit_ref).is_empty():
				get_viewport().set_input_as_handled()
				return
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
