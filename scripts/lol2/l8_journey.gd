extends CanvasLayer
const Grants=preload("res://scripts/lol2/item_grants.gd")
## Modern first-departure encounter UI. Source behaviour: hintbook86-89/98.
## Temporary summary presentation/reach/entry anchor are adapter0209.
const State = preload("res://scripts/lol2/l8_journey_state.gd")
const KEY := "l8_journey"
const REACH := 160.0
## G1 (BJ14 F10): the native exit after the initiation (531, -4414) is 192 from the village point, so the village answers from 200.
const VILLAGE_REACH := 200.0
const TARGETS := {"entry":Vector3(-3854,32,1190), "temple":Vector3(758,32,2046), "village":Vector3(676,32,-4541)}
## Owner r17 stood at the village with the blade recovered and the temple unvisited. The journal note was not enough.
const TEMPLE_FIRST := "The village guard: Visit the Huline Temple first. It is east of the entry, on the far side of the map."
var backroom: Node
var host: Node3D
var panel: PanelContainer
var box: VBoxContainer
var hint: Label
var opened := ""
## The Wild Village is a special scene with several views (HINTBOOK 2984-3009: the herbalist's treehouse, the shaman's, the
## doorway right of the shaman, Daniel's). "" is the clearing; "herbalist" / "shaman" / "daniel" are the approached views.
var view := ""
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
		if position.distance_to(destination)>(VILLAGE_REACH if id=="village" else REACH): continue
		var camera = host.get("camera")
		var origin: Vector3 = camera.global_position if is_instance_valid(camera) else position
		if origin.distance_to(destination)>1.0:
			var ray := PhysicsRayQueryParameters3D.create(origin,destination,1)
			if host.player is CollisionObject3D: ray.exclude = [host.player.get_rid()]
			if not host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		if id=="entry" and state().gift in ["recovered","returned"]: continue
		if id=="temple" and state().temple_visited: continue
		# BJ12 (owner 2026-11-10): the village always answers. A player who walks here first is told what the guard wants.
		return id
	return ""
func permitted(action: String, location: String) -> bool:
	if action in ["initiation","shaman_silverleaf"]:return location=="village" and state().admitted
	if action=="backroom": return location=="village" and state().admitted
	if action=="mix": return location=="village" and state().admitted
	if action.begins_with("herb:"): return location=="village" and state().admitted
	match action:
		"offer_daniel": return location=="entry" if state().gift=="unoffered" else location=="village"
		"hopper_interruption","recover_blade": return location=="entry"
		"visit_temple": return location=="temple"
		"show_guard","visit_shaman": return location=="village" and state().temple_visited
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
	if action=="mix":
		# The shaman's table: Amaranth Serum and a Silverleaf become the Larkhon Vapors (the same mix as the pack's button).
		var guardian = host.get_node_or_null("L8Larkhon")
		var serums: Array = host.carried_collected.filter(func(id): return preload("res://scripts/lol2/act2_items_catalog.gd").definition(id)==119)
		if guardian==null or serums.is_empty(): return {"ok":false,"reason":"The mix needs the Amaranth Serum and a Silverleaf, as a man."}
		if not guardian.mix(str(serums[0]),true):
			var reason:Variant=guardian.get("mix_refusal")
			return {"ok":false,"reason":reason if reason is String and not reason.is_empty() else "The mix needs the Amaranth Serum and a Silverleaf, as a man."}
		notice = "You mix Silverleaf with Amaranth Serum: Larkhon Vapors. Activate them from the pack, then use them on the Larkhon's upper chest."
		return {"ok":true}
	if action.begins_with("herb:"):
		var herb = preload("res://scripts/lol2/l8_herbalist.gd")
		var taken: Dictionary = herb.pick(host.quest_state.get("l8_herbalist",herb.initial()),host.carried_collected,action.get_slice(":",1),state().admitted)
		if taken.ok:
			var admission:=Grants.transition(host,taken.inventory,{"l8_herbalist":taken.state})
			if not admission.ok:return admission
			notice=taken.notice
		return taken
	if action in ["initiation","shaman_silverleaf"]:
		var at_table: bool = opened=="village"
		close()
		var trade:Dictionary=host.get_node("L8Tribe").offer(offered) if action=="initiation" else host.get_node("L8Tribe").offer_shaman(offered)
		host.save_feedback(trade.get("reason",""))
		if action=="shaman_silverleaf" and at_table:
			# BJ12: the trade leaves Luther at the shaman's table, where the serum and a leaf can be mixed at once.
			opened = "village"; view = "shaman"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().paused = true
			notice = str(trade.get("reason","")) + (" It does nothing alone: mix it with a Silverleaf, here or from the pack." if trade.ok else "")
		return trade
	var result := State.act(state(),host.carried_collected,action,offered)
	if not result.ok: return result
	# No awaits/signals between these writes: one synchronous transaction.
	var admission:=Grants.transition(host,result.inventory,{KEY:result.state})
	if not admission.ok:return admission
	if host.get("equipped_item") == State.BLADE and State.BLADE not in result.inventory:
		host.equipped_item = ""
	notice = result.notice
	restore_world()
	return result
