extends CanvasLayer
## Jungle room entry and first-visit conversations; source event and DLL ordering.
const State = preload("res://scripts/lol2/monastery_quest_state.gd")
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
const View = preload("res://scripts/lol2/monastery_room_view.gd")
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
## My Journal notes recorded when their conversation plays: Bacatta's farewell (flag34), Anyar's death (flag150) and
## branch A, the hut entered after striking Kelsrick ([0xD74]: line 365, thrown out).
const JOURNAL_SEQUENCES := {"CAN_EXIT":"tavern_after_farewell","CAN_LEAVE":"tavern_after_farewell","CHUT_KILL":"stones","CHUT_ATTACK":"kelsrick_attacked_then_hut"}
const ENTRANCE := [Vector2(4164,2540),Vector2(4324,2190),Vector2(4364,2210),Vector2(4204,2560)]
const VILLAGE_ENTRANCE := [Vector2(-1624,-4037),Vector2(-1565,-4021),Vector2(-1613,-3732),Vector2(-1729,-3790)]
var view: Control
var backdrop: ColorRect
var back: Button
var held: OptionButton
var give: Button
var hotspots: Array[Control] = []
## CHUT stone piles (CHUT.SHP frames 0/1 at (274,169) and (374,169)) shown while flag 150 (tools/prepare_chut_branch_media.py).
var chut_stones: Dictionary = {}
const CHUT_BRANCHES := "res://assets/lol2/generated/chut_branches/clips.json"
const CHUT_STONE_IDS := ["jungle:chut:Ancients_Stone_1","jungle:chut:Ancients_Stone_2","jungle:chut:Ancients_Stone_3","jungle:chut:Ancients_Stone_4","jungle:chut:Ancients_Stone_5","jungle:chut:Ancients_Stone_6"]
const CHUT_STONE_FLAGS := ["154","155","156","157","158","159"]
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
	for data in [[Rect2(0,106,87,227),"MCEL","MENT"],[Rect2(272,132,119,167),"MGAR","MENT"],[Rect2(140,106,95,217),"MLIB","MENT"],[Rect2(431,152,179,161),"MOFF","MENT"],[Rect2(244,220,142,90),"CAN","VILLAGE"],[Rect2(425,211,151,99),"LIZ","VILLAGE"]]:
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
	# MCEL hotspot1 (setup 0x4A8, click 0x658): host 0xA30 (5618, -2369) + exit_room, no flag test: the passage into
	# the isolated Jungle pocket whose region3205 leads to Dark Halls (dark_halls_route.gd).
	if preload("res://scripts/lol2/dark_halls_route.gd").assets_ready():
		var cellar: Dictionary = preload("res://scripts/lol2/dark_halls_route.gd").catalog().cellar
		var passage := Control.new()
		passage.position = Vector2(cellar.rect[0],cellar.rect[1]); passage.size = Vector2(cellar.rect[2]-cellar.rect[0],cellar.rect[3]-cellar.rect[1])
		passage.set_meta("room","MCEL")
		passage.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		view.canvas.add_child(passage)
		passage.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: cellar_passage())
		hotspots.append(passage)
	# LIZ hotspot0: wax; hotspots1..4: native generic responses, once per room load.
	var wax := Control.new()
	wax.position = Vector2(91,282); wax.size = Vector2(55,57); wax.set_meta("room","LIZ")
	wax.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	view.canvas.add_child(wax)
	wax.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: take_wax())
	hotspots.append(wax)
	# CHUT branches: Anyar's lines 365/366/367/998, the cues 100:17 and 2:30, the two stone piles (CHUT_BRANCHES_DECODE_20261027).
	if view.manifest.rooms.has("CHUT") and FileAccess.file_exists(CHUT_BRANCHES):
		var branches: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CHUT_BRANCHES))
		var seq: Dictionary = view.manifest.rooms.CHUT.get("sequences",{})
		seq["CHUT_ATTACK"] = [branches.clips["29:365:6"]]
		seq["CHUT_KILL"] = [branches.clips["29:998:6"],branches.cues["100:17:24"]]
		seq["CHUT_REFUSE"] = [branches.clips["29:366:6"],branches.clips["29:367:6"]]
		seq["CHUT_STONE"] = [branches.cues["2:30:24"]]
		view.manifest.rooms.CHUT.sequences = seq
		for pair in [[0,Vector2(274,169)],[1,Vector2(374,169)]]:
			var info: Dictionary = branches.sprites[str(pair[0])]
			var sprite := TextureRect.new()
			sprite.texture = ImageTexture.create_from_image(Image.load_from_file(info.path))
			sprite.position = pair[1]; sprite.size = Vector2(info.width,info.height)
			sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE; sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.visible = false
			view.canvas.add_child(sprite); view.canvas.move_child(sprite,view.patch.get_index())
			chut_stones[pair[0]] = sprite
			var hit := Control.new()
			hit.position = pair[1]; hit.size = Vector2(info.width,info.height); hit.set_meta("room","CHUT"); hit.set_meta("chut_stone",pair[0])
			hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			view.canvas.add_child(hit)
			hit.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: take_stone())
			hotspots.append(hit)
	var liz_source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/liz_room_source.json"))
	for index in range(1,5):
		var rect: Array = liz_source.hotspots[index].rect
		var hit := Control.new()
		hit.position = Vector2(rect[0],rect[1]); hit.size = Vector2(rect[2]-rect[0],rect[3]-rect[1])
		hit.set_meta("room","LIZ"); hit.set_meta("liz_hotspot",index)
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		view.canvas.add_child(hit)
		hit.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: liz_response(index))
		hotspots.append(hit)
	restore()
