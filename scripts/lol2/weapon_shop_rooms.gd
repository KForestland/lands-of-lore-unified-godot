extends CanvasLayer
## Original WPNEXT/WPN entry and first-visit interactions, with modern action buttons.
const State = preload("res://scripts/lol2/weapon_shop_state.gd")
const View = preload("res://scripts/lol2/monastery_room_view.gd")
const MANIFEST := "res://assets/lol2/generated/weapon_shop/rooms.json"
var data: Dictionary
var view: Control
var back: Button
var held: OptionButton
var offer_button: Button
var actions: Dictionary = {}
var available := false
var was_inside := false
var shown_cursor := -1
var shown_sequence := ""
func state() -> Dictionary:
	var quests: Dictionary = get_parent().quest_state
	if not quests.has("weapon_shop"): quests.weapon_shop = State.initial()
	return quests.weapon_shop
func active() -> bool:
	return available and state().room != ""
func other_room_active() -> bool:
	for key in ["monastery","magic_shop","departure"]:
		var room = get_parent().get(key)
		if is_instance_valid(room) and room.active(): return true
	return false
func _ready() -> void:
	layer = 30
	available = FileAccess.file_exists(MANIFEST)
	if not available: return
	data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view = View.new()
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.set_process(false)
	view.manifest.rooms.merge(data.rooms)
	back = Button.new()
	back.text = "Back"
	back.position = Vector2(550,365)
	back.size = Vector2(80,28)
	view.canvas.add_child(back)
	back.pressed.connect(leave_room)
	var x := 8.0
	for entry in [["enter","Enter"],["shortsword","Talk"],["longarm","Long Arm"],["gargoyle","Bracers"],["orb","Firestorm"]]:
		var button := Button.new()
		button.text = entry[1]
		button.position = Vector2(x,365)
		button.size = Vector2(100,28)
		view.canvas.add_child(button)
		var action_name: String = entry[0]
		button.pressed.connect(func(): interact(action_name))
		actions[entry[0]] = button
		x += 105
	held=OptionButton.new()
	held.position=Vector2(16,333)
	held.size=Vector2(240,28)
	view.canvas.add_child(held)
	offer_button=Button.new()
	offer_button.text="Offer item"
	offer_button.position=Vector2(264,333)
	view.canvas.add_child(offer_button)
	offer_button.pressed.connect(func():
		if held.selected>=0: offer_item(str(held.get_item_metadata(held.selected))))
	restore()
	refresh_hand()
func refresh_hand() -> void:
	if not is_instance_valid(held): return
	var previous := str(held.get_item_metadata(held.selected)) if held.selected>=0 else ""
	held.clear()
	for id in get_parent().carried_collected:
		if preload("res://scripts/lol2/act_one_item_names.gd").source_name(id) not in ["83-Power orb","10-Th Dagger"]: continue
		held.add_item(str(id).get_slice(":",2).replace("_"," "))
		held.set_item_metadata(held.item_count-1,id)
		if id==previous: held.select(held.item_count-1)
func offer_item(id: String) -> bool:
	if not active() or state().room!="WPN" or State.active(state()) or id not in get_parent().carried_collected: return false
	var source := preload("res://scripts/lol2/act_one_item_names.gd").source_name(id)
	if source not in ["83-Power orb","10-Th Dagger"]: return false
	var effects := State.offer(state(),source)
	for effect in effects:
		if effect[0]=="consume_held": get_parent().carried_collected.erase(id)
	apply_effects(effects)
	refresh_hand()
	refresh()
	return true
func enter_exterior() -> bool:
	sync_shared_flags()
	if not available or other_room_active() or not State.enter_exterior(state()): return false
	restore()
	return true
func interact(action_name: String) -> bool:
	if not active() or State.active(state()): return false
	if action_name == "enter":
		if state().room != "WPNEXT" or not State.admitted(state()): return false
		State.enter_room(state())
		if not State.flag(state(),69) and state().globals.get("GV_KITYARA_DEAD",0)==0: apply_effects(State.begin(state(),"intro"))
		restore()
		return true
	if state().room != "WPN" or state().globals.get("GV_KITYARA_DEAD",0)!=0: return false
	if get_parent().quest_state.monastery.globals.get("GV_KNOWLEDGE_OF_POWER_ORB",0) != 0:
		state().globals["GV_KNOWLEDGE_OF_POWER_ORB"] = 1
	apply_effects(State.action(state(),action_name))
	refresh()
	return true
