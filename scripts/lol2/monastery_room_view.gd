extends Control
## Source-sized room background and transparent movie patch compositor.
## Quest sequencing is owned by the caller, not by this presentation layer.
var manifest: Dictionary
var room: String
var background: VideoStreamPlayer
var patch: TextureRect
var voice: AudioStreamPlayer
var canvas: Control
var clip: Dictionary = {}
var visual: Dictionary = {}
var elapsed := 0.0
var last_frame := -1
var textures: Dictionary = {}
var background_generation := 0
func _ready() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/monastery_rooms/rooms.json"))
	var village_path := "res://assets/lol2/generated/bacatta_rooms/rooms.json"
	if FileAccess.file_exists(village_path):
		var village: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(village_path))
		manifest.rooms.merge(village.rooms)
	# Village LIZ room (tools/prepare_liz_room_media.py).
	var liz_path := "res://assets/lol2/generated/liz_room/rooms.json"
	if FileAccess.file_exists(liz_path):
		manifest.rooms.merge(JSON.parse_string(FileAccess.get_file_as_string(liz_path)).rooms)
	var side_path := "res://assets/lol2/generated/monastery_side_rooms/rooms.json"
	if FileAccess.file_exists(side_path):
		var side: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(side_path))
		manifest.rooms.merge(side.rooms)
	# Julian's revisit/exit patches (tools/prepare_moff_revisit.py); the flute exit reuses first-visit patches.
	var moff_path := "res://assets/lol2/generated/monastery_moff/moff.json"
	if manifest.rooms.has("MOFF") and FileAccess.file_exists(moff_path):
		var moff: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(moff_path))
		var sequences: Dictionary = moff.sequences
		sequences["MOFF_EXIT_FLUTE"] = manifest.rooms.MOFF.movies.slice(14,23)
		manifest.rooms.MOFF.sequences = sequences
	# CAN later visits (tools/prepare_tavern_return_media.py): maid betrayal, second visit, line675.
	var revisit_path := "res://assets/lol2/generated/bacatta_revisit/clips.json"
	if manifest.rooms.has("CAN") and FileAccess.file_exists(revisit_path):
		var named: Dictionary = manifest.rooms.CAN.get("sequences",{})
		named.merge(JSON.parse_string(FileAccess.get_file_as_string(revisit_path)).sequences)
		manifest.rooms.CAN.sequences = named
	var morgan_path := "res://assets/lol2/generated/morgan_blessing/clips.json"
	if manifest.rooms.has("MGAR") and FileAccess.file_exists(morgan_path):
		manifest.rooms.MGAR.sequences = JSON.parse_string(FileAccess.get_file_as_string(morgan_path)).sequences
	canvas = Control.new()
	canvas.size = Vector2(640,400)
	add_child(canvas)
	background = VideoStreamPlayer.new()
	background.expand = true
	background.size = canvas.size
	canvas.add_child(background)
	background.finished.connect(func(): background.play())
	patch = TextureRect.new()
	patch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.add_child(patch)
	voice = AudioStreamPlayer.new()
	add_child(voice)
	resized.connect(_layout)
	_layout()
func _layout() -> void:
	if not is_instance_valid(canvas): return
	var factor := minf(size.x/640.0,size.y/400.0)
	canvas.scale = Vector2.ONE*factor
	canvas.position = (size-Vector2(640,400)*factor)/2.0
func enter_room(id: String) -> void:
	assert(manifest.rooms.has(id))
	room = id
	clip = {}
	visual = {}
	textures.clear()
	voice.stop()
	patch.texture = null
	background_generation += 1
	_start_background.call_deferred(id,background_generation)
func _start_background(id: String, generation: int) -> void:
	if generation != background_generation or not is_inside_tree(): return
	background.stop()
	background.stream = null
	var stream := VideoStreamTheora.new()
	stream.file = manifest.rooms[id].background.path
	background.stream = stream
	background.play()
func play_patch(index: int, start_time: float = 0.0, sequence: String = "") -> void:
	last_frame = -1
	var named: Dictionary = manifest.rooms[room].get("sequences",{})
	if named.has(sequence): clip = named[sequence][index].duplicate(true)
	else: clip = manifest.rooms[room][{"MGAR_REPEAT":"repeat_movies","CAN_EXIT":"exit_movies","MOFF_RUNES":"rune_movies","MOFF_REFUSE":"refusal_movies","MOFF_ORB":"orb_movies","MAGIC_RETURN":"return_movies"}.get(sequence,"movies")][index].duplicate(true)
	elapsed = clampf(start_time,0.0,float(clip.duration))
	visual = clip if int(clip.frames) > 0 else manifest.rooms[room].get("idle",{})
	if not visual.is_empty():
		patch.position = Vector2(visual.x,visual.y)
		patch.size = Vector2(visual.width,visual.height)
	voice.stop()
	if not str(clip.get("audio","")).is_empty():
		voice.stream = AudioStreamWAV.load_from_file(clip.audio)
		voice.play(elapsed)
	set_time(elapsed)
func set_time(time: float) -> void:
	elapsed = time
	if visual.is_empty(): return
	var frame := int(time*float(visual.fps))
	show_frame(frame%int(visual.frames) if int(clip.frames)==0 else mini(frame,int(visual.frames)-1))
func play_idle(time: float = 0.0) -> void:
	visual = manifest.rooms[room].get("idle",{})
	if visual.is_empty(): return
	voice.stop()
	clip = {"frames":0,"duration":INF,"idle":true}
	last_frame = -1
	patch.position = Vector2(visual.x,visual.y)
	patch.size = Vector2(visual.width,visual.height)
	set_time(time)
func show_frame(frame: int) -> void:
	assert(frame >= 0 and frame < int(visual.frames))
	if frame == last_frame: return
	last_frame = frame
	var sheet_index := frame/16
	var path: String = visual.atlases[sheet_index]
	if not textures.has(path): textures[path] = ImageTexture.create_from_image(Image.load_from_file(path))
	var atlas := AtlasTexture.new()
	atlas.atlas = textures[path]
	atlas.region = Rect2((frame%4)*visual.width,((frame%16)/4)*visual.height,visual.width,visual.height)
	patch.texture = atlas
func _process(delta: float) -> void:
	if clip.is_empty(): return
	elapsed = minf(elapsed+delta,float(clip.duration))
	set_time(elapsed)

func _exit_tree() -> void:
	if is_instance_valid(background):
		background.stop()
		background.stream = null
	if is_instance_valid(voice):
		voice.stop()
		voice.stream = null