func active() -> bool:
	return available and not str(state().get("room","")).is_empty()
func enter_room(destination: String) -> bool:
	var s := state()
	_sync_dawn_locals(s)
	var current: String = s.get("room","")
	if Speech.active(s.get("conversation",Speech.initial())): return false
	if destination in ["MENT","VILLAGE","CHUT"]:
		if not current.is_empty() or not view.manifest.rooms.has(destination): return false
	elif destination == "CAN":
		if current != "VILLAGE" or s.flags.get("267",0) != 0: return false
	elif destination == "LIZ":
		# VILLAGE hotspot3 (0x591): room("liz_") with no flag test.
		if current != "VILLAGE": return false
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
	if destination == "CHUT":
		s.chut_attacked = false # the DLL static [0xD74], zero at every load
		# The DLL static [0xD78] ("Anyar is in the hut"): 1 at every load, cleared by setup 0x47C only when flag 153 is
		# set and 150 clear; nothing clears it inside a visit, so the dead speech leaves her idle until the next entry.
		s.anyar_present = not (s.flags.get("153",0) != 0 and s.flags.get("150",0) == 0)
	if destination != "MENT": Speech.begin(s,destination)
	restore()
	return true
## Jungle local17 "Gave_Dawn_Runes" is written by Dawn actor63's wax-runes offer (jungle_dawn owns it); the library
## DLL reads the same native local by name, so the monastery bank follows Dawn's copy.
func _sync_dawn_locals(s: Dictionary) -> void:
	var dawn = get_parent().get("dawn")
	var given := 0
	if dawn != null and is_instance_valid(dawn) and dawn.get("state") is Dictionary: given = int(dawn.state.get("locals",{}).get("17",0))
	else: given = int(get_parent().quest_state.get("jungle_dawn",{}).get("locals",{}).get("17",0))
	if given != 0: s.locals.Gave_Dawn_Runes = 1
