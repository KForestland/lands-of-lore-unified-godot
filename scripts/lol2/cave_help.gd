extends Node
## L1_DC help triggers (scripts/lol2/cave_help_source.json, docs/help-system.md). Each native record runs one op2
## help sub; the shared HUD help_system.gd applies the native gate (enabled + one-time bit).
## - topic 1 inventory: first pickup of a crystal (props 144-149, 641 kind4), the Stone (control75 kind4) or actor loot
##   (captain56 kind3 and 21 actor groups): watched as a rise in those carried items (no generic world items, no Aloe);
## - topics 2/6/8: first sighting (kind5) of props 927/1219/1363 (camera frustum + clear ray within 1600, the same
##   adapter as the Jungle prop552/554/3235 producers);
## - topic 3 magic: first sighting of captain56 (kind5) while he is present;
## - topic 7 looking around: grounded entry into region1077 (kind4 value0).
## Not hosted: prop422 timer (topic 4; its starter is untraced). Saved in the Cave save as "help".
const SOURCE := "res://scripts/lol2/cave_help_source.json"
var host: Node3D
var src: Dictionary = {}
var last_items := -1
var in_region := false

static func source() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SOURCE)) if FileAccess.file_exists(SOURCE) else null
	return data if data is Dictionary else {}

func setup(owner_host: Node3D) -> String:
	host = owner_host
	name = "CaveHelp"
	src = source()
	return "" if not src.is_empty() else "Cave help source missing."

func help() -> Node:
	var hud = host.get("interface_hud")
	if hud == null or not is_instance_valid(hud): return null
	var h = hud.get("help")
	return h if h != null and is_instance_valid(h) else null

## Items whose native pickup records run sub 0x29.
func trigger_items() -> int:
	var count: int = host.stalagmites.collected.size() if host.get("stalagmites") != null else 0
	if host.get("stone_manafoil") != null: count += host.stone_manafoil.collected.size()
	if host.get("captain") != null: count += preload("res://scripts/lol2/cave_captain_items.gd").from_checkpoint(host.captain.state).size()
	for loot_name in ["guard38_loot", "guard39_loot", "guard54_loot"]:
		var loot = host.get(loot_name)
		if loot != null: count += loot.carried(loot.state).size()
	for loot_name in ["guard52_loot", "guard53_loot"]:
		var loot = host.get(loot_name)
		if loot != null: count += loot.carried(loot.state, loot.actor).size()
	return count

## Reset the pickup baseline after a load so restored items do not count as new pickups.
func rebase() -> void:
	last_items = trigger_items()
	in_region = _inside_region()

func visible_point(point: Vector3, exclude: Array) -> bool:
	var eye: Vector3 = host.camera.global_position
	if eye.distance_to(point) > float(src.sight_distance) or not host.camera.is_position_in_frustum(point): return false
	var ray := PhysicsRayQueryParameters3D.create(eye, point, 1, [host.player.get_rid()] + exclude)
	return host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _inside_region() -> bool:
	if not host.player.is_on_floor(): return in_region
	var r: Dictionary = src.region
	var p: Vector3 = host.player.global_position - host.native_translation
	var foot := p.y - 32.0
	if foot < float(r.floor_min) - 4.0 or foot > float(r.floor_max) + 4.0: return false
	var polygon := PackedVector2Array()
	for point in r.polygon: polygon.append(Vector2(point[0], point[1]))
	return Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), polygon)

func advance() -> void:
	var h := help()
	if h == null or src.is_empty(): return
	var items := trigger_items()
	if last_items >= 0 and items > last_items: h.request(1)
	last_items = items
	var inside := _inside_region()
	if inside and not in_region: h.request(int(src.region.topic))
	in_region = inside
	var seen := int(h.state.seen)
	for record in src.sighted:
		var row: Dictionary = src.sighted[record]
		if seen & (1 << (int(row.topic) - 1)): continue
		var point: Vector3 = host.native_translation + Vector3(row.position[0], float(row.position[1]) + float(row.height) * 0.5, row.position[2])
		if visible_point(point, []): h.request(int(row.topic))
	if not seen & (1 << 2):
		var population = host.get("guard_population")
		if population != null and is_instance_valid(population) and population.state.actors.has("56") and population.bodies.has("56"):
			var actor: Dictionary = population.state.actors["56"]
			var body: Node3D = population.bodies["56"]
			if bool(actor.present) and int(actor.health) > 0 and visible_point(body.global_position + Vector3.UP * 40, [body.get_rid()]):
				h.request(3)

func _physics_process(_delta: float) -> void:
	if host == null or not host.get("walkthrough_ready") or host.get_tree().paused: return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	advance()
