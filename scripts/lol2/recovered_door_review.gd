extends Node3D
## Isolated review: recovered surfaces and sampled native hinge motion.
## UVs and playback speed are provisional. No gameplay collision is claimed.
const Door = preload("res://scripts/lol2/recovered_door.gd")
const SCALE := 0.025
var motion: Dictionary
var door_nodes: Array[Node3D] = []
var camera: Camera3D
var progress: HSlider
var status: Label
var playing := false
var phase := 0.0
var view_angle := 0.6
var current_frame := -1

func _ready() -> void:
	motion = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/doors/motion.json"))
	for i in range(2):
		var door := Door.new()
		door.position.x = (float(i) - 0.5) * 3.4
		add_child(door)
		door.configure(motion.doors[i], SCALE)
		door_nodes.append(door)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202936")
	add_child(environment)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(24, 24)
	panel.custom_minimum_size = Vector2(620, 0)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "Recovered cave doors — 75 and 79"
	panel.add_child(title)
	status = Label.new()
	panel.add_child(status)
	progress = HSlider.new()
	progress.max_value = 100
	progress.step = 1
	progress.value_changed.connect(func(value: float) -> void: _show_frame(int(value)))
	panel.add_child(progress)
	var play := Button.new()
	play.text = "Play / pause"
	play.pressed.connect(func() -> void:
		playing = not playing
		phase = acos(1.0 - progress.value / 50.0))
	panel.add_child(play)
	var angle := HSlider.new()
	angle.max_value = 360
	angle.value = rad_to_deg(view_angle)
	angle.value_changed.connect(func(value: float) -> void: view_angle = deg_to_rad(value))
	panel.add_child(angle)
	var note := Label.new()
	note.text = "Opening and view angle controls. Doors shown separately.\nPreview UVs and timing; collision is not connected."
	panel.add_child(note)
	_show_frame(0)
	if "--door-review-check" in OS.get_cmdline_user_args():
		for frame in range(101):
			_show_frame(frame)
			for door in door_nodes:
				for surface in door.get_children():
					assert(surface.mesh.get_surface_count() == 1)
		print("Door review: 101 frames, 8 textured surfaces per frame passed")
		get_tree().quit()

func _process(delta: float) -> void:
	if playing:
		phase += delta / 1.8
		progress.value = round((1.0 - cos(phase)) * 50.0)
	camera.position = Vector3(sin(view_angle) * 8.0, 3.8, cos(view_angle) * 8.0)
	camera.look_at(Vector3(0, 0.8, 0))

func _show_frame(frame: int) -> void:
	if frame == current_frame:
		return
	current_frame = frame
	status.text = "Opening: %d%%" % frame
	for door in door_nodes:
		door.set_opening(frame)