## MCEL hotspot1: close the room and stand the player at the original pocket point (region3191), then take the
## pocket's region3205 route to Dark Halls directly (dark_halls_route.gd enter_directly).
func cellar_passage() -> bool:
	var s := state()
	if not active() or s.get("room","") != "MCEL" or Speech.active(s.get("conversation",Speech.initial())): return false
	var route = get_parent().get_node_or_null("DarkHallsRoute")
	if route == null: return false
	var a: Array = preload("res://scripts/lol2/dark_halls_route.gd").catalog().cellar.arrival
	s.room = ""
	get_parent().player.position = Vector3(a[0],a[1],a[2])
	get_parent().player.velocity = Vector3.ZERO
	was_inside = false
	restore()
	return route.enter_directly()
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
	elif s.room == "CHUT":
		# Callback8 (0x866): place(-1769, 5464), host 0xF0(150), exit_room.
		_chut_leave()
		return
	elif s.room == "LIZ":
		# Callback8 (0x63D): room("VILLAGE_"), exit_room.
		s.room = "VILLAGE"
	elif s.room == "CAN":
		# Message8 (0x91B): walk-out (0xE09) while flag37 is set, else Bacatta's leave-taking before the farewell.
		if Speech.begin_can_exit(s):
			refresh_speech()
			return
		s.room = "VILLAGE"
	elif s.room == "MLIB":
		# Source message8 (0x6C0): Dawn's rune translation and Dampen charm, else straight to the hall.
		_sync_dawn_locals(s)
		if Speech.begin_mlib_exit(s):
			refresh_speech()
			return
		s.room = "MENT"
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
	if item in [Speech.ORB,Speech.DAMPEN] and not preload("res://scripts/lol2/jungle_save.gd").validate_inventory({"collected":carried+[item],"equipped_item":"","equipped_armor":""}).is_empty():
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
	held.visible = room == "MOFF" or (room == "MGAR" and s.get("side_actor_present",false)) or room == "CHUT"
	give.visible = held.visible
	var previous_item := str(held.get_item_metadata(held.selected)) if held.selected >= 0 and held.selected < held.item_count else ""
	held.clear()
	held.add_item("Empty hand")
	held.set_item_metadata(0,"")
	# Presentation adapter (owner r12e report 1): with a full pack the selector list scrolls, so rune copies come first.
	var runes := preload("res://scripts/lol2/hive_rune_items.gd")
	for item in preload("res://scripts/lol2/hand_selector_order.gd").wanted_first(get_parent().carried_collected,runes.valid):
		held.add_item("Wax runes" if runes.valid(item) else str(item).get_slice(":",2).replace("_"," "))
		held.set_item_metadata(held.item_count-1,item)
		if item == previous_item: held.select(held.item_count-1)
	shown_cursor = -1
	get_parent().set_physics_process(room.is_empty())
	if is_instance_valid(get_parent().interface_hud): get_parent().interface_hud.visible = room.is_empty()
	if room.is_empty():
		# A restored position already inside an entrance is not a new entry (as jungle_village_gate.restore): a save
		# made in the tavern doorway must not re-enter VILLAGE on load. Leaving and re-entering still fires.
		was_inside = _entrance_contact()
		view.voice.stop()
		view.background.stop()
		for key in ["magic_shop","weapon_shop","thieves_den"]:
			var other = get_parent().get(key)
			if is_instance_valid(other) and other.active(): return
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view.enter_room(room)
	for hit in hotspots: hit.visible = room == hit.get_meta("room") and (not hit.has_meta("chut_stone") or s.flags.get("150",0) != 0)
	refresh_speech()
func refresh_speech() -> void:
	var s := state()
	var speech: Dictionary = s.get("conversation",Speech.initial())
	if shown_sequence != speech.sequence:
		shown_sequence = speech.sequence
		shown_cursor = -1
	var speaking := Speech.active(speech)
	if speaking and JOURNAL_SEQUENCES.has(speech.sequence): MyJournal.discover(get_parent(), JOURNAL_SEQUENCES[speech.sequence])
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
	for id in chut_stones: chut_stones[id].visible = shown_room == "CHUT" and s.flags.get("150",0) != 0
	if shown_room == "CHUT" and not speaking:
		# Setup 0x47C: with flag 150 the stone piles replace Anyar; the hut is empty when setup cleared [0xD78] (153 set
		# and 150 clear at entry); else idle(29, 999 / 995 when GV_KELSRICK_DEAD, 6); the dead branch returns to this idle
		# without leaving the room (older saves predate anyar_present: the static's initial value 1, present).
		if s.flags.get("150",0) != 0 or not s.get("anyar_present",true):
			view.patch.texture = null; view.clip = {}; view.visual = {}; view.voice.stop()
			return
		if not view.clip.get("idle",false): view.play_idle(0.0,"idle_dead" if _kelsrick_dead() else "idle")
		return
	if shown_room == "CAN" and not speaking and State.bacatta_present(s):
		if not view.clip.get("idle",false): view.play_idle()
		return
	if speech.sequence.is_empty() or Speech.room_for(speech.sequence) != shown_room: return
	var index := mini(int(speech.cursor),Speech.FRAMES[speech.sequence].size()-1)
	if index != shown_cursor:
		shown_cursor = index
		view.play_patch(index,float(speech.elapsed) if speaking else Speech.duration(speech.sequence,index),speech.sequence)
		# LIZ/CHUT cues are audio-only sound-bank requests: show the room background, not the intro's last frame.
		if shown_room in ["LIZ","CHUT"] and int(view.clip.get("frames",0)) == 0: view.patch.texture = null
	view.elapsed = float(speech.elapsed) if speaking else float(view.clip.duration)
	view.set_time(view.elapsed)
	if not speaking: view.voice.stop()
