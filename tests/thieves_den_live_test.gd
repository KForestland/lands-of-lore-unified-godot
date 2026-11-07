extends SceneTree
## Rendered, actual Jungle host, real GUI input (docs/thieves-den.md): the yard opens from region 3642 and shows its
## looping background; real clicks on the boards, the cellar door, the slot door and Mauri's shelf drive the chain
## (CELLAR walk-in frames, the password clips with audio, Mauri's idle and talking heads, the two THFSHAPE sprites
## until taken); the Back button leaves; a mid-line disk save resumes the same frame; the alert escape plays TINTTRAN
## and lands Luther outside the palisade, standing on the floor after physics.
const State = preload("res://scripts/lol2/thieves_den_state.gd")
const YARD := Vector3(-2421,32,-5346)
const PAINT := "jungle:thieves_den:Pois_paint"
const KEY := "jungle:thieves_den:Skull_key"
var jungle
var den
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		push_error("FAIL: "+label)
	return ok
func s() -> Dictionary: return den.state()
func lines() -> Array:
	var out: Array = []
	var st := s()
	if not State.script_active(st): return out
	for e in State.script_effects(st.script.handler,st.script.args):
		if e[0] in ["movie","movie_flags"]: out.append(int(e[2]))
		elif e[0] == "reply": out.append("L%d" % int(e[1]))
		elif e[0] == "load_room": out.append(str(e[1]))
	return out
## A real left click at a 640x400 canvas point, through the viewport input path.
func gui_click(canvas_point: Vector2) -> void:
	var point: Vector2 = den.input_layer.get_global_transform_with_canvas() * canvas_point
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	root.push_input(motion)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position = point; event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		root.push_input(event)
	await process_frame
func gui_back() -> void:
	var point: Vector2 = den.back.get_global_transform_with_canvas() * (den.back.size*0.5)
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	root.push_input(motion)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position = point; event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		root.push_input(event)
	await process_frame
func settle() -> void:
	for i in range(64):
		den.advance(1000.0)
		if not State.active(s()): break
	await process_frame
func open(room: String) -> bool:
	for i in range(100000):
		if s().room == room and (State.script_active(s()) or i > 0): return true
		den.advance(0.25)
		if not den.active() and s().room != room: return false
	return s().room == room
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/thieves_den_%s.png" % name)
func set_met_confidant(value: int) -> void:
	var c = jungle.get("confidante")
	if c != null and is_instance_valid(c) and c.get("state") is Dictionary and not c.state.is_empty(): c.state.locals["27"] = value
	else: jungle.quest_state.jungle_confidante = {"version":1,"state":{"locals":{"27":value}},"inside":[]}
