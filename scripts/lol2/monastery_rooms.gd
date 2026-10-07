extends CanvasLayer
## Jungle room entry and first-visit conversations; source event and DLL ordering.
const State = preload("res://scripts/lol2/monastery_quest_state.gd")
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
const View = preload("res://scripts/lol2/monastery_room_view.gd")
const ENTRANCE := [Vector2(4164,2540),Vector2(4324,2190),Vector2(4364,2210),Vector2(4204,2560)]
const VILLAGE_ENTRANCE := [Vector2(-1624,-4037),Vector2(-1565,-4021),Vector2(-1613,-3732),Vector2(-1729,-3790)]
var view: Control
var backdrop: ColorRect
var back: Button
var held: OptionButton
var give: Button
var hotspots: Array[Control] = []
var was_inside := false
var shown_room := ""
var shown_cursor := -1
var shown_sequence := ""
var available := false
func state() -> Dictionary:
	var quests: Dictionary = get_parent().quest_state
	if not quests.has("monastery"): quests.monastery = State.initial()
	return quests.monastery
func _ready() -> void:
	layer = 30
	available = FileAccess.file_exists("res://assets/lol2/generated/monastery_rooms/rooms.json")
	if not available: return
	backdrop = ColorRect.new()
	backdrop.color = Color.BLACK
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view = View.new()
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.set_process(false)
	back = Button.new()
	back.text = "Back"
	back.position = Vector2(550,365)
	back.size = Vector2(80,28)
	view.canvas.add_child(back)
	back.pressed.connect(leave_room)
	held = OptionButton.new()
	held.position = Vector2(16,365)
	held.size = Vector2(220,28)
	view.canvas.add_child(held)
	give = Button.new()
	give.text = "Give item"
	give.position = Vector2(245,365)
	give.size = Vector2(100,28)
	view.canvas.add_child(give)
	give.pressed.connect(func(): offer_item(str(held.get_item_metadata(held.selected))))
	for data in [[Rect2(0,106,87,227),"MCEL","MENT"],[Rect2(272,132,119,167),"MGAR","MENT"],[Rect2(140,106,95,217),"MLIB","MENT"],[Rect2(431,152,179,161),"MOFF","MENT"],[Rect2(244,220,142,90),"CAN","VILLAGE"]]:
		var hit := Control.new()
		hit.position = data[0].position
		hit.size = data[0].size
		hit.set_meta("room",data[2])
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		view.canvas.add_child(hit)
		var destination: String = data[1]
		hit.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: enter_room(destination))
		hotspots.append(hit)
	restore()
func active() -> bool:
	return available and not str(state().get("room","")).is_empty()
func enter_room(destination: String) -> bool:
	var s := state()
	var current: String = s.get("room","")
	if Speech.active(s.get("conversation",Speech.initial())): return false
	if destination in ["MENT","VILLAGE"]:
		if not current.is_empty() or not view.manifest.rooms.has(destination): return false
	elif destination == "CAN":
		if current != "VILLAGE" or s.flags.get("267",0) != 0: return false
	elif current != "MENT": return false
	elif destination == "MOFF" and not State.office_admitted(s): return false
	elif destination == "MCEL" and not State.cellar_admitted(s): return false
	elif not destination in ["MLIB","MOFF","MCEL","MGAR"]: return false
	if not view.manifest.rooms.has(destination): return false
	if destination in ["MCEL","MGAR"]:
		s.side_actor_present = State.side_actor_present(s,destination,Speech.ORB in get_parent().carried_collected)
		if s.side_actor_present:
			if destination == "MCEL": s.flags["171"] = 1
			else: s.locals.Met_Morgan = 1
	s.room = destination
	if destination != "MENT": Speech.begin(s,destination)
	restore()
	return true