func advance(delta: float) -> void:
	if not active(): return
	var rewards := Speech.advance(state(),delta)
	for item in rewards:
		if item is Dictionary and item.has("huline_alert"):
			# GV_HULINE_ALERT has one owner (the village gate's shared29); the room bank only requests the write.
			if get_parent().has_method("raise_huline_alert"): get_parent().raise_huline_alert()
		elif item is Dictionary and item.has("chut_exit"):
			_chut_leave()
			return
		elif item is Dictionary and item.has("chut_exit_attack"):
			_chut_leave(CHUT_PLACE_ATTACK,CHUT_HEADING_ATTACK)
			return
		elif item is Dictionary and item.has("morgan_heal"):
			# Playable health currently caps at30; native progression health is separate.
			get_parent().health = preload("res://scripts/lol2/morgan_orb_blessing.gd").heal(get_parent().health,30)
		else: grant(item)
	if not rewards.is_empty(): restore()
	var speech: Dictionary = state().get("conversation",Speech.initial())
	if state().room == "MOFF" and Speech.is_moff_exit(speech.sequence) and not Speech.active(speech):
		state().room = "MENT"
		restore()
		return
	if state().room == "MLIB" and speech.sequence == "MLIB_EXIT_RUNES" and not Speech.active(speech):
		state().room = "MENT"
		restore()
		return
	# CHUT: callback9 (the first update) follows the hut-apr intro.
	if state().room == "CHUT" and speech.sequence == "CHUT" and not Speech.active(speech):
		chut_first_update()
		refresh_speech()
		return
	# LIZ: the first update (callback9, cue 2:59) follows the intro.
	if state().room == "LIZ" and speech.sequence == "LIZ" and not Speech.active(speech):
		state().conversation = {"sequence":"LIZ_ENTRY","cursor":0,"elapsed":0.0}
		refresh_speech()
		return
	if state().room == "CAN" and speech.sequence in ["CAN_EXIT","CAN_MAID","CAN_LEAVE"] and not Speech.active(speech):
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
	for key in ["magic_shop","weapon_shop","departure","thieves_den"]:
		var other = get_parent().get(key)
		if is_instance_valid(other) and other.active(): return
	var inside := _in_entrance()
	var village_inside := _in_village_entrance()
	if (inside or village_inside) and not was_inside:
		# Region3501 event2 also runs g7092: Left_Village 0 -> 2 (docs/tavern-return.md).
		if village_inside: _left_village(0,2)
		enter_room("MENT" if inside else "VILLAGE")
	was_inside = inside or village_inside
func _in_entrance() -> bool:
	var position: Vector3 = get_parent().player.position
	return absf(position.y-42.0) < 48.0 and Geometry2D.is_point_in_polygon(Vector2(position.x,position.z),PackedVector2Array(ENTRANCE))
func _in_village_entrance() -> bool:
	var position: Vector3 = get_parent().player.position
	return view.manifest.rooms.has("VILLAGE") and absf(position.y-32.0) < 48.0 and Geometry2D.is_point_in_polygon(Vector2(position.x,position.z),PackedVector2Array(VILLAGE_ENTRANCE))
func _entrance_contact() -> bool:
	return is_instance_valid(get_parent().player) and (_in_entrance() or _in_village_entrance())
func _unhandled_input(event: InputEvent) -> void:
	if not active() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE: leave_room()
	# Room messages7/6 come from the player's Use Weapon (original key F) and Cast Spell actions inside a room.
	elif event.keycode in [KEY_F,KEY_Q] and attack(7 if event.keycode == KEY_F else 6): pass
	elif event.keycode == KEY_F5: get_parent().quicksave()
	elif event.keycode == KEY_F9: get_parent().quickload()
	else: return
	get_viewport().set_input_as_handled()

## L4_HJ local36 "Left_Village" writes: region3501 g7092 (0 -> 2) and region3805 g7950 (2 -> 3), each under its
## source predicate. Returns true when the value changed.
func left_village(from: int, to: int) -> bool: return _left_village(from,to)
func _left_village(from: int, to: int) -> bool:
	var s := state()
	if int(s.locals.get("Left_Village",0)) != from: return false
	s.locals.Left_Village = to
	return true

