extends SceneTree
## Owner r18 15-26-05 at Jungle (3539,-4154): "cant hear him barrcata".
## Walk west-to-east into link region 1921 (the south edge is a bit0 wall), then along the
## open floor to a stand west of prop 552, press E, and wait until actor 61 speaks.
## The listener then stands at the reported pose. The line has to be on his body and inside max_distance.
const REPORT := Vector3(3539.875, 32.0, -4154.008)
## Region 1951 floor, just west of region 1921. Region 1912, to the south, is player-blocked.
const LINK_OUTSIDE := Vector3(2306.0, 32.0, -4672.0)
## Open floor on region 3781, outside talk range, with a clear line to the stand.
const TALK_START := Vector3(3312.0, 32.0, -3712.0)
## Open floor on region 3785, west of prop 552. The ground north and east of him is blocked.
const TALK_STAND := Vector3(3520.0, 32.0, -4136.0)
var scene
var ctrl
var exit

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func region_point(region: int) -> Vector3:
	for row in ctrl.src.regions:
		if int(row.region) != region:
			continue
		var centre := Vector2.ZERO
		for point in row.polygon:
			centre += Vector2(point[0], point[1])
		centre /= float(row.polygon.size())
		return Vector3(centre.x, 32.0, centre.y) + ctrl.origin()
	return Vector3.ZERO

func placed(point: Vector3) -> Vector3:
	return point + ctrl.origin()

func walk_to(goal: Vector3, stop_at: float) -> void:
	var stuck: int = 0
	var previous: Vector3 = scene.player.global_position
	for _tick in 1200:
		var delta: Vector3 = goal - scene.player.global_position
		delta.y = 0.0
		if delta.length() < stop_at:
			return
		scene.move_grounded(delta.normalized(), 1.0 / 60.0)
		await physics_frame
		var step: float = Vector2(scene.player.global_position.x - previous.x, scene.player.global_position.z - previous.z).length()
		previous = scene.player.global_position
		if step < 0.05:
			stuck += 1
		else:
			stuck = 0
		if stuck >= 40:
			return

func look_at_prop() -> void:
	var mouth: Vector3 = ctrl.prop_body.global_position + Vector3.UP * 45.0
	if mouth.distance_to(scene.camera.global_position) > 0.1:
		scene.camera.look_at(mouth)

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
	ctrl = scene.bacatta
	exit = scene.exit_encounter
	if ctrl == null or exit == null:
		fail("Bacatta or the exit encounter is missing")
		return
	scene.set_physics_process(false)
	ctrl.set_physics_process(false)
	exit.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.flying = false
	scene.player_form = 0
	if not scene.quest_state.has("monastery"):
		scene.quest_state.monastery = {}
	if not scene.quest_state.monastery.has("globals"):
		scene.quest_state.monastery.globals = {}
	var globals: Dictionary = scene.quest_state.monastery.globals
	globals["GV_RUNES_TRANSLATED"] = 1
	globals["GV_MET_BACATTA"] = 1
	globals["GV_BACATTA_RELATIONSHIP"] = 1
	globals["GV_LUTHERS_SOUL"] = 4
	globals["GV_DAWN_RELATIONSHIP"] = 3
	scene.quest_state.weapon_shop.globals["GV_LUTHER_KNOWS_ABOUT_DANIEL"] = 0
	if not scene.starting_magic.world_active():
		fail("World not active, so his talk clock would stay stopped")
		return
	scene.player.global_position = placed(LINK_OUTSIDE)
	scene.player.velocity = Vector3.ZERO
	await walk_to(region_point(1921), 8.0)
	ctrl.advance(1.0 / 30.0)
	if 1921 not in ctrl.inside:
		fail("The walk did not enter region 1921 at %s" % scene.player.global_position)
		return
	var departed: Vector3 = placed(TALK_START)
	if ctrl.prop_body.global_position.distance_to(departed) < 96.0:
		fail("The talk walk starts inside reach")
		return
	scene.player.global_position = departed
	scene.player.velocity = Vector3.ZERO
	await walk_to(placed(TALK_STAND), 8.0)
	look_at_prop()
	await physics_frame
	exit._visible_spawn()
	ctrl.advance(1.0 / 30.0)
	if not ctrl.state.prop552.present:
		fail("Prop 552 did not appear after the link and the sighting")
		return
	look_at_prop()
	await physics_frame
	if not ctrl.can_use():
		fail("The walk did not reach Bacatta, distance %s at %s" % [ctrl.prop_body.global_position.distance_to(scene.player.global_position), scene.player.global_position])
		return
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	ctrl._unhandled_input(key)
	var speaker := ""
	for _step in 1200:
		ctrl.advance(1.0 / 30.0)
		for name in ["prop552", "bacatta"]:
			var candidate: AudioStreamPlayer3D = ctrl.voices[name]
			if candidate.playing and not candidate.stream_paused:
				speaker = name
				break
		if speaker != "":
			break
	if speaker == "":
		fail("No line started (prop %s, actor 61 %s)" % [ctrl.state.prop552.clip, ctrl.state.bacatta.clip])
		return
	scene.player.global_position = REPORT
	scene.player.velocity = Vector3.ZERO
	scene.camera.rotation = Vector3(-0.121, -1.913, 0.0)
	await physics_frame
	var voice: AudioStreamPlayer3D = ctrl.voices[speaker]
	if not voice.playing or voice.stream_paused:
		fail("The line stopped before the reported pose")
		return
	var anchor: Variant = ctrl._owner_anchor(speaker)
	if not anchor is Vector3:
		fail("No body for %s" % speaker)
		return
	var mouth: Vector3 = (anchor as Vector3) + Vector3.UP * 40.0
	if voice.global_position.distance_to(mouth) > 1.0:
		fail("Voice is at %s, not on %s" % [voice.global_position, speaker])
		return
	var heard: float = scene.camera.global_position.distance_to(voice.global_position)
	if heard > voice.max_distance:
		fail("Voice is %s away, past max_distance %s" % [heard, voice.max_distance])
		return
	if REPORT.length() <= voice.max_distance:
		fail("The origin is inside max_distance from this spot, so the old voice placement would still be heard")
		return
	if voice.unit_size != 300.0 or voice.max_distance != 1200.0 or voice.attenuation_model != AudioStreamPlayer3D.ATTENUATION_DISABLED:
		fail("Reach changed (unit %s max %s model %s)" % [voice.unit_size, voice.max_distance, voice.attenuation_model])
		return
	if voice.bus != "Master":
		fail("Voice bus is %s" % voice.bus)
		return
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.add_bus_effect(bus, capture)
	var discard := capture.get_frames_available()
	if discard > 0:
		capture.get_buffer(discard)
	for _i in 20:
		await process_frame
	var frames := capture.get_frames_available()
	if frames < 64:
		fail("No mix at (3539,-4154) (driver %s, frames %s)" % [AudioServer.get_driver_name(), frames])
		return
	var samples := capture.get_buffer(frames)
	var peak := 0.0
	for index in samples.size():
		var sample: Vector2 = samples[index]
		peak = maxf(peak, absf(sample.x))
		peak = maxf(peak, absf(sample.y))
	if peak < 0.02:
		fail("The line at (3539,-4154) is silent, peak %s" % peak)
		return
	print("PASS bacatta voice: walked up, pressed E, and heard %s at (3539,-4154)" % speaker)
	quit(0)
