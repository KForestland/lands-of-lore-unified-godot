extends RefCounted

# Source ordering is verified; this preview rate is not native timing evidence.
const PREVIEW_FPS := 8.0
const ROOT := "res://assets/lol2/generated/encounter_directions/"
var textures: Array[ImageTexture] = []
var view_textures: Array = []
var view_slot := 7
var action_textures: Dictionary = {}
var action_key := -1
var attack_impact_frame := -1
var canvas_size := Vector2.ZERO
var centre_offset := Vector3.ZERO
var world_units_per_pixel := 0.0
var elapsed := 0.0
var frame_index := 0
var frame_count := 0

func load_assets() -> String:
	var manifest_path := ROOT + "animation.json"
	if not FileAccess.file_exists(manifest_path):
		return "Missing encounter animation assets; run export_creature_directions.py."
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary or not manifest.get("views") is Array or manifest.views.size() != 8:
		return "Invalid encounter animation manifest."
	textures.clear()
	view_textures.clear()
	action_textures.clear()
	canvas_size = Vector2(manifest.canvas_size[0], manifest.canvas_size[1])
	centre_offset = Vector3(manifest.centre_offset[0], manifest.centre_offset[1], manifest.centre_offset[2])
	world_units_per_pixel = manifest.world_units_per_pixel
	var resources := [769, 733, 742, 751, 760, 751, 742, 733]
	for slot in range(8):
		var view: Dictionary = manifest.views[slot]
		if int(view.slot) != slot or int(view.resource) != resources[slot] or view.frames.size() != 9:
			return "Encounter directional source order differs."
		var loaded: Array[ImageTexture] = []
		for index in range(9):
			var entry: Dictionary = view.frames[index]
			var path := ROOT + "view_%d_frame_%d.png" % [slot, resources[slot] + index]
			if int(entry.descriptor) != resources[slot] + index or FileAccess.get_sha256(path) != entry.png_sha256:
				return "Encounter animation frame is missing or changed."
			var image := Image.load_from_file(path)
			if image == null or image.is_empty() or Vector2(image.get_size()) != canvas_size:
				return "Encounter animation frame dimensions differ."
			loaded.append(ImageTexture.create_from_image(image))
		view_textures.append(loaded)
	for key in [5, 14]:
		var action = manifest.get("actions", {}).get(str(key))
		var count := 16 if key == 5 else 20
		var resource := 794 if key == 5 else 810
		if not action is Dictionary or action.frames.size() != count or int(action.resource) != resource:
			return "Encounter action source differs."
		if key == 5:
			var markers = action.get("impact_frames", [])
			if not markers is Array or markers.size() != 1 or int(markers[0]) != 12:
				return "Original attack frame marker differs."
			attack_impact_frame = int(action.impact_frames[0])
		var loaded: Array[ImageTexture] = []
		for index in range(count):
			var entry: Dictionary = action.frames[index]
			var path := ROOT + "action_%d_frame_%d.png" % [key, resource + index]
			if int(entry.descriptor) != resource + index or FileAccess.get_sha256(path) != entry.png_sha256:
				return "Encounter action frame is missing or changed."
			var image := Image.load_from_file(path)
			if image == null or image.is_empty() or Vector2(image.get_size()) != canvas_size:
				return "Encounter action frame dimensions differ."
			loaded.append(ImageTexture.create_from_image(image))
		action_textures[key] = loaded
	action_key = -1
	set_view(7)
	frame_count = textures.size()
	reset()
	return ""

func set_view(slot: int) -> void:
	if view_textures.is_empty():
		return
	view_slot = posmod(slot, 8)
	if action_key < 0:
		textures = view_textures[view_slot]