func apply_effects(effects: Array) -> void:
	var host = get_parent()
	for effect in effects:
		if effect[0] == "give_item":
			var id: String = State.ITEMS[effect[1]]
			if id not in host.carried_collected: host.carried_collected.append(id)
		elif effect[0] == "set_global":
			host.quest_state.monastery.globals[effect[1]] = effect[2]
	if not effects.is_empty(): refresh_hand()
func leave_room() -> void:
	if not active() or State.active(state()): return
	if state().room == "WPN": state().room = "WPNEXT"
	else:
		state().room = ""
		var player = get_parent().player
		# Source group continuation runs after the exterior closes; flags0x85 preserve height.
		player.position.x = data.return_pose.x
		player.position.z = data.return_pose.z
		player.rotation.y = wrapf(-float(data.return_pose.bearing)*TAU/65536.0,-PI,PI)
		player.velocity = Vector3.ZERO
		was_inside = true
	restore()
func sync_shared_flags() -> void:
	var globals: Dictionary=get_parent().quest_state.get("monastery",{}).get("globals",{})
	for key in ["GV_KITYARA_DEAD","GV_LUTHER_HAS_WARBLADE"]:
		if not globals.has(key) and not state().globals.has(key): continue
		state().globals[key]=maxi(int(globals.get(key,0)),int(state().globals.get(key,0)))

func restore() -> void:
	if not available: return
	sync_shared_flags()
	refresh_hand()
	visible = active()
	shown_cursor = -1
	shown_sequence = ""
	if not visible:
		view.voice.stop()
		view.background.stop()
		view.clip = {}
		if other_room_active(): return
		get_parent().set_physics_process(true)
		if is_instance_valid(get_parent().interface_hud): get_parent().interface_hud.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	get_parent().set_physics_process(false)
	if is_instance_valid(get_parent().interface_hud): get_parent().interface_hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view.enter_room(state().room)
	refresh()
func refresh() -> void:
	var speaking := State.active(state())
	var absent: bool=state().room=="WPN" and state().globals.get("GV_KITYARA_DEAD",0)!=0
	view.patch.visible=not absent
	held.visible=state().room=="WPN"
	offer_button.visible=held.visible
	held.disabled=speaking
	offer_button.disabled=speaking or held.item_count==0
	back.disabled = speaking
	for name in actions:
		actions[name].visible = (name == "enter") == (state().room == "WPNEXT")
		actions[name].disabled = speaking
	if absent:
		held.visible=false;offer_button.visible=false;back.disabled=false
		for button in actions.values(): button.visible=false
		view.voice.stop();view.clip={};view.patch.texture=null
		return
	if state().room == "WPNEXT": return
	if not speaking:
		if not view.clip.get("idle",false): view.play_idle()
		return
	if shown_cursor != int(state().cursor) or shown_sequence != state().sequence:
		shown_cursor = int(state().cursor)
		shown_sequence = state().sequence
		var effect: Array = State.Data.PLANS[shown_sequence][shown_cursor]
		view.manifest.rooms.WPN.movies = [data.media[State.movie_key(effect)]]
		view.play_patch(0,float(state().elapsed))
	view.set_time(float(state().elapsed))
func advance(delta: float) -> void:
	apply_effects(State.advance(state(),delta))
	refresh()
	if view.clip.get("idle",false): view.set_time(view.elapsed+delta)
func _process(delta: float) -> void:
	if not available or get_tree().paused: return
	if active():
		advance(delta)
		return
	if other_room_active(): return
	var p: Vector3 = get_parent().player.position
	var inside := false
	if absf(p.y-32.0) < 48:
		for polygon in data.entrances:
			var points := PackedVector2Array()
			for point in polygon: points.append(Vector2(point[0],point[1]))
			if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),points): inside = true
	if inside and not was_inside: enter_exterior()
	was_inside = inside
func _unhandled_input(event: InputEvent) -> void:
	if not active() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE: leave_room()
	elif event.keycode == KEY_F5: get_parent().quicksave()
	elif event.keycode == KEY_F9: get_parent().quickload()
	else: return
	get_viewport().set_input_as_handled()
