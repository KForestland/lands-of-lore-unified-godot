extends SceneTree
## L14 Temple doors 92/93 (lead 2026-11-13; owner r19g bundle 14-08-18 "cant opend doors can cheat around tho"; Grok's note
## grok_research/OWNER_R19G_REPORTS_20261113.md). With the Dreamstone slot unset the doors stand closed, but he walked
## round the east end of door 92: on the ritual's lower-room ceiling sheet (y 20) he crossed wall 792 edge 1 and wall 957
## edge 1, which meet at the door's east jamb (2483, -3025). Both are null-neighbour edges in the original (the
## impassable side); neither collided. They are now named in scripts/lol2/height_boundary/L14_HT.json (block_face_keys).
## Real input (W held, mouse captured) from his own save and his own stand at t 371.511, steered along his own path:
##  (a) round the east jamb: held south of the door plane (z <= -3020);
##  (b) control: straight at door 92 on the hall floor: held by the closed door;
##  (c) in front of the doors (lead 2026-11-14): the lower-room ceiling 781 at y 20 no longer pokes above the floor-0
##      hall (tools/build_l14_ritual_ceiling_collision.py HALL_CEILINGS): from his stand at t 369.465 (h 52, feet 20)
##      the body settles on the hall floor, and W along his own path before the doors keeps the feet at the floor.
## Test aids: the start pose (his trace) and the heading set each frame toward the next point of his path.
const SAVE := "res://tests/fixtures/l14_owner_door92_save_140818.json"
const PATH := [Vector2(2492.8, -3062.4), Vector2(2499.1, -3027.1), Vector2(2495.7, -2991.3), Vector2(2492.3, -2955.4), Vector2(2488.6, -2917.2)]
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	printerr("FAIL l14 door92 around: ", m)
	quit(1)
func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = down
	Input.parse_input_event(e); Input.flush_buffered_events()
func face(scene: Node, to: Vector2) -> void:
	var p: Vector3 = scene.player.global_position
	scene.player.rotation.y = atan2(-(to.x - p.x), -(to.y - p.z))
func walk(scene: Node, points: Array, ticks: int) -> float:
	var i := 0
	var north := -INF
	key(KEY_W, true)
	for t in ticks:
		var p: Vector3 = scene.player.global_position
		if i < points.size() - 1 and Vector2(p.x, p.z).distance_to(points[i]) < 6.0: i += 1
		face(scene, points[i])
		await physics_frame
		north = maxf(north, scene.player.global_position.z)
	key(KEY_W, false)
	for t in 5: await physics_frame
	return north
func place(scene: Node, at: Vector3) -> void:
	scene.tracked_region = -1
	scene.player.global_position = at; scene.player.velocity = Vector3.ZERO
	for t in 20: await physics_frame
func run() -> void:
	set_meta("original_game_verified", true)
	var old := current_scene
	var err: String = load("res://scripts/lol2/game_save.gd").load_file(self, ProjectSettings.globalize_path(SAVE))
	if not err.is_empty(): return fail("owner save: " + err)
	for i in 1500:
		await process_frame
		if is_instance_valid(current_scene) and current_scene != old and current_scene.get("player") is Node3D and current_scene.is_node_ready(): break
	var scene: Node = current_scene
	for i in 30: await physics_frame
	if str(scene.name) != "MapL14_HT": return fail("owner save opened " + str(scene.name))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# (a) his stand at t 371.511 (h 52.05 on the y 20 sheet), then his path round the east jamb
	await place(scene, Vector3(2458.8, 52.05, -3078.8))
	var na: float = await walk(scene, PATH, 360)
	var pa: Vector3 = scene.player.global_position
	print("DOOR92 (a) furthest north z %.1f, end %s" % [na, str(pa)])
	if na > -3020.0: return fail("(a) round the east end of door 92: reached z %.1f (end %s)" % [na, str(pa)])
	# (b) control: at door 92 on the hall floor
	await place(scene, Vector3(2450, 32.5, -3070))
	var nb: float = await walk(scene, [Vector2(2450, -2990)], 240)
	print("DOOR92 (b) furthest north z %.1f" % nb)
	if nb > -3020.0: return fail("(b) the closed door 92 let the body through to z %.1f" % nb)
	# (c) the y 20 sheet in front of the doors
	await place(scene, Vector3(2468.2, 52.05, -3060.4))
	for t in 40: await physics_frame
	var settled: float = scene.player.global_position.y - 32.0
	print("DOOR92 (c) feet after settling %.1f" % settled)
	if settled > 4.0: return fail("(c) standing on the y 20 sheet before the doors: feet %.1f" % settled)
	var high := -INF
	key(KEY_W, true)
	var hall := [Vector2(2456.2, -3044.4), Vector2(2432.4, -3050.1), Vector2(2418.3, -3060.2), Vector2(2423.0, -3091.9), Vector2(2458.8, -3078.8)]
	var i := 0
	for t in 300:
		var p: Vector3 = scene.player.global_position
		if i < hall.size() - 1 and Vector2(p.x, p.z).distance_to(hall[i]) < 6.0: i += 1
		face(scene, hall[i])
		await physics_frame
		if scene.player.is_on_floor(): high = maxf(high, scene.player.global_position.y - 32.0)
	key(KEY_W, false)
	print("DOOR92 (c) highest grounded feet along his path %.1f" % high)
	if high > 4.0: return fail("(c) the hall before the doors still holds the body at feet %.1f" % high)
	print("PASS l14 door92 around: owner's way round the east jamb held at z %.1f; closed door 92 holds at z %.1f; hall before the doors at floor (feet %.1f)" % [na, nb, high])
	quit(0)