func load_extra_roach_actions() -> String:
	const EXTRA="res://assets/lol2/generated/cave_roach_extra_actions/"
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(EXTRA+"animation.json"))
	if not manifest is Dictionary or not manifest.get("clips") is Array or manifest.clips.size()!=2:
		return "Missing original Roach action9/10 clips."
	if Vector2(manifest.canvas_size[0],manifest.canvas_size[1])!=canvas_size:
		return "Roach extra-action canvas differs."
	var prepared: Dictionary={}
	for clip in manifest.clips:
		var key:=int(clip.action)
		if key not in [9,10] or prepared.has(key) or clip.frames.size()!=8:
			return "Invalid Roach extra-action contract."
		var base:=830 if key==9 else 838
		var loaded: Array[ImageTexture]=[]
		for index in range(8):
			var row: Dictionary=clip.frames[index]
			var path:=EXTRA+"action_%d_frame_%d.png" % [key,base+index]
			if int(row.descriptor)!=base+index or FileAccess.get_sha256(path)!=row.png_sha256:
				return "Roach extra-action frame is missing or changed."
			var image:=Image.load_from_file(path)
			if image==null or image.is_empty() or Vector2(image.get_size())!=canvas_size:
				return "Roach extra-action dimensions differ."
			loaded.append(ImageTexture.create_from_image(image))
		prepared[key]=loaded
	for key in prepared: action_textures[key]=prepared[key]
	return ""

func play_action(key: int) -> void:
	if action_key == key:
		return
	assert(action_textures.has(key), "Action assets missing")
	action_key = key
	textures = action_textures[key]
	frame_count = textures.size()
	elapsed = 0.0
	frame_index = 0

func clear_action() -> void:
	if action_key < 0:
		return
	action_key = -1
	set_view(view_slot)
	frame_count = textures.size()
	elapsed = 0.0
	frame_index = 0

func action_finished() -> bool:
	return action_key >= 0 and elapsed >= frame_count / PREVIEW_FPS

func set_action_elapsed(seconds: float) -> void:
	assert(action_key >= 0, "Action must be selected before synchronizing its clock")
	elapsed = clampf(seconds, 0.0, frame_count / PREVIEW_FPS)
	frame_index = mini(int(floor(elapsed * PREVIEW_FPS)), frame_count - 1)

static func native_bearing(dx: int, dy: int) -> int:
	var quadrant: int = (0xc0 if dx < 0 else 0) ^ (0x40 if dy < 0 else 0)
	var x: int = absi(dx)
	var y: int = absi(dy)
	var reverse: int = (quadrant & 0x40) ^ 0x40
	if y >= x:
		var swap := x
		x = y
		y = swap
		reverse ^= 0x40
	if y < 256:
		while x >= 256:
			x >>= 1
			y >>= 1
	var ratio: int = (y << 8) / x if x != 0 else 0xffffffff
	var result: int = ratio >> 3
	return ((63 - result if reverse != 0 else result) + quadrant) & 255

func select_direction(to_camera: Vector2, facing: Vector2) -> void:
	if to_camera.length_squared() < 0.000001 or facing.length_squared() < 0.000001:
		return
	var bearing := native_bearing(roundi(to_camera.x * 65536), roundi(to_camera.y * 65536))
	# Facing comes from prototype movement. Native heading is a16-bit angle;
	# this approximation derives it from the verified8-bit bearing routine.
	var heading := native_bearing(roundi(facing.x * 65536), roundi(facing.y * 65536)) << 8
	var adjusted: int = ((heading - 4096) & 0xffffffff) >> 8
	set_view((((bearing - adjusted) & 255) * 8) >> 8)

func reset() -> void:
	clear_action()
	elapsed = 0.0
	frame_index = 0

func advance(delta: float, moving: bool) -> int:
	if action_key >= 0:
		elapsed = minf(elapsed + delta, frame_count / PREVIEW_FPS)
		frame_index = mini(int(floor(elapsed * PREVIEW_FPS)), frame_count - 1)
		return frame_index
	if not moving or frame_count == 0:
		reset()
		return frame_index
	elapsed = fposmod(elapsed + delta, frame_count / PREVIEW_FPS)
	frame_index = int(floor(elapsed * PREVIEW_FPS)) % frame_count
	return frame_index