func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in range(5): await process_frame
	jungle.set_physics_process(false)
	den = jungle.thieves_den
	if not check(den != null and den.available,"den layer missing or media not staged (tools/prepare_thieves_den_media.py)"): return finish()
	den.set_process(false)
	for key in ["monastery","magic_shop","weapon_shop"]:
		var other = jungle.get(key)
		if is_instance_valid(other): other.set_process(false)
	for key in ["bacatta57","dino_population"]:
		var owner = jungle.get(key)
		if owner != null and is_instance_valid(owner): owner.set_physics_process(false); owner.set_process(false)
	jungle.quest_state.thieves_den = State.initial(); den.restore()
	jungle.carried_collected.clear(); set_met_confidant(1)
	jungle.quest_state.monastery.globals["GV_KELSRICK_DEAD"] = 0
	if is_instance_valid(jungle.get("village_gate")): jungle.village_gate.state().shared29 = 0
	# The yard from region 3642: looping background, no patch, mouse visible.
	jungle.player.position = YARD; den.was_inside = false; den._process(0.0)
	check(den.active() and s().room == "TEXT" and den.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"region 3642 opens the yard")
	await process_frame; await process_frame
	check(den.view.background.is_playing() and den.view.patch.texture == null,"yard background loops without a patch")
	await shot("yard")
	# Real clicks: the boards, then the cellar walk-in frames.
	await gui_click(Vector2(400,280))
	check(open("TCEL") and lines() == ["CELLAR"],"GUI boards click -> cellar with the walk-in")
	await process_frame
	check(den.view.patch.texture != null and den.view.voice.playing and den.view.patch.size == Vector2(640,400),"CELLAR frames and audio on screen")
	await shot("cellar_walk_in")
	await settle()
	check(den.view.patch.texture == null and den.view.background.is_playing(),"cellar background after the walk-in")
	await gui_click(Vector2(300,230))
	check(open("TDOOR"),"GUI cellar door -> slot door")
	await settle()
	await gui_click(Vector2(300,250))
	check(lines() == [475,476] and den.view.voice.playing,"GUI knock: 475 playing with audio")
	den.advance(1.0); await process_frame
	check(den.view.last_frame == 15 or den.view.last_frame == 14,"475 at frame 15 after one second: %d" % den.view.last_frame)
	await shot("door_475")
	# Mid-line disk save resumes the same frame.
	var path := "user://tests/thieves_den_live.json"
	var before: Dictionary = JSON.parse_string(JSON.stringify(s()))
	check(jungle.quicksave(path).is_empty(),"save during 475")
	den.advance(3.0)
	check(jungle.quickload(path).is_empty(),"load during 475")
	den = jungle.thieves_den
	await process_frame
	check(JSON.parse_string(JSON.stringify(s())) == before and den.view.last_frame in [14,15] and den.view.voice.playing,"resume at the saved frame with audio")
	check(open("TINT") and lines().slice(0,2) == [401,477],"Mauri's den after the door")
	await process_frame
	check(den.sprite_nodes[0].visible and den.sprite_nodes[1].visible and den.held.visible,"shelf sprites and the hand selector shown")
	den.advance(State.clip_duration("TINT",["movie",1,401,10])+0.5); await process_frame
	check(den.view.patch.texture != null and den.view.patch.position == Vector2(332,108),"Mauri's 477 talking head at its source position")
	await shot("mauri_477")
	await settle()
	check(den.view.clip.get("idle",false) and den.view.patch.position == Vector2(332,116),"Mauri's idle loop between lines")
	# Real clicks on the shelf: both items into the pack, sprites gone.
	await gui_click(Vector2(550,165))
	check(lines() == [502,503],"GUI Poison Paint click")
	await settle()
	await gui_click(Vector2(600,150))
	check(lines() == [29],"GUI Skull Key click")
	await settle()
	check(PAINT in jungle.carried_collected and KEY in jungle.carried_collected and not den.sprite_nodes[0].visible and not den.sprite_nodes[1].visible,"both items taken, sprites hidden")
	await shot("den_emptied")
	# The Back button (callback 8): farewell, then the cellar.
	await gui_back()
	check(lines() == [507,508],"GUI Back: farewell")
	check(open("TCEL") and not State.script_active(s()),"back in the cellar")
	await gui_back(); open("TEXT"); await gui_back()
	check(not den.active() and jungle.is_physics_processing() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"out in the village again")
	# Alert escape: the tunnel walk, then standing on the floor outside the palisade.
	jungle.quest_state.monastery.globals["GV_KELSRICK_DEAD"] = 1
	if is_instance_valid(jungle.get("village_gate")): jungle.village_gate.state().shared29 = 1
	jungle.player.position = YARD; den.was_inside = false; den._process(0.0)
	await settle()
	await gui_click(Vector2(400,280)); open("TCEL"); await settle()
	await gui_click(Vector2(300,230)); open("TDOOR"); await settle()
	await gui_click(Vector2(300,250))
	check(open("TINT") and lines() == [600,"L600",601,603,"L603",604,"L604",605,606],"alert Firestorm scene: %s" % [lines()])
	await settle()
	check(int(s().flags["18"]) == 1,"tunnel free")
	await gui_click(Vector2(100,150))
	check(lines() == ["TINTTRAN"],"GUI doorway -> TINTTRAN")
	den.advance(2.0); await process_frame
	check(den.view.patch.size == Vector2(640,400) and den.view.voice.playing,"tunnel walk frames and audio")
	await shot("tunnel")
	await settle()
	check(not den.active() and is_equal_approx(jungle.player.position.x,-2576) and is_equal_approx(jungle.player.position.z,-5154),"outside at (-2576, -5154)")
	jungle.set_physics_process(true)
	for i in range(90): await physics_frame
	var y: float = jungle.player.position.y
	check(y < 40.0 and y > -60.0 and absf(jungle.player.position.x+2576) < 20 and absf(jungle.player.position.z+5154) < 20,"standing on region 386's floor after physics: %s" % [jungle.player.position])
	await shot("outside_palisade")
	DirAccess.remove_absolute(path)
	jungle.queue_free()
	await process_frame
	await process_frame
	finish()
func finish() -> void:
	if failures:
		push_error("FAIL: %d thieves den live checks" % failures)
		quit(1)
		return
	print("PASS thieves den live: real GUI clicks through yard, cellar walk-in, password door (475 frames + audio, mid-line disk resume), Mauri's talking head/idle, both shelf items, Back button chain, alert tunnel (TINTTRAN) landing on the floor outside the palisade")
	quit()
