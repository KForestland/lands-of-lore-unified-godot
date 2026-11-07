extends CanvasLayer
## The Thieves' Den room chain on the Jungle host: TEXT (yard) from L4_HJ region 3642, then TCEL, TDOOR and TINT through
## the DLLs' own room calls, sharing the monastery compositor. Clicks follow the host router (actor rect, then
## sprites, then hotspots); the hand selector stands in for the original held item (docs/thieves-den.md,
## docs/DEVIATIONS.md). Quest sequencing lives in thieves_den_state.gd; this layer presents and applies host effects.
const State = preload("res://scripts/lol2/thieves_den_state.gd")
const Den = preload("res://scripts/lol2/thieves_den.gd")
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const JOURNAL_FLAGS := {28:"kelsrick_must_die_quietly",18:"village_hostile_gate_shut"}
const View = preload("res://scripts/lol2/monastery_room_view.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const Definitions = preload("res://scripts/lol2/item_definitions.gd")
## L4_HJ region 3642 (vertices 5546/5461/5462/5565), port coordinates (x, -y): the yard entry (event 2, g7338).
const ENTRANCE := [Vector2(-2395,-5389),Vector2(-2419,-5295),Vector2(-2448,-5297),Vector2(-2424,-5404)]
## Floor bases of the placement regions: TEXT leave -> region 3362 (0); the tunnel -> region 386 (-30).
const PLACE_FLOOR := {"TEXT":0.0,"TINT":-30.0}
const FOOT := 32.0
const FELL := "You fell. R: recover here · F9: load save"
var view: Control
var backdrop: ColorRect
var back: Button
var held: OptionButton
var input_layer: Control
var sprite_nodes := {}
var was_inside := false
var shown_room := ""
var shown_script := ""
var available := false
func state() -> Dictionary:
	var quests: Dictionary = get_parent().quest_state
	if not quests.has("thieves_den"): quests.thieves_den = State.initial()
	return State.normalize(quests.thieves_den)
func _ready() -> void:
	layer = 30
	available = State.available() and FileAccess.file_exists("res://assets/lol2/generated/monastery_rooms/rooms.json")
	if not available: return
	backdrop = ColorRect.new()
	backdrop.color = Color.BLACK
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view = View.new()
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.set_process(false)
	for room in Den.ROOMS:
		var media: Dictionary = State.media().rooms[room]
		var entry := {"background":media.background,"movies":[]}
		if media.has("idle"): entry.idle = media.idle
		view.manifest.rooms[room] = entry
	# THFSHAPE sprites sit above the background and below the movie patch.
	var sprites: Dictionary = State.media().rooms.TINT.sprites
	for id in Den.SPRITES:
		var info: Dictionary = sprites.get(str(id),{})
		if info.is_empty(): continue
		var sprite := TextureRect.new()
		sprite.texture = ImageTexture.create_from_image(Image.load_from_file(info.path))
		sprite.position = Vector2(Den.SPRITES[id][0],Den.SPRITES[id][1])
		sprite.size = Vector2(info.width,info.height)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.visible = false
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
	held.tooltip_text = "Item in hand when clicking Mauri"
	view.canvas.add_child(held)
	restore()
func active() -> bool:
	return available and state().room != ""
func other_room_active() -> bool:
	for key in ["monastery","magic_shop","weapon_shop","departure"]:
		var room = get_parent().get(key)
		if is_instance_valid(room) and room.active(): return true
	return false
func sprite_sizes() -> Dictionary:
	var sizes := {}
	for id in sprite_nodes: sizes[id] = Vector2i(sprite_nodes[id].size)
	return sizes

## Globals and locals the DLLs read, from their owners: GV_KELSRICK_DEAD and Met_Kelsrick (monastery bank), the Huline
## alert (village gate shared29), Met_Confidant (the Confidante owner's local 27) and the shared Firestorm flag 63
## (Kit'yara's shop bank).
func context() -> Dictionary:
	var host = get_parent()
	var monastery: Dictionary = host.quest_state.get("monastery",{})
	var shop: Dictionary = host.quest_state.get("weapon_shop",{})
	var alert := 0
	if is_instance_valid(host.get("village_gate")): alert = int(host.village_gate.state().shared29)
	var met_confidant := 0
	var confidante = host.get("confidante")
	if confidante != null and is_instance_valid(confidante) and confidante.get("state") is Dictionary and not confidante.state.is_empty(): met_confidant = int(confidante.state.get("locals",{}).get("27",0))
	else: met_confidant = int(host.quest_state.get("jungle_confidante",{}).get("state",{}).get("locals",{}).get("27",0))
	return {"kelsrick_dead":int(monastery.get("globals",{}).get("GV_KELSRICK_DEAD",0)) != 0,"alert":alert == 1,
		"met_kelsrick":int(monastery.get("locals",{}).get("Met_Kelsrick",0)) != 0,"met_confidant":met_confidant != 0,
		"firestorm":int(shop.get("flags",{}).get("63",0)) != 0}

## Region 3642 event 2: the yard opens where Luther stands (no reposition; TEXT's leave places him at region 3362).
func enter_room() -> bool:
	if not available or other_room_active() or not State.enter(state(),context()): return false
	was_inside = true
	_apply(State.advance(state(),0.0,context()))
	restore()
	return true
## Back/Escape issue the room exit request (message 8).
func leave_room() -> void:
	if not active() or not State.leave(state()): return
	_apply(State.advance(state(),0.0,context()))
	restore()
func restore() -> void:
	if not available: return
	var s := state()
	_flush_pending_items()
	visible = s.room != ""
	shown_script = ""
	if not visible:
		shown_room = ""
		view.voice.stop()
		view.background.stop()
		view.clip = {}
		if other_room_active(): return
		get_parent().set_physics_process(true)
		if is_instance_valid(get_parent().interface_hud): get_parent().interface_hud.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		was_inside = _entrance_contact()
		return
	get_parent().set_physics_process(false)
	if is_instance_valid(get_parent().interface_hud): get_parent().interface_hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if shown_room != s.room:
		shown_room = s.room
		view.enter_room(s.room)
	held.visible = s.room == "TINT"
	_refresh_hand()
	refresh_speech()
func _refresh_hand() -> void:
	var previous := str(held.get_item_metadata(held.selected)) if held.selected >= 0 and held.selected < held.item_count else ""
	held.clear()
	held.add_item("Empty hand")
	held.set_item_metadata(0,"")
	for item in preload("res://scripts/lol2/hand_selector_order.gd").wanted_first(get_parent().carried_collected,is_magic_item):
		held.add_item(Catalog.label(item) if not Catalog.label(item).is_empty() else str(item))
		held.set_item_metadata(held.item_count-1,item)
		if item == previous: held.select(held.item_count-1)
## Host 0xA8: the held definition's byte +0x43 bit 0 (24 "magic" items; THIEVES_DEN_DECODE §6).
static func is_magic_item(id: String) -> bool:
	var index := Catalog.definition(id)
	return index >= 0 and (Definitions.raw_byte(index,0x43) & 1) != 0
func refresh_speech() -> void:
	var s := state()
	var shown := Den.visible_sprites(s.flags) if s.room == "TINT" else []
	for id in sprite_nodes: sprite_nodes[id].visible = id in shown
	var speaking := State.active(s)
	back.disabled = speaking
	held.disabled = speaking
	if speaking:
		var script: Dictionary = s.script
		var effects := State.script_effects(script.handler,script.args)
		var key := "%s:%d" % [script.handler,int(script.cursor)]
		if key != shown_script:
			shown_script = key
			var clip: Dictionary = State.clip(s.room,effects[int(script.cursor)])
			if clip.is_empty(): clip = {"frames":0,"duration":0.0,"audio":""}
			# The shared view resolves unnamed sequences through `movies`.
			view.manifest.rooms[s.room].movies = [clip]
			view.play_patch(0,float(script.elapsed),"")
		view.set_time(float(script.elapsed))
		return
	shown_script = ""
	if s.room == "TINT":
		if not view.clip.get("idle",false): view.play_idle()
		return
	if not view.clip.is_empty():
		view.clip = {}
		view.visual = {}
		view.patch.texture = null
		view.voice.stop()
func advance(delta: float) -> void:
	_apply(State.advance(state(),delta,context()))
	if not active(): return
	refresh_speech()
	if view.clip.get("idle",false): view.set_time(view.elapsed+delta)
func _apply(effects: Array) -> void:
	var host = get_parent()
	var left := false
	for effect in effects:
		match effect[0]:
			"give_item": grant(str(effect[1]))
			"add_fighting_xp": award_fighting(int(effect[1]))
			"set_flag":
				# My Journal: Mauri's first meeting (28) and his tunnel offered with the village roused (18).
				if int(effect[1]) in JOURNAL_FLAGS: MyJournal.discover(host, JOURNAL_FLAGS[int(effect[1])])
				# Flag 63 is one host bit shared with Kit'yara's WPN room (offer_orb_repeat reads it).
				if int(effect[1]) == 63:
					if not host.quest_state.has("weapon_shop"): host.quest_state.weapon_shop = preload("res://scripts/lol2/weapon_shop_state.gd").initial()
					host.quest_state.weapon_shop.flags["63"] = 1
			"set_local":
				if not host.quest_state.has("weapon_shop"): host.quest_state.weapon_shop = preload("res://scripts/lol2/weapon_shop_state.gd").initial()
				host.quest_state.weapon_shop.locals[str(effect[1])] = clampi(int(effect[2]),0,1)
			"consume_held":
				var id := str(effect[1])
				if host.equipped_item == id: host.set_equipped_item("")
				host.carried_collected.erase(id)
				if host.get("hand_item") == id: host.hand_item = ""
				if is_instance_valid(host.interface_hud): host.interface_hud.refresh_equipment()
			"place":
				# Native y is the port's -z; the player stands FOOT units above the placing room's region floor.
				host.player.position = Vector3(float(effect[1]),PLACE_FLOOR.get(str(effect[3]),0.0)+FOOT,-float(effect[2]))
				host.player.velocity = Vector3.ZERO
			"set_heading":
				# Host 0xF0 degrees, 0 = map east, counterclockwise (monastery_rooms CHUT_HEADING): Godot yaw = deg - 90.
				host.player.rotation.y = deg_to_rad(float(effect[1])-90.0)
			"damage":
				# Host 0x5C with -1: hit points to 0 and the death routine; the Jungle host's R/F9 recovery follows.
				if host.get("starting_magic") != null and is_instance_valid(host.starting_magic):
					host.starting_magic.set_health(0)
					if host.has_method("save_feedback"): host.save_feedback(FELL)
			"exit_room": left = true
	if not effects.is_empty() and is_instance_valid(held) and active(): _refresh_hand()
	# A room change inside the chain (room + exit_room) re-enters the compositor's room; a close restores the world.
	if left or state().room != shown_room: restore()
## give_item: modern inventory entry when the pack admits it, else pending until it does (as Rashar's grants).
func grant(name: String) -> void:
	var s := state()
	var id: String = State.ITEMS.get(name,"")
	var carried: Array = get_parent().carried_collected
	if id.is_empty() or id in carried: return
	if _inventory_accepts(carried+[id]):
		carried.append(id)
		if is_instance_valid(get_parent().interface_hud): get_parent().interface_hud.refresh_equipment()
		return
	if not name in s.pending_items: s.pending_items.append(name)
func _inventory_accepts(collected: Array) -> bool:
	return preload("res://scripts/lol2/jungle_save.gd").validate_inventory({"collected":collected,"equipped_item":"","equipped_armor":""}).is_empty()
func _flush_pending_items() -> void:
	var s := state()
	var pending: Array = s.pending_items.duplicate()
	s.pending_items.clear()
	for name in pending: grant(name)
## Host slot 0x120 -> player fighting award (D8A1C); the saved LCG replaces the native RNG (magic_shop_rooms).
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
## Host click router on the 640x400 room canvas.
func click(point: Vector2i) -> bool:
	if not active() or State.active(state()): return false
	var s := state()
	for hit in Den.route(s.room,point,s.flags,sprite_sizes()):
		match hit[0]:
			"npc":
				if s.room != "TINT": return false
				var id := str(held.get_item_metadata(held.selected)) if held.selected >= 0 else ""
				return offer_item(id)
			"sprite":
				# Adapter (DEVIATIONS): a full pack refuses before the DLL's flag is set, so the pickup can be retried.
				var name: String = ["123-Pois paint","93-Skull key"][int(hit[1])]
				if not _inventory_accepts(get_parent().carried_collected+[State.ITEMS[name]]):
					get_parent().save_feedback("You cannot carry more.")
					return true
				if State.click_sprite(s,int(hit[1])):
					_apply(State.advance(s,0.0,context()))
					refresh_speech()
					return true
			"hotspot":
				if State.click_hotspot(s,int(hit[1]),context()):
					_apply(State.advance(s,0.0,context()))
					if active(): refresh_speech()
					return true
	return false
## Message 5: a click on Mauri with `id` (a carried inventory entry, or "") in hand.
func offer_item(id: String) -> bool:
	if not active() or State.active(state()): return false
	if not id.is_empty() and not id in get_parent().carried_collected: return false
	if not State.offer(state(),id,is_magic_item(id) if not id.is_empty() else false): return false
	_apply(State.advance(state(),0.0,context()))
	if active(): refresh_speech()
	return true
## Messages 7/6: Use Weapon (F) or Cast Spell (Q) inside the den.
func attack(message: int) -> bool:
	if not active() or state().room != "TINT" or not State.attack(state()): return false
	_apply(State.advance(state(),0.0,context()))
	if active(): refresh_speech()
	return message in [6,7]
func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if click(Vector2i(event.position)): input_layer.accept_event()
func _in_entrance() -> bool:
	var position: Vector3 = get_parent().player.position
	return absf(position.y-FOOT) < 48.0 and Geometry2D.is_point_in_polygon(Vector2(position.x,position.z),PackedVector2Array(ENTRANCE))
func _entrance_contact() -> bool:
	return is_instance_valid(get_parent().player) and _in_entrance()
func _process(delta: float) -> void:
	if not available or get_tree().paused: return
	if active():
		advance(delta)
		return
	if other_room_active(): return
	var inside := _in_entrance()
	if inside and not was_inside and enter_room(): return
	was_inside = inside
func _unhandled_input(event: InputEvent) -> void:
	if not active() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE: leave_room()
	elif event.keycode in [KEY_F,KEY_Q]:
		if not attack(7 if event.keycode == KEY_F else 6): return
	elif event.keycode == KEY_F5: get_parent().quicksave()
	elif event.keycode == KEY_F9: get_parent().quickload()
	else: return
	get_viewport().set_input_as_handled()
## Enter skips the line now playing (dialogue_skip.gd): only the script clock moves.
func skip_line() -> bool:
	if not available or get_tree().paused or not active(): return false
	var s: Dictionary = state()
	if not State.script_active(s): return false
	var effects := State.script_effects(s.script.handler,s.script.args)
	if int(s.script.cursor) >= effects.size() or not State.is_movie(effects[int(s.script.cursor)]): return false
	var remaining := State.clip_duration(s.room,effects[int(s.script.cursor)])-float(s.script.elapsed)
	_apply(State.advance(s,maxf(remaining,0.0),context()))
	if active(): refresh_speech()
	return true