func leave_room() -> void:
	var s := state()
	if not active() or Speech.active(s.get("conversation",Speech.initial())): return
	if s.room == "MENT":
		s.room = ""
		get_parent().player.position.x = 4181
		get_parent().player.position.z = 2377
		was_inside = false
	elif s.room == "VILLAGE":
		s.room = ""
		was_inside = true
	elif s.room == "CAN":
		if s.flags.get("37",0) == 1:
			Speech.begin_exit(s)
			refresh_speech()
			return
		s.room = "VILLAGE"
	elif s.room == "MOFF":
		# Source message8: visit counter first, then Julian's exit lines (or none).
		if Speech.begin_moff_exit(s):
			refresh_speech()
			return
		s.room = "MENT"
	else: s.room = "MENT"
	restore()
## Item grants from room speech. The orb waits in `pending_items` until the shared
## inventory format admits its ID; the flute is already admitted.
func grant(item: String) -> void:
	var carried: Array = get_parent().carried_collected
	if item in carried: return
	var s := state()
	if item == Speech.ORB and not preload("res://scripts/lol2/jungle_save.gd").validate_inventory({"collected":carried+[item],"equipped_item":"","equipped_armor":""}).is_empty():
		if not s.has("pending_items"): s.pending_items = []
		if not item in s.pending_items: s.pending_items.append(item)
		return
	carried.append(item)
	if s.has("pending_items"): s.pending_items.erase(item)
func restore() -> void:
	if not available: return
	var s := state()
	for item in s.get("pending_items",[]).duplicate(): grant(item)
	var room: String = s.get("room","")
	visible = not room.is_empty()
	shown_room = room
	held.visible = room == "MOFF" or (room == "MGAR" and s.get("side_actor_present",false))
	give.visible = held.visible
	var previous_item := str(held.get_item_metadata(held.selected)) if held.selected >= 0 and held.selected < held.item_count else ""
	held.clear()
	held.add_item("Empty hand")
	held.set_item_metadata(0,"")
	for item in get_parent().carried_collected:
		held.add_item("Wax runes" if preload("res://scripts/lol2/hive_rune_items.gd").valid(item) else str(item).get_slice(":",2).replace("_"," "))
		held.set_item_metadata(held.item_count-1,item)
		if item == previous_item: held.select(held.item_count-1)
	shown_cursor = -1
	get_parent().set_physics_process(room.is_empty())
	if is_instance_valid(get_parent().interface_hud): get_parent().interface_hud.visible = room.is_empty()
	if room.is_empty():
		view.voice.stop()
		view.background.stop()
		for key in ["magic_shop","weapon_shop"]:
			var other = get_parent().get(key)
			if is_instance_valid(other) and other.active(): return
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view.enter_room(room)
	for hit in hotspots: hit.visible = room == hit.get_meta("room")
	refresh_speech()
func refresh_speech() -> void:
	var s := state()
	var speech: Dictionary = s.get("conversation",Speech.initial())
	if shown_sequence != speech.sequence:
		shown_sequence = speech.sequence
		shown_cursor = -1
	var speaking := Speech.active(speech)
	back.disabled = speaking
	held.disabled = speaking
	give.disabled = speaking
	if shown_room == "VILLAGE" and not speaking:
		view.patch.texture = null
		view.clip = {}
		view.visual = {}
		view.voice.stop()
		return
	if shown_room in ["MCEL","MGAR"] and not speaking:
		if s.get("side_actor_present",false):
			if not view.clip.get("idle",false): view.play_idle()
		else:
			view.patch.texture = null
			view.clip = {}
			view.visual = {}
			view.voice.stop()
		return
	if shown_room == "CAN" and not speaking and State.bacatta_present(s):
		if not view.clip.get("idle",false): view.play_idle()
		return
	if speech.sequence.is_empty() or Speech.room_for(speech.sequence) != shown_room: return
	var index := mini(int(speech.cursor),Speech.FRAMES[speech.sequence].size()-1)
	if index != shown_cursor:
		shown_cursor = index
		view.play_patch(index,float(speech.elapsed) if speaking else Speech.duration(speech.sequence,index),speech.sequence)
	view.elapsed = float(speech.elapsed) if speaking else float(view.clip.duration)
	view.set_time(view.elapsed)
	if not speaking: view.voice.stop()
