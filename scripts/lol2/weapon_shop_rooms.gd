extends CanvasLayer
const Grants=preload("res://scripts/lol2/item_grants.gd")
## Original WPNEXT/WPN entry and first-visit interactions, with modern action buttons.
const State = preload("res://scripts/lol2/weapon_shop_state.gd")
const View = preload("res://scripts/lol2/monastery_room_view.gd")
const MANIFEST := "res://assets/lol2/generated/weapon_shop/rooms.json"
## Longplay f_00580, side bars cropped, scaled onto the 640 by 400 room.
## Sword: the bright blade on the chest. Bow: decoded Firestorm icon, right end on the red tip.
## Bracer: top shelf, above the dagger blades. Clicks use the existing actions.
const SHELF_ACTION: Array[String] = ["shortsword", "orb", "gargoyle"]
const SHELF_RECT: Array[Rect2] = [Rect2(0, 249, 155, 27), Rect2(120, 340, 94, 12), Rect2(400, 136, 66, 25)]
const SHELF_ICON: Array[String] = [
	"res://assets/lol2/generated/weapon_shop/Short_Sword.png",
	"res://assets/lol2/generated/weapon_shop/Firestorm.png",
	"res://assets/lol2/generated/weapon_shop/Gargoyle_Bracers.png",
]
const SHELF_GONE: Array[int] = [62, 63, 64]
var data: Dictionary
var view: Control
var back: Button
var held: OptionButton
var offer_button: Button
var actions: Dictionary = {}
var shelf: Array[TextureRect] = []
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
	for key in ["monastery","magic_shop","departure","thieves_den"]:
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
	for index in SHELF_ACTION.size():
		var picture := TextureRect.new()
		picture.texture = ImageTexture.create_from_image(Image.load_from_file(SHELF_ICON[index]))
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.position = SHELF_RECT[index].position
		picture.size = SHELF_RECT[index].size
		picture.visible = false
		var action_name: String = SHELF_ACTION[index]
		picture.gui_input.connect(_shelf_input.bind(action_name))
		view.canvas.add_child(picture)
		view.canvas.move_child(picture, view.patch.get_index())
		shelf.append(picture)
	restore()
	refresh_hand()
func refresh_hand() -> void:
	if not is_instance_valid(held): return
	var offered:Array=get_parent().carried_collected.filter(func(id):return preload("res://scripts/lol2/act_one_item_names.gd").source_name(id) in ["83-Power orb","10-Th Dagger"])
	preload("res://scripts/lol2/item_choice_menu.gd").populate(held,offered,get_parent(),"")
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
			Grants.grant(host,id,{"cap":false,"duplicate":"skip"})
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
func _shelf_input(event: InputEvent, action_name: String) -> void:
	if not event is InputEventMouseButton: return
	var button := event as InputEventMouseButton
	if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed: return
	if interact(action_name): view.canvas.accept_event()
func _show_shelf(present: bool) -> void:
	for index in shelf.size():
		var show_picture: bool = present and state().room == "WPN" and not State.flag(state(), SHELF_GONE[index])
		shelf[index].visible = show_picture
		shelf[index].mouse_filter = Control.MOUSE_FILTER_STOP if show_picture else Control.MOUSE_FILTER_IGNORE
func refresh() -> void:
	var speaking := State.active(state())
	var absent: bool=state().room=="WPN" and state().globals.get("GV_KITYARA_DEAD",0)!=0
	view.patch.visible=not absent
	_show_shelf(not absent)
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

## Enter skips the line now playing (dialogue_skip.gd): the plan clock runs to the current movie's end through advance().
func skip_line() -> bool:
	if not available or get_tree().paused or not active() or not State.active(state()): return false
	var effect: Array = State.Data.PLANS[state().sequence][int(state().cursor)]
	if effect[0] != "movie": return false
	advance(maxf(State.Data.DURATIONS[State.movie_key(effect)]-float(state().elapsed),0.0))
	return true
