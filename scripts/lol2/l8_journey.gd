extends CanvasLayer
## Modern first-departure encounter UI. Source behaviour: hintbook86-89/98.
## Temporary summary presentation/reach/entry anchor are adapter0209.
const State = preload("res://scripts/lol2/l8_journey_state.gd")
const KEY := "l8_journey"
const REACH := 160.0
const TARGETS := {"entry":Vector3(-3854,32,1190), "temple":Vector3(758,32,2046), "village":Vector3(676,32,-4541)}
var backroom: Node
var host: Node3D
var panel: PanelContainer
var box: VBoxContainer
var hint: Label
var opened := ""
var notice := ""
var previous_mouse := Input.MOUSE_MODE_CAPTURED
func state() -> Dictionary:
	return host.quest_state.get(KEY,State.initial())
func _ready() -> void:
	backroom = preload("res://scripts/lol2/l8_backroom.gd").new()
	backroom.host = host
	add_child(backroom)
	backroom.completed.connect(func():
		if not opened.is_empty(): refresh())
	name = "L8Journey"
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.position = Vector2(40,60)
	panel.custom_minimum_size = Vector2(540,180)
	add_child(panel)
	box = VBoxContainer.new()
	panel.add_child(box)
	panel.hide()
	hint = Label.new()
	hint.position = Vector2(24,300)
	add_child(hint)
func target() -> String:
	if not is_instance_valid(host.player): return ""
	var position: Vector3 = host.player.global_position
	var translation: Vector3 = host.native_translation if host.get("native_translation") != null else Vector3.ZERO
	for id in TARGETS:
		var destination: Vector3 = TARGETS[id]+translation
		if position.distance_to(destination)>REACH: continue
		var camera = host.get("camera")
		var origin: Vector3 = camera.global_position if is_instance_valid(camera) else position
		if origin.distance_to(destination)>1.0:
			var ray := PhysicsRayQueryParameters3D.create(origin,destination,1)
			if host.player is CollisionObject3D: ray.exclude = [host.player.get_rid()]
			if not host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		if id=="entry" and state().gift in ["recovered","returned"]: continue
		if id=="temple" and state().temple_visited: continue
		if id=="village" and not state().temple_visited: continue
		return id
	return ""
func permitted(action: String, location: String) -> bool:
	if action in ["initiation","shaman_silverleaf"]:return location=="village" and state().admitted
	if action=="backroom": return location=="village" and state().admitted
	if action.begins_with("herb:"): return location=="village" and state().admitted
	match action:
		"offer_daniel": return location=="entry" if state().gift=="unoffered" else location=="village"
		"hopper_interruption","recover_blade": return location=="entry"
		"visit_temple": return location=="temple"
		"show_guard","visit_shaman": return location=="village"
	return false
## Same semantic command for buttons and tests; caller cannot claim a remote target.
func interact(action: String, offered: String = "") -> Dictionary:
	var location := target()
	if location.is_empty() or not permitted(action,location): return {"ok":false,"reason":"Move to the encounter first."}
	if backroom.state().active: return {"ok":false,"reason":"Listen to the conversation first."}
	if action=="backroom":
		var news: Dictionary = backroom.start()
		if news.ok: notice = "You listen at the doorway. Enter skips a line."
		return news
	if action.begins_with("herb:"):
		var herb = preload("res://scripts/lol2/l8_herbalist.gd")
		var taken: Dictionary = herb.pick(host.quest_state.get("l8_herbalist",herb.initial()),host.carried_collected,action.get_slice(":",1),state().admitted)
		if taken.ok:
			host.quest_state.l8_herbalist=taken.state
			host.carried_collected=taken.inventory
			notice=taken.notice
		return taken
	if action in ["initiation","shaman_silverleaf"]:
		close()
		var trade:Dictionary=host.get_node("L8Tribe").offer(offered) if action=="initiation" else host.get_node("L8Tribe").offer_shaman(offered)
		host.save_feedback(trade.get("reason",""))
		return trade
	var result := State.act(state(),host.carried_collected,action,offered)
	if not result.ok: return result
	# No awaits/signals between these writes: one synchronous transaction.
	host.quest_state[KEY] = result.state
	host.carried_collected = result.inventory
	if host.get("equipped_item") == State.BLADE and State.BLADE not in result.inventory:
		host.equipped_item = ""
	notice = result.notice
	restore_world()
	return result