func advance(delta: float) -> void:
	if not active(): return
	var rewards := Speech.advance(state(),delta)
	for item in rewards:
		if item is Dictionary and item.has("morgan_heal"):
			# Playable health currently caps at30; native progression health is separate.
			get_parent().health = preload("res://scripts/lol2/morgan_orb_blessing.gd").heal(get_parent().health,30)
		else: grant(item)
	if not rewards.is_empty(): restore()
	var speech: Dictionary = state().get("conversation",Speech.initial())
	if state().room == "MOFF" and Speech.is_moff_exit(speech.sequence) and not Speech.active(speech):
		state().room = "MENT"
		restore()
		return
	if state().room == "CAN" and speech.sequence == "CAN_EXIT" and not Speech.active(speech):
		state().room = "VILLAGE"
		restore()
		return
	refresh_speech()
	if view.clip.get("idle",false): view.set_time(view.elapsed+delta)
func _process(delta: float) -> void:
	if not available or get_tree().paused: return
	if active():
		advance(delta)
		return
	for key in ["magic_shop","weapon_shop","departure"]:
		var other = get_parent().get(key)
		if is_instance_valid(other) and other.active(): return
	var position: Vector3 = get_parent().player.position
	var inside := absf(position.y-42.0) < 48.0 and Geometry2D.is_point_in_polygon(Vector2(position.x,position.z),PackedVector2Array(ENTRANCE))
	var village_inside: bool = view.manifest.rooms.has("VILLAGE") and absf(position.y-32.0) < 48.0 and Geometry2D.is_point_in_polygon(Vector2(position.x,position.z),PackedVector2Array(VILLAGE_ENTRANCE))
	if (inside or village_inside) and not was_inside: enter_room("MENT" if inside else "VILLAGE")
	was_inside = inside or village_inside
func _unhandled_input(event: InputEvent) -> void:
	if not active() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE: leave_room()
	# Room messages7/6 come from the player's Use Weapon (original key F) and Cast Spell actions inside a room.
	elif event.keycode in [KEY_F,KEY_Q] and attack(7 if event.keycode == KEY_F else 6): pass
	elif event.keycode == KEY_F5: get_parent().quicksave()
	elif event.keycode == KEY_F9: get_parent().quickload()
	else: return
	get_viewport().set_input_as_handled()

func attack(message: int) -> bool:
	var s := state()
	if not active() or s.room != "MLIB" or not Speech.begin_attack(s,message): return false
	refresh_speech()
	return true

func offer_item(id: String) -> bool:
	var s := state()
	if s.room == "MGAR":
		if Speech.active(s.get("conversation",Speech.initial())) or not s.get("side_actor_present",false) or id != Speech.ORB or id not in get_parent().carried_collected: return false
		var plan := preload("res://scripts/lol2/morgan_orb_blessing.gd").offer_plan(s.flags,"83-Power orb")
		var sequence := "MGAR_ORB" if plan.has(["consume_held"]) else "MGAR_ORB_REFUSE"
		if sequence == "MGAR_ORB": get_parent().carried_collected.erase(id)
		s.conversation = {"sequence":sequence,"cursor":0,"elapsed":0.0}
		restore()
		return true
	if s.room != "MOFF" or Speech.active(s.get("conversation",Speech.initial())) or s.flags["144"] != 0: return false
	if not id.is_empty() and id not in get_parent().carried_collected: return false
	var held_name := "72-Wax runes" if preload("res://scripts/lol2/hive_rune_items.gd").valid(id) else id
	var plan := preload("res://scripts/lol2/monastery_offer.gd").plan(held_name,s.flags,int(s.globals.get("GV_KNOWLEDGE_OF_POWER_ORB",0)))
	if not plan.handled: return false
	for effect in plan.effects:
		match effect[0]:
			"set_flag": s.flags[str(effect[1])] = 1
			"clear_flag": s.flags[str(effect[1])] = 0
			"consume_held": get_parent().carried_collected.erase(id)
	if not plan.sequence.is_empty():
		s.conversation = {"sequence":plan.sequence,"cursor":0,"elapsed":0.0}
		restore()
	return true