func restore_world() -> void:
	var population = host.get("act2_creatures")
	if not is_instance_valid(population): return
	var changed := false
	# BJ12: the guard also steps out for a player who reaches the village first (HINTBOOK 2978: "you've been spotted by a
	# Huline guard"), so the prompt there has someone to speak for it.
	var near: bool = is_instance_valid(host.player) and host.player.global_position.distance_to(TARGETS.village+(host.native_translation if host.get("native_translation") != null else Vector3.ZERO))<=REACH*2.0
	if (state().temple_visited or near) and population.state.actors.has("113"):
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
	if id == "village" and not state().admitted and state().gift not in ["recovered","returned"]:
		hint.text = "E — Speak with the village guard"
	elif id == "village" and not state().temple_visited:
		hint.text = TEMPLE_FIRST
	else:
		hint.text = "E — " + {"entry":"Meet Daniel","temple":"Visit the temple","village":"Speak at the village"}.get(id,"") if not id.is_empty() else ""
	if id == "village" and not state().temple_visited and is_instance_valid(host.get("interface_hud")):
		host.interface_hud.hint.text = hint.text
		host.interface_hud.save_notice_remaining = 0.2
func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo: return
	if not opened.is_empty():
		if event.keycode==KEY_ESCAPE: close(); get_viewport().set_input_as_handled()
		return
	if get_tree().paused or host.get("flying"): return
	# Headless has no window, so a captured mouse cannot stick. A real window still requires it.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless": return
	if is_instance_valid(host.get("inventory")): return
	# BJ12: a dead Luther does not talk (the walk probe opened the village panel at 0 health).
	if host.get("starting_magic") != null and host.starting_magic.health() <= 0: return
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
	var village_line := TEMPLE_FIRST if opened == "village" and not state().temple_visited else "The village guard watches your approach."
	text.text = notice if not notice.is_empty() else {"entry":"Daniel and his companions are here.","temple":"An old priest stands at the temple.","village":village_line}.get(opened,"")
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
			if str(state().get("gift", "")) not in ["recovered","returned"] and not state().admitted:
				text.text = "The village guard bars the way. " + State.NEED_DANIEL
			elif not state().temple_visited:
				pass
			elif not state().admitted:
				add_action("Show Daniel's blade","show_guard",State.BLADE)
			else:
				village_view(text)
	var back := Button.new()
	back.text = "Return to the jungle" if view.is_empty() or opened != "village" else "Step back to the clearing"
	back.disabled = backroom.state().active
	back.pressed.connect(close if view.is_empty() or opened != "village" else func(): show_view(""))
	box.add_child(back)
	panel.show()