func restore_world() -> void:
	var population = host.get("act2_creatures")
	if not is_instance_valid(population): return
	var changed := false
	if state().temple_visited and population.state.actors.has("113"):
		changed = preload("res://scripts/lol2/scripted_creature_state.gd").spawn(population.state,"113")
	# Book87: the trio flees. Presentation uses saved presence, no reward replay.
	if state().gift in ["dropped","recovered","returned"]:
		for id in ["81","92","93"]:
			if population.state.actors.has(id) and population.state.actors[id].present:
				population.state.actors[id].present = false
				changed = true
	if changed:
		population.sync_quests()
		population.present()
func _process(_delta: float) -> void:
	restore_world()
	if not opened.is_empty(): return
	if get_tree().paused:
		hint.text = ""
		return
	var id := target()
	# HINTBOOK 2932-2941: the first approach plays the scene. L8 has no opcode 21 for that snatch.
	if id == "temple" and not bool(host.get("flying")):
		if not (host.has_method("actor_input_locked") and host.actor_input_locked()):
			interact("visit_temple")
			id = target()
	hint.text = "E — " + {"entry":"Meet Daniel","temple":"Visit the temple","village":"Speak at the village"}.get(id,"") if not id.is_empty() else ""
func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo: return
	if not opened.is_empty():
		if event.keycode==KEY_ESCAPE: close(); get_viewport().set_input_as_handled()
		return
	if get_tree().paused or host.get("flying") or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: return
	if is_instance_valid(host.get("inventory")): return
	if host.has_method("actor_input_locked") and host.actor_input_locked(): return
	if event.keycode==KEY_E and not target().is_empty():
		opened = target()
		previous_mouse = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
		refresh()
		get_viewport().set_input_as_handled()
func add_action(label: String, action: String, offered: String = "") -> void:
	var button := Button.new()
	button.text = label
	box.add_child(button)
	button.pressed.connect(func():
		var result := interact(action,offered)
		if not result.ok: notice = result.reason
		if not opened.is_empty():refresh())
func refresh() -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var text := Label.new()
	text.text = notice if not notice.is_empty() else {"entry":"Daniel and his companions are here.","temple":"An old priest stands at the temple.","village":"The village guard watches your approach."}.get(opened,"")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 520
	box.add_child(text)
	match opened:
		"entry":
			match state().gift:
				"unoffered": add_action("Offer grandfather's blade","offer_daniel",State.BLADE)
				"delivered": add_action("Continue the meeting","hopper_interruption")
				"dropped": add_action("Pick up the dropped blade","recover_blade")
		"temple":
			if not state().temple_visited: add_action("Approach the priest","visit_temple")
		"village":
			if not state().admitted: add_action("Show Daniel's blade","show_guard",State.BLADE)
			else:
				if host.has_node("L8Tribe") and host.get_node("L8Tribe").state().phase=="idle":
					for id in host.carried_collected:
						if preload("res://scripts/lol2/act2_items_catalog.gd").definition(id)==117:
							add_action("Offer Silverleaf — begin initiation","initiation",id);break
				if host.has_node("L8Tribe") and host.get_node("L8Tribe").State.member(host.get_node("L8Tribe").state()) and not preload("res://scripts/lol2/l8_shaman_trade.gd").completed(host.quest_state.get("l8_shaman_trade",{})):
					for id in host.carried_collected:
						if preload("res://scripts/lol2/act2_items_catalog.gd").definition(id)==117:
							add_action("Offer Silverleaf to the shaman","shaman_silverleaf",id);break
				if backroom.available() and backroom.state().completed<3: add_action("Visit the room behind the shaman","backroom")
				for kind in ["sap","amber","aloe"]:
					add_action("Herbalist — take " + {"sap":"ironwood sap","amber":"amber","aloe":"cave aloe"}[kind],"herb:"+kind)
				if state().gift=="recovered": add_action("Visit Daniel and return the blade","offer_daniel",State.BLADE)
				if not state().key_awarded: add_action("Visit the shaman","visit_shaman")
	var back := Button.new()
	back.text = "Return to the jungle"
	back.disabled = backroom.state().active
	back.pressed.connect(close)
	box.add_child(back)
	panel.show()
func close() -> void:
	if backroom.state().active: return
	panel.hide()
	opened = ""
	notice = ""
	get_tree().paused = false
	Input.mouse_mode = previous_mouse
func _exit_tree() -> void:
	if not opened.is_empty():
		get_tree().paused = false
		Input.mouse_mode = previous_mouse
