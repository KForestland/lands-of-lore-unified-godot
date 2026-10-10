extends CanvasLayer
## Rashar's MAGIC_ room entered from L4_HJ region2636 (group4858), sharing the
## monastery compositor. Clicks follow host router EFC74 (Rashar, then sprites,
## then hotspots); the hand selector stands in for the original held item.
## Opcode9 object-flag clears remain unbound.
const State = preload("res://scripts/lol2/magic_shop_state.gd")
const Shop = preload("res://scripts/lol2/magic_shop.gd")
const View = preload("res://scripts/lol2/monastery_room_view.gd")
const MANIFEST := "res://assets/lol2/generated/magic_shop/room.json"
var view: Control
var backdrop: ColorRect
var back: Button
var held: OptionButton
var input_layer: Control
var sprite_nodes := {}
var was_inside := false
var shown_sequence := ""
var shown_cursor := -1
var shown_script := ""
var available := false
var intro_movies: Array = []
func state() -> Dictionary:
	var quests: Dictionary = get_parent().quest_state
	if not quests.has("magic_shop"): quests.magic_shop = State.initial()
	return State.normalize(quests.magic_shop)
func _ready() -> void:
	layer = 30
	available = FileAccess.file_exists(MANIFEST) and FileAccess.file_exists("res://assets/lol2/generated/monastery_rooms/rooms.json")
	if not available: return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	backdrop = ColorRect.new()
	backdrop.color = Color.BLACK
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view = View.new()
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.set_process(false)
	var room := {"background":data.background,"idle":data.idle,"movies":[],"return_movies":[]}
	for line in State.LINES.MAGIC: room.movies.append(data.lines[str(line)])
	for line in State.LINES.MAGIC_RETURN: room.return_movies.append(data.lines[str(line)])
	intro_movies = room.movies
	view.manifest.rooms.MAGIC = room
	# MAGSHAPE sprites sit above the background and below the movie patch.
	for id in Shop.SPRITES:
		var info: Dictionary = State.media().sprites.get(str(Shop.SPRITES[id][2]),{})
		if info.is_empty(): continue
		var sprite := TextureRect.new()
		sprite.texture = ImageTexture.create_from_image(Image.load_from_file(info.path))
		sprite.position = Vector2(Shop.SPRITES[id][0],Shop.SPRITES[id][1])
		sprite.size = Vector2(info.width,info.height)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		view.canvas.add_child(sprite)
		view.canvas.move_child(sprite,view.patch.get_index())
		sprite_nodes[id] = sprite
	input_layer = Control.new()
	input_layer.size = Vector2(640,400)
	input_layer.gui_input.connect(_canvas_input)
	view.canvas.add_child(input_layer)
	back = Button.new()
	back.text = "Back"
	back.position = Vector2(550,365)
	back.size = Vector2(80,28)
	view.canvas.add_child(back)
	back.pressed.connect(leave_room)
	held = OptionButton.new()
	held.position = Vector2(16,365)
	held.size = Vector2(220,28)
	held.tooltip_text = "Item in hand when clicking Rashar"
	view.canvas.add_child(held)
	restore()
func active() -> bool:
	return available and state().room == "MAGIC"
func other_room_active() -> bool:
	for key in ["monastery","weapon_shop","departure"]:
		var room = get_parent().get(key)
		if is_instance_valid(room) and room.active(): return true
	return false
func enter_room() -> bool:
	if not available or other_room_active() or not State.enter(state()): return false
	# Source group order: opcode18 reposition precedes the room command.
	var host = get_parent()
	host.player.position.x = State.RETURN_POSE.x
	host.player.position.z = State.RETURN_POSE.z
	host.player.rotation.y = wrapf(-float(State.RETURN_POSE.bearing)*TAU/65536.0,-PI,PI)
	host.player.velocity = Vector3.ZERO
	was_inside = false
	restore()
	return true
## Back/Escape issue the source exit request (message8).
func leave_room() -> void:
	if not active() or not State.leave(state()): return
	restore()
func restore() -> void:
	if not available: return
	var s := state()
	visible = s.room == "MAGIC"
	shown_sequence = ""
	shown_cursor = -1
	shown_script = ""
	_flush_pending_items()
	if not visible:
		view.voice.stop()
		view.background.stop()
		view.clip = {}
		# The monastery layer owns the world while one of its rooms is shown.
		if other_room_active(): return
		get_parent().set_physics_process(true)
		if is_instance_valid(get_parent().interface_hud): get_parent().interface_hud.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	get_parent().set_physics_process(false)
	if is_instance_valid(get_parent().interface_hud): get_parent().interface_hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view.manifest.rooms.MAGIC.movies = intro_movies
	view.enter_room("MAGIC")
	_refresh_hand()
	refresh_speech()