## What the village asks of Luther next, from what he has earned (narration, never a quoted line).
func next_step() -> String:
	var Items = preload("res://scripts/lol2/act2_items_catalog.gd")
	var Tribe = preload("res://scripts/lol2/l8_tribe_state.gd")
	var quests: Dictionary = host.quest_state
	var leaf: bool = host.carried_collected.any(func(id): return Items.definition(id)==117)
	var serum: bool = host.carried_collected.any(func(id): return Items.definition(id)==119)
	if not state().key_awarded: return "The shaman in the middle treehouse is the one to see."
	if serum: return "The Amaranth Serum does nothing alone: mix it with a Silverleaf at the shaman's table, or from the pack."
	if Tribe.member(quests.get(Tribe.KEY,{})):
		if not preload("res://scripts/lol2/l8_shaman_trade.gd").completed(quests.get("l8_shaman_trade",{})): return "Luther is of the tribe. The shaman will trade his potion for a Silverleaf."
		return "The Larkhon guards the way to the Claw Mountains, across the river in the east."
	if leaf: return "A Silverleaf offered here begins the tribe's initiation."
	if bool(quests.get("l10_silverleaf",{}).get("grown",false)): return "Silverleaf grows on the dead trees of the Dracoid Cemetery now. Nine leaves are worth the walk."
	return "The shaman wants Silverleaf. His sigil opens the gate of the Dracoid Cemetery, east of the village; the dead there must be appeased first."
func show_view(id: String) -> void:
	view = id
	notice = ""
	refresh()
func add_view(label: String, id: String) -> void:
	var button := Button.new()
	button.text = label
	box.add_child(button)
	button.pressed.connect(func(): show_view(id))
## The admitted village: the clearing and its three treehouses, like the original scene's views.
func village_view(text: Label) -> void:
	var Items = preload("res://scripts/lol2/act2_items_catalog.gd")
	var tribe = host.get_node_or_null("L8Tribe")
	var leaves: Array = host.carried_collected.filter(func(id): return Items.definition(id)==117)
	match view:
		"herbalist":
			if notice.is_empty(): text.text = "The herbalist's treehouse. She does not mind if Luther takes from her jars."
			for kind in ["sap","amber","aloe"]:
				add_action("Take " + {"sap":"ironwood sap","amber":"amber","aloe":"cave aloe"}[kind],"herb:"+kind)
		"shaman":
			if notice.is_empty(): text.text = "The shaman's treehouse. " + next_step()
			if not state().key_awarded: add_action("Speak with the shaman until he gives the cemetery sigil","visit_shaman")
			if tribe!=null and tribe.State.member(tribe.state()) and not preload("res://scripts/lol2/l8_shaman_trade.gd").completed(host.quest_state.get("l8_shaman_trade",{})) and not leaves.is_empty():
				add_action("Offer a Silverleaf — he gives the Amaranth Serum","shaman_silverleaf",str(leaves[0]))
			if host.has_node("L8Larkhon") and host.carried_collected.any(func(id): return host.get_node("L8Larkhon").can_mix(id)):
				add_action("Mix the Amaranth Serum with a Silverleaf","mix")
			if backroom.available() and backroom.state().completed<3: add_action("Listen at the doorway to the right of the shaman","backroom")
		"daniel":
			if notice.is_empty(): text.text = "Daniel's treehouse."
			if state().gift=="recovered": add_action("Return his grandfather's blade","offer_daniel",State.BLADE)
			elif notice.is_empty(): text.text = "Daniel's treehouse. He has his grandfather's blade and little more to say."
		_:
			if notice.is_empty(): text.text = "The Wild Village. The herbalist's treehouse is on the left, the shaman's in the middle, Daniel's on the right. " + next_step()
			if tribe!=null and tribe.state().phase=="idle" and not leaves.is_empty():
				add_action("Present a Silverleaf — the initiation begins","initiation",str(leaves[0]))
			add_view("Approach the herbalist's treehouse","herbalist")
			add_view("Approach the shaman's treehouse","shaman")
			add_view("Approach Daniel's treehouse","daniel")
func close() -> void:
	if backroom.state().active: return
	panel.hide()
	opened = ""
	view = ""
	notice = ""
	get_tree().paused = false
	Input.mouse_mode = previous_mouse
func _exit_tree() -> void:
	if not opened.is_empty():
		get_tree().paused = false
		Input.mouse_mode = previous_mouse
