extends SceneTree
## Owner r17 17-36-46 at Jungle (-5761, 4004): "cant hear what she is saying". Region 2842 starts Dawn's
## talk and places the player on that spot. The voice has to be on her body, inside max_distance, and the line has to come through.
const Form := preload("res://scripts/lol2/player_form_body.gd")
const DawnScript := preload("res://scripts/lol2/jungle_dawn.gd")
const TALK := Vector2(-5761.0, 4004.0)
var scene

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL dawn voice: ", message)
	quit(1)

func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for _i in 1500:
		await process_frame
		if scene.get("ready_for_review"):
			break
	if not scene.get("ready_for_review"):
		fail("Jungle not ready")
		return
	var dawn := scene.get_node("JungleDawn") as DawnScript
	if dawn == null:
		fail("Dawn is not in the Jungle")
		return
	if not scene.quest_state.has("monastery"):
		scene.quest_state.monastery = preload("res://scripts/lol2/monastery_quest_state.gd").initial()
	var globals: Dictionary = scene.quest_state.monastery.globals
	globals["GV_HAS_RUNES"] = 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not scene.starting_magic.world_active():
		fail("World not active, so her talk clock would stay stopped")
		return
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.add_bus_effect(bus, capture)
	if not await walk_into(dawn, 2812):
		fail("Did not walk into Dawn's clearing")
		return
	await physics_frame
	if not dawn.state.present:
		fail("Dawn did not appear after the walk into region 2812")
		return
	if not await walk_into(dawn, 2842):
		fail("Did not walk into Dawn's talk")
		return
	await physics_frame
	var body: CharacterBody3D = scene.player
	var at := Vector2(body.global_position.x, body.global_position.z)
	if at.distance_to(TALK) > 2.0:
		fail("Talk did not place the player at (-5761, 4004), stood at %s" % at)
		return
	body.rotation.y = -0.699
	scene.camera.rotation = Vector3(-0.112, 0.0, 0.0)
	var voice: AudioStreamPlayer3D = dawn.voice
	if not voice.playing or voice.stream_paused or bool(dawn.state.clip.repeat) or int(dawn.state.clip.segment) != 1:
		fail("Talk line is not playing (segment %s playing %s paused %s)" % [dawn.state.clip.get("segment", -1), voice.playing, voice.stream_paused])
		return
	var actor := dawn.population.bodies["63"] as Node3D
	if actor == null:
		fail("Dawn has no body")
		return
	var mouth: Vector3 = actor.global_position + Vector3.UP * 40.0
	if voice.global_position.distance_to(mouth) > 1.0:
		fail("Voice is at %s, not on Dawn" % voice.global_position)
		return
	var heard: float = scene.camera.global_position.distance_to(voice.global_position)
	if heard > voice.max_distance:
		fail("Voice is %s away, past max_distance %s" % [heard, voice.max_distance])
		return
	if scene.camera.global_position.length() <= voice.max_distance:
		fail("The origin is inside max_distance from this spot, so the old voice placement would still be heard")
		return
	var reached := false
	for _i in 240:
		await process_frame
		if voice.get_playback_position() >= 5.0:
			reached = true
			break
	if not reached:
		fail("Playback stayed at %s and never reached the words" % voice.get_playback_position())
		return
	var discard := capture.get_frames_available()
	if discard > 0:
		capture.get_buffer(discard)
	for _i in 20:
		await process_frame
	var frames := capture.get_frames_available()
	if frames < 64:
		fail("No mix at the talk spot (driver %s, frames %s)" % [AudioServer.get_driver_name(), frames])
		return
	var samples := capture.get_buffer(frames)
	var peak := 0.0
	for index in samples.size():
		var sample: Vector2 = samples[index]
		peak = maxf(peak, absf(sample.x))
		peak = maxf(peak, absf(sample.y))
	if peak < 0.02:
		fail("The line at (-5761, 4004) is silent, peak %s" % peak)
		return
	print("PASS dawn voice: walked into her talk and heard the line at (-5761,4004)")
	quit(0)

func floor_of(dawn: DawnScript, region: int) -> float:
	var regions: Array = dawn.src.regions
	for row in regions:
		if int(row.region) == region:
			return float(row.floor_min)
	return -100.0

func polygon_of(dawn: DawnScript, region: int) -> PackedVector2Array:
	var poly := PackedVector2Array()
	var regions: Array = dawn.src.regions
	for row in regions:
		if int(row.region) != region:
			continue
		var points: Array = row.polygon
		for point in points:
			poly.append(Vector2(point[0], point[1]))
	return poly

func plant(at: Vector2, floor_y: float) -> void:
	var body: CharacterBody3D = scene.player
	var top := Vector3(at.x, floor_y + 30.0, at.y)
	var query := PhysicsRayQueryParameters3D.create(top, top - Vector3.UP * 80.0, 1, [body.get_rid()])
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
	var ground: float = floor_y
	if not hit.is_empty() and absf(hit.position.y - floor_y) <= 8.0:
		ground = hit.position.y
	body.global_position = Vector3(at.x, ground + Form.FOOT_OFFSET, at.y)
	body.velocity = Vector3.ZERO

func walk_into(dawn: DawnScript, region: int) -> bool:
	var poly := polygon_of(dawn, region)
	if poly.is_empty():
		return false
	var center := Vector2.ZERO
	var start := Vector2.ZERO
	if region == 2842:
		# The centroid's south side is the bank at height 15, and a wall closes that edge.
		# The open side is the river floor. The owner's spot sits on it, just outside the talk.
		center = Vector2(-5780.0, 4050.0)
		start = TALK
	else:
		for point in poly:
			center += point
		center /= float(poly.size())
		start = center
		var guard := 0
		while Geometry2D.is_point_in_polygon(start, poly) and guard < 40:
			start.y -= 40.0
			guard += 1
	plant(start, floor_of(dawn, region))
	for _i in 8:
		await physics_frame
	var body: CharacterBody3D = scene.player
	var stuck := 0
	var previous := body.global_position
	var floor_y: float = floor_of(dawn, region)
	for _step in 500:
		if Geometry2D.is_point_in_polygon(Vector2(body.global_position.x, body.global_position.z), poly):
			return true
		var flat := center - Vector2(body.global_position.x, body.global_position.z)
		await physics_frame
		scene.move_grounded(Vector3(flat.x, 0.0, flat.y).normalized(), 1.0 / 60.0)
		var foot: float = body.global_position.y - Form.FOOT_OFFSET
		if absf(foot - floor_y) > 3.0:
			body.global_position.y = floor_y + Form.FOOT_OFFSET
			body.velocity = Vector3.ZERO
		if body.global_position.distance_to(previous) < 0.05:
			stuck += 1
			if stuck >= 40:
				return false
		else:
			stuck = 0
			previous = body.global_position
	return false