func _refresh_hand() -> void:
	var previous := str(held.get_item_metadata(held.selected)) if held.selected >= 0 and held.selected < held.item_count else ""
	held.clear()
	held.add_item("Empty hand")
	held.set_item_metadata(0,"")
	for item in get_parent().carried_collected:
		held.add_item(str(item).get_slice(":",2).replace("_"," ") if str(item).get_slice_count(":") > 2 else str(item))
		held.set_item_metadata(held.item_count-1,item)
		if item == previous: held.select(held.item_count-1)
func sprite_sizes() -> Dictionary:
	var sizes := {}
	for id in Shop.SPRITES:
		var info: Dictionary = State.media().sprites.get(str(Shop.SPRITES[id][2]),{})
		if not info.is_empty(): sizes[id] = Vector2i(int(info.width),int(info.height))
	return sizes
func refresh_speech() -> void:
	var s := state()
	var shown := Shop.visible_sprites(s.flags)
	for id in sprite_nodes: sprite_nodes[id].visible = id in shown
	var speaking := State.active(s)
	back.disabled = speaking
	held.disabled = speaking
	if State.conversation_active(s):
		var speech: Dictionary = s.conversation
		if speech.sequence != shown_sequence or int(speech.cursor) != shown_cursor:
			shown_sequence = speech.sequence
			shown_cursor = int(speech.cursor)
			shown_script = ""
			view.manifest.rooms.MAGIC.movies = intro_movies
			view.play_patch(shown_cursor,float(speech.elapsed),speech.sequence)
		view.set_time(float(speech.elapsed))
		return
	if State.script_active(s):
		var script: Dictionary = s.script
		var effects := State.script_effects(script.handler,script.args)
		var key := "%s:%d" % [script.handler,int(script.cursor)]
		if key != shown_script:
			shown_script = key
			shown_sequence = ""
			shown_cursor = -1
			var clip := _clip(effects[int(script.cursor)])
			var kept := [view.patch.texture,view.patch.position,view.patch.size]
			# The shared view resolves unnamed sequences through `movies`.
			view.manifest.rooms.MAGIC.movies = [clip]
			view.play_patch(0,float(script.elapsed),"")
			if int(clip.frames) == 0 and Shop._f(s.flags,52):
				# No idle loop once Rashar is dead: keep the last death frame, if any.
				view.visual = {}
				view.patch.texture = kept[0]
				view.patch.position = kept[1]
				view.patch.size = kept[2]
		view.set_time(float(script.elapsed))
		return
	shown_script = ""
	if not view.clip.get("idle",false):
		if Shop._f(s.flags,52):
			view.clip = {}
			view.patch.texture = null
			view.voice.stop()
		else: view.play_idle()
## View clip for a script movie; audio-only requests keep Rashar's idle loop visible.
func _clip(effect: Array) -> Dictionary:
	var source: Dictionary = State.media().clips.get(State.clip_key(effect),{})
	var duration := State.clip_duration(effect)
	if source.has("atlases"): return source
	var audio := str(source.get("audio",source.get("path","")))
	return {"frames":0,"duration":duration,"audio":audio}
func advance(delta: float) -> void:
	State.tick_timer(state(),delta)
	_apply(State.advance(state(),delta))
	if not active(): return
	_apply(State.poll_timer(state()))
	if not active(): return
	refresh_speech()
	if view.clip.get("idle",false): view.set_time(view.elapsed+delta)
func _apply(effects: Array) -> void:
	var left := false
	for effect in effects:
		match effect[0]:
			"mana_debit": debit_mana(int(effect[1]))
			"consume_held":
				if get_parent().equipped_item == str(effect[1]): get_parent().set_equipped_item("")
				get_parent().carried_collected.erase(str(effect[1]))
			"give_item": grant(str(effect[1]))
			"award_fighting": award_fighting(int(effect[1]))
			"set_global":
				# Julian's MOFF offer reads the shared monastery knowledge global.
				if effect[1] in ["GV_KNOWLEDGE_OF_POWER_ORB","GV_LUTHERS_SOUL"] and get_parent().quest_state.has("monastery"):
					get_parent().quest_state.monastery.globals[effect[1]] = int(effect[2])
			"exit_room": left = true
	if left or not effects.is_empty():
		if is_instance_valid(held) and active(): _refresh_hand()
	if left: restore()
## give_item: modern inventory entry when the save format admits it, else pending.
func grant(name: String) -> void:
	var s := state()
	var ids: Array = State.ITEMS.get(name,[])
	var carried: Array = get_parent().carried_collected
	for id in ids:
		if id in carried: continue
		if _inventory_accepts(carried+[id]):
			carried.append(id)
			return
		break
	s.pending_items.append(name)