## LIZ hotspot0 (0x5A7): while flag162 is clear, set it, play cue 100:2 and give one "71-Wax" (the existing beehive
## pool). Modern adapter: a full inventory or an exhausted pool refuses and leaves 162 clear, so the pickup can be retried.
func take_wax() -> bool:
	var s := state()
	if not active() or s.room != "LIZ" or Speech.active(s.get("conversation",Speech.initial())) or s.flags.get("162",0) != 0: return false
	var carried: Array = get_parent().carried_collected
	var id: String = preload("res://scripts/lol2/jungle_beehive_wax.gd").next_free(carried)
	if id.is_empty() or carried.size() >= preload("res://scripts/lol2/item_catalog.gd").MAX_CARRIED:
		get_parent().save_feedback("You cannot carry more.")
		return true
	s.flags["162"] = 1
	carried.append(id)
	s.conversation = {"sequence":"LIZ_WAX","cursor":0,"elapsed":0.0}
	get_parent().save_feedback("Wax added to inventory.")
	restore()
	return true

func attack(message: int) -> bool:
	var s := state()
	if active() and s.room == "CHUT": return chut_attack()
	if not active() or s.room != "MLIB" or not Speech.begin_attack(s,message): return false
	refresh_speech()
	return true

## ---- CHUT branches (CHUT_BRANCHES_DECODE_20261027) ----------------------------------------------------------------
## Callbacks 6/7 (0x6E8): nothing once the hut is empty (153 without 150) or the stones are out (150); else branch A
## when the hut was entered with Kelsrick attacked ([0xD74]): Anyar_Attacked, the alert, line 365, thrown out at
## (-1749, 5457) facing 286; else branch B: Anyar_Attacked, the alert, Soul -1, flag 150, her death 998, the stone
## piles, cue 100:17.
func chut_attack() -> bool:
	var s := state()
	if not active() or s.room != "CHUT" or Speech.active(s.get("conversation",Speech.initial())): return false
	if s.flags.get("150",0) != 0 or s.flags.get("153",0) != 0: return false
	if not s.get("chut_attacked",false) and not s.get("anyar_present",true): return false # [0xD78] clear: nothing
	_anyar_attacked()
	if s.get("chut_attacked",false):
		s.conversation = {"sequence":"CHUT_ATTACK","cursor":0,"elapsed":0.0}
	else:
		var soul := int(s.globals.get("GV_LUTHERS_SOUL",preload("res://scripts/lol2/shared_global_defaults.gd").initial_value("GV_LUTHERS_SOUL")))
		s.globals["GV_LUTHERS_SOUL"] = clampi(soul-1,0,10)
		s.flags["150"] = 1
		s.conversation = {"sequence":"CHUT_KILL","cursor":0,"elapsed":0.0}
	restore()
	return true
## Anyar_Attacked = 1 (L4_HJ local 33, Kelsrick's bank) and GV_HULINE_ALERT = 1 (the village gate's shared29).
func _anyar_attacked() -> void:
	var kelsrick = get_parent().get("kelsrick")
	if kelsrick != null and is_instance_valid(kelsrick) and kelsrick.get("state") is Dictionary and not kelsrick.state.is_empty(): kelsrick.state.locals["33"] = 1
	if get_parent().has_method("raise_huline_alert"): get_parent().raise_huline_alert()
## Callback 3 (0x594): while flag 150, a click on either pile gives the first clear of 154..159 ("66-Ancients stn"); the
## first also plays cue 2:30. Adapter: a full pack refuses before the flag is set.
func take_stone() -> bool:
	var s := state()
	if not active() or s.room != "CHUT" or Speech.active(s.get("conversation",Speech.initial())) or s.flags.get("150",0) == 0: return false
	for index in range(CHUT_STONE_FLAGS.size()):
		if s.flags.get(CHUT_STONE_FLAGS[index],0) != 0: continue
		var id: String = CHUT_STONE_IDS[index]
		var carried: Array = get_parent().carried_collected
		if id in carried or not preload("res://scripts/lol2/jungle_save.gd").validate_inventory({"collected":carried+[id],"equipped_item":"","equipped_armor":""}).is_empty():
			get_parent().save_feedback("You cannot carry more.")
			return true
		s.flags[CHUT_STONE_FLAGS[index]] = 1
		carried.append(id)
		if index == 0: s.conversation = {"sequence":"CHUT_STONE","cursor":0,"elapsed":0.0}
		get_parent().save_feedback("Ancients' Stone added to inventory.")
		restore()
		return true
	return false