func _inventory_accepts(collected: Array) -> bool:
	return preload("res://scripts/lol2/jungle_save.gd").validate_inventory({"collected":collected,"equipped_item":"","equipped_armor":""}).is_empty()
func _flush_pending_items() -> void:
	var s := state()
	var pending: Array = s.pending_items.duplicate()
	s.pending_items.clear()
	for name in pending: grant(name)
## Host slot120 -> player D8A1C fighting award; saved LCG replaces native RNG.
func award_fighting(amount: int) -> void:
	var quests: Dictionary = get_parent().quest_state
	var initial: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/player_progression_initial.json"))
	var maxima: Array = []
	for level in range(31): maxima.append_array([95,63,63])
	var random := preload("res://scripts/lol2/hive_rune_transaction.gd").draws(int(state().reward_seed),maxima)
	var fight := preload("res://scripts/lol2/hive_reward_application.gd").award_checkpoint(quests.get("player_reward_state",{"version":1,"player":initial.fighting}),amount,random.values)
	if fight.has("error"): return
	quests.player_reward_state = fight.checkpoint
	state().reward_seed = int(random.seeds[fight.draws_used])
## Host slot1214: D6A88 with -amount, current mana clamped at zero.
func debit_mana(amount: int) -> void:
	var quests: Dictionary = get_parent().quest_state
	var magic: Dictionary
	if quests.has("player_magic_reward_state"): magic = quests.player_magic_reward_state.duplicate(true)
	else: magic = preload("res://scripts/lol2/player_magic_state.gd").initial()
	magic.player.mana = maxi(0,int(magic.player.mana)-amount)
	quests.player_magic_reward_state = magic
## Hand item as the source item name the DLL compares against.
func held_source_name(id: String) -> String:
	return preload("res://scripts/lol2/act_one_item_names.gd").source_name(id)
## Host click router EFC74 on the 640x400 room canvas.
func click(point: Vector2i) -> bool:
	if not active() or State.active(state()): return false
	for hit in Shop.route(point,state().flags,sprite_sizes()):
		match hit[0]:
			"npc":
				var id := str(held.get_item_metadata(held.selected)) if held.selected >= 0 else ""
				return offer_item(id)
			"sprite":
				var result := State.click_sprite(state(),int(hit[1]))
				if result[0]:
					_apply(result[1])
					refresh_speech()
					return true
			"hotspot":
				_apply(State.click_region(state(),int(hit[1])))
				refresh_speech()
				return true
	return false
## Message5: click on Rashar with `id` (a carried inventory entry, or "") in hand.
func offer_item(id: String) -> bool:
	if not active() or State.active(state()): return false
	if not id.is_empty() and not id in get_parent().carried_collected: return false
	var name := held_source_name(id)
	var has_broken := false
	for item in get_parent().carried_collected:
		if item != id and held_source_name(str(item)) == "12-Tho Broken": has_broken = true
	var s := state()
	var shared: Dictionary = get_parent().quest_state.monastery.globals
	if shared.has("GV_LUTHERS_SOUL"): s.globals.GV_LUTHERS_SOUL = int(shared["GV_LUTHERS_SOUL"])
	else: shared["GV_LUTHERS_SOUL"] = int(s.globals.GV_LUTHERS_SOUL)
	if shared.get("GV_KNOWLEDGE_OF_POWER_ORB",0) != 0: s.globals.GV_KNOWLEDGE_OF_POWER_ORB = 1
	var before := JSON.stringify(s)
	_apply(State.offer(s,name,id,has_broken))
	refresh_speech()
	return JSON.stringify(s) != before
func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if click(Vector2i(event.position)): input_layer.accept_event()
func _process(delta: float) -> void:
	if not available or get_tree().paused: return
	if active():
		advance(delta)
		return
	# Host timer DB4A8 keeps counting outside the room.
	State.tick_timer(state(),delta)
	if other_room_active() and state().timer_armed and float(state().timer_left) <= 0.0:
		# Another room's update stops the host timer before sending it message10.
		state().timer_armed = false
		state().timer_left = 0.0
	if other_room_active(): return
	var position: Vector3 = get_parent().player.position
	var inside := absf(position.y-32.0) < 48.0 and Geometry2D.is_point_in_polygon(Vector2(position.x,position.z),PackedVector2Array(State.ENTRANCE))
	# Entry repositions outside the polygon and owns was_inside itself.
	if inside and not was_inside and enter_room(): return
	was_inside = inside
func _unhandled_input(event: InputEvent) -> void:
	if not active() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE: leave_room()
	elif event.keycode == KEY_F5: get_parent().quicksave()
	elif event.keycode == KEY_F9: get_parent().quickload()
	else: return
	get_viewport().set_input_as_handled()