const CHUT_PLACE_ATTACK := Vector2(-1749,-5457)
const CHUT_HEADING_ATTACK := 286.0

func offer_item(id: String) -> bool:
	var s := state()
	if s.room == "CHUT":
		# Message 5 (0x68B): a held item answers 366/367 only when the hut was entered with Kelsrick attacked.
		if Speech.active(s.get("conversation",Speech.initial())) or id.is_empty() or id not in get_parent().carried_collected or not s.get("chut_attacked",false): return false
		s.conversation = {"sequence":"CHUT_REFUSE","cursor":0,"elapsed":0.0}
		restore()
		return true
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

func liz_response(hotspot: int) -> bool:
	var s := state()
	if not active() or s.room != "LIZ" or Speech.active(s.get("conversation",Speech.initial())): return false
	var line := preload("res://scripts/lol2/liz_room_responses.gd").choose(s,hotspot)
	if line == 0: return false
	s.conversation = {"sequence":"LIZ_QUIP_%d" % line,"cursor":0,"elapsed":0.0}
	refresh_speech()
	return true

## Enter skips the line now playing (dialogue_skip.gd): the speech clock runs to the line's end through advance(), so its
## rewards, the next line and room exits follow as usual.
func skip_line() -> bool:
	if not available or get_tree().paused or not active(): return false
	var speech: Dictionary = state().get("conversation",Speech.initial())
	if not Speech.active(speech): return false
	advance(maxf(Speech.duration(speech.sequence,int(speech.cursor))-float(speech.elapsed),0.0))
	return true

## ---- Chief's hut CHUT (docs/jungle-chut-room.md) ---------------------------------------------------------------------
## Callback9: death branch precedes the attacked and peaceful-first-visit branches.
## Native 8F7 raises the shared alert before flag153 and the five lines; no auto-exit.
func chut_first_update() -> bool:
	var s := state()
	if s.flags.get("153",0) != 0: return false
	if _kelsrick_dead():
		if s.flags.get("150",0) != 0: return false
		if not get_parent().has_method("raise_huline_alert"): return false
		get_parent().raise_huline_alert()
		s.flags["153"] = 1
		s.conversation = {"sequence":"CHUT_DEAD","cursor":0,"elapsed":0.0}
		return true
	if _kelsrick_attacked():
		# 0x986: alive and Kelsrick_Attacked -> [0xD74] = 1 and branch A at once (365, thrown out, the alert).
		s.chut_attacked = true
		_anyar_attacked()
		s.conversation = {"sequence":"CHUT_ATTACK","cursor":0,"elapsed":0.0}
		return true
	if s.flags.get("152",0) != 0 or s.flags.get("150",0) != 0: return false
	s.flags["152"] = 1
	s.conversation = {"sequence":"CHUT_FIRST","cursor":0,"elapsed":0.0}
	return true
func _kelsrick_dead() -> bool:
	return int(state().globals.get("GV_KELSRICK_DEAD",0)) != 0
func _kelsrick_attacked() -> bool:
	var kelsrick = get_parent().get("kelsrick")
	return is_instance_valid(kelsrick) and kelsrick.state != null and int(kelsrick.state.get("locals",{}).get("52",0)) != 0
## place(-1769, 5464): native y is Godot -z (as the MCEL cellar placement). Host 0xF0(150) is read as a facing in
## degrees, 0 = map east, counterclockwise (all room-DLL 0xF0 arguments are 0..359; the longplay f_00756 returns Luther
## facing Kelsrick to the west): Godot yaw = degrees - 90.
const CHUT_PLACE := Vector2(-1769,-5464)
const CHUT_HEADING := 150.0
func _chut_leave(place: Vector2 = CHUT_PLACE, heading: float = CHUT_HEADING) -> void:
	var s := state()
	s.room = ""
	s.conversation = Speech.initial()
	var player: Node3D = get_parent().player
	player.position.x = place.x
	player.position.z = place.y
	player.rotation.y = deg_to_rad(heading-90.0)
	was_inside = false
	restore()

