extends CanvasLayer
const PlayerHealth=preload("res://scripts/lol2/player_health.gd")
const PlayerCombat=preload("res://scripts/lol2/player_combat.gd")
## Collected items and independent weapon/armor selection; the host owns combat.
var item_ids: Array = []
var previous_mouse := Input.MOUSE_MODE_VISIBLE
var previous_pause := false
var session_tree: SceneTree
var item_list: ItemList
var closed := false
var return_to_game: Callable
var detail_name: Label
var detail_text: Label
var detail_icon: TextureRect
var equipped_item := ""
var equipped_armor := ""
var change_armor: Callable
var change_equipment: Callable
var hold_item: Callable
var held_item_id := ""
## Host wording for the hold action (Museum exhibit by default; Jungle offers to actors).
var hold_label := "Hold for exhibit"
var hold_button: Button
var use_item: Callable
var mix_button: Button
var use_button: Button
var equip_button: Button
var selected_index := -1

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	session_tree = get_tree()
	previous_mouse = Input.mouse_mode
	previous_pause = session_tree.paused
	session_tree.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Original layout (intrface.shp pieces, classic_interface pack; reference longplay 28m30s): a red 4x5 item grid
	# docked above the bottom-right HUD cluster with stat rows and a 2x3 equipment block beside it; the world stays
	# visible. Presentation only: the item, equip, use and hold logic below is unchanged.
	var theme_res := preload("res://scripts/lol2/museum_ui_theme.gd").create()
	var background := ColorRect.new()
	background.theme = theme_res
	background.color = Color(0,0,0,0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	# Item cells are 24 px art at 2x; smaller windows use 1.5x so the panel stays clear of the screen top.
	var k := 2.0 if get_viewport().get_visible_rect().size.y >= 680 else 1.5
	var panel := PanelContainer.new()
	panel.name = "ClassicInventory"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("3a0f0c")
	style.border_color = Color("d4a93c")
	style.set_border_width_all(3)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	background.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",4)
	panel.add_child(box)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",4)
	box.add_child(columns)
	item_list = ItemList.new()
	item_list.name = "ItemGrid"
	item_list.max_columns = 4
	item_list.same_column_width = true
	item_list.fixed_column_width = int(24 * k) - 4
	item_list.icon_mode = ItemList.ICON_MODE_TOP
	item_list.fixed_icon_size = Vector2i(int(22 * k), int(22 * k))
	item_list.custom_minimum_size = Vector2(24 * k * 4 + 4, 24 * k * 5 + 4)
	item_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	item_list.add_theme_constant_override("h_separation", 4)
	item_list.add_theme_constant_override("v_separation", 4)
	item_list.add_theme_color_override("font_color", Color(0,0,0,0))
	item_list.add_theme_color_override("font_selected_color", Color(0,0,0,0))
	item_list.add_theme_color_override("font_hovered_color", Color(0,0,0,0))
	item_list.add_theme_font_size_override("font_size", 1)
	item_list.add_theme_stylebox_override("panel", _tile_style(78, k))
	var selected_style := StyleBoxFlat.new()
	selected_style.draw_center = false
	selected_style.border_color = Color("f2d36b")
	selected_style.set_border_width_all(2)
	for name in ["selected", "selected_focus", "cursor", "cursor_unfocused"]: item_list.add_theme_stylebox_override(name, selected_style)
	columns.add_child(item_list)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	columns.add_child(side)
	stat_bars.clear()
	for row in [[111, "Defense"], [112, "Health"], [113, "Attack"], [114, "Ranged"]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 3)
		var stat_icon := TextureRect.new()
		stat_icon.texture = _interface_texture(int(row[0]))
		stat_icon.custom_minimum_size = Vector2(10, 8) * k
		stat_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stat_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stat_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		stat_icon.tooltip_text = str(row[1])
		line.add_child(stat_icon)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(39 * k * 0.9, 4 * k + 2)
		bar.tooltip_text = str(row[1])
		var fill := StyleBoxFlat.new(); fill.bg_color = Color("c0392b")
		var back := StyleBoxFlat.new(); back.bg_color = Color("2a0806"); back.border_color = Color("8f7950"); back.set_border_width_all(1)
		bar.add_theme_stylebox_override("fill", fill); bar.add_theme_stylebox_override("background", back)
		line.add_child(bar)
		stat_bars[str(row[1])] = bar
		side.add_child(line)
	var slots := GridContainer.new()
	slots.columns = 2
	slots.add_theme_constant_override("h_separation", 2)
	slots.add_theme_constant_override("v_separation", 2)
	side.add_child(slots)
	equipment_slots.clear()
	for index in 6:
		var slot := Button.new()
		slot.name = "EquipmentSlot%d" % index
		slot.custom_minimum_size = Vector2(24, 24) * k
		slot.focus_mode = Control.FOCUS_NONE
		slot.add_theme_stylebox_override("normal", _tile_style(86, k))
		slot.add_theme_stylebox_override("hover", _tile_style(86, k))
		slot.add_theme_stylebox_override("pressed", _tile_style(86, k))
		var ghost := TextureRect.new()
		ghost.texture = _interface_texture(87 + index)
		ghost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(ghost)
		var worn := TextureRect.new()
		worn.name = "Worn"
		worn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		worn.offset_left = 4; worn.offset_top = 4; worn.offset_right = -4; worn.offset_bottom = -4
		worn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		worn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		worn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		worn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(worn)
		var role: String = SLOT_ROLES[index]
		slot.tooltip_text = role.capitalize() if role != "" else ""
		slot.pressed.connect(func(): unequip_slot(role))
		slot.set_drag_forwarding(Callable(), func(_at, data): return _can_drop(role, data), func(_at, data): _drop(role, data))
		slots.add_child(slot)
		equipment_slots.append(slot)
	var seen: Array = []
	for id in item_ids:
		if id in seen: continue
		seen.append(id)
		var name_text := "Unidentified item"
		var icon: Texture2D
		if preload("res://scripts/lol2/cave_captain_items.gd").valid(id):
			name_text=preload("res://scripts/lol2/cave_captain_items.gd").label(id)
		elif id == "museum:item11:Fine_Longsword":
			name_text = "Fine Longsword"
		elif id == "museum:item10:Mail_Shirt":
			name_text = "Mail Shirt"
		elif id in ["museum:item8:Champion_Stone", "museum:item9:Champion_Stone"]:
			name_text = "Champion Stone"
		elif preload("res://scripts/lol2/hive_rune_items.gd").valid(id):
			name_text = "Wax runes"
		elif id == preload("res://scripts/lol2/hive_ancient_stone.gd").ITEM:
			name_text = "Ancients’ Stone"
		elif id == preload("res://scripts/lol2/hive_wax.gd").ITEM:
			name_text = "Wax"
		elif not preload("res://scripts/lol2/shop_item_inventory.gd").info(id).is_empty():
			name_text = str(preload("res://scripts/lol2/shop_item_inventory.gd").info(id).label)
		elif id in preload("res://scripts/lol2/weapon_shop_state.gd").ITEMS.values():
			name_text = str(id).get_slice(":",2).replace("_"," ")
		elif id == preload("res://scripts/lol2/monastery_conversation.gd").FLUTE: name_text = "Iron Flute"
		elif id == "draracle/prop/1108/sample": name_text = "Cavern find (unidentified)"
		elif preload("res://scripts/lol2/cave_aloe.gd").valid_item(id): name_text = "Cave Aloe"
		elif preload("res://scripts/lol2/cave_stalagmite.gd").valid_item(id):
			name_text = "Stalagmite"
		# Generic catalog presentation for identities without a dedicated branch (e.g. cave guard drops).
		if name_text == "Unidentified item" and preload("res://scripts/lol2/item_catalog.gd").known(id):
			name_text = preload("res://scripts/lol2/item_catalog.gd").label(id)
		# BJ13: the Larkhon recipe items read by their catalog names, not the raw definition labels ("Amaranth sr").
		if _larkhon_recipe(id) >= 0: name_text = str(preload("res://scripts/lol2/act2_items_catalog.gd").row(id).get("label", name_text))
		# Every picture comes from the catalog's original 24x24 inventory icon (the branches above set labels
		# only); the ground sprite remains for world billboards and for identities without a definition.
		var icon_path := preload("res://scripts/lol2/item_catalog.gd").inventory_icon(id)
		if not icon_path.is_empty() and FileAccess.file_exists(icon_path): icon = ImageTexture.create_from_image(Image.load_from_file(icon_path))
		item_list.add_item(name_text,icon)
		item_list.set_item_metadata(item_list.item_count - 1, id)
	item_list.item_activated.connect(activate_item)
	# BJ14 F7: with more than four rows of items the grid scrolls; show the newest item (the last gained) and say so.
	if item_list.item_count > 20:
		var more := Label.new()
		more.name = "ScrollHint"
		more.text = "Mouse wheel: more items"
		more.add_theme_font_size_override("font_size", 11)
		box.add_child(more)
		box.move_child(more, columns.get_index() + 1)
		(func(): if is_instance_valid(item_list): item_list.get_v_scroll_bar().value = item_list.get_v_scroll_bar().max_value).call_deferred()
	item_list.item_clicked.connect(func(index, _at, button):
		if button == MOUSE_BUTTON_RIGHT:
			select_item(index)
			show_item_menu())
	item_list.set_drag_forwarding(func(at): return _drag_item(at), func(at, data): return _can_combine(at, data), func(at, data): _combine(at, data))
	var details := HBoxContainer.new()
	details.add_theme_constant_override("separation", 6)
	box.add_child(details)
	detail_icon = TextureRect.new()
	detail_icon.custom_minimum_size = Vector2(48, 32)
	detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	details.add_child(detail_icon)
	var description := VBoxContainer.new()
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(description)
	detail_name = Label.new()
	detail_name.add_theme_color_override("font_color", Color("f2d36b"))
	description.add_child(detail_name)
	detail_text = Label.new()
	detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_text.custom_minimum_size = Vector2(250, 0)
	detail_text.add_theme_font_size_override("font_size", 13)
	description.add_child(detail_text)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	box.add_child(actions)
	equip_button = Button.new()
	equip_button.text = "Equip"
	equip_button.disabled = true
	equip_button.pressed.connect(toggle_equipment)
	actions.add_child(equip_button)
	use_button = Button.new()
	use_button.text = "Play flute"
	use_button.hide()
	use_button.pressed.connect(use_selected_item)
	actions.add_child(use_button)
	if get_parent().has_node("L8Larkhon"):
		mix_button=Button.new();mix_button.text="Mix with Silverleaf";mix_button.hide();actions.add_child(mix_button)
		mix_button.pressed.connect(func():
			if selected_index>=0 and _try_larkhon_mix(str(item_list.get_item_metadata(selected_index))):close())
	hold_button = Button.new()
	hold_button.hide()
	hold_button.pressed.connect(func():
		if selected_index >= 0 and hold_item.is_valid() and hold_item.call(str(item_list.get_item_metadata(selected_index))): close())
	actions.add_child(hold_button)
	var close_button := Button.new()
	close_button.text = "Close · I"
	close_button.pressed.connect(close)
	actions.add_child(close_button)
	# BJ13: the panel docks to the right edge and grows left, so a wider button row would slide the grid out from under a drag.
	# Where the Mix button exists (the widest row), reserve that width once.
	if is_instance_valid(mix_button):
		use_button.show(); mix_button.show(); hold_button.show(); hold_button.text = hold_label
		box.custom_minimum_size.x = actions.get_combined_minimum_size().x
		detail_text.custom_minimum_size.y = detail_text.get_line_height() * 3
		use_button.hide(); mix_button.hide(); hold_button.hide()
	item_list.item_selected.connect(select_item)
	if item_list.item_count > 0:
		var initial_index := 0
		for index in item_list.item_count:
			if item_list.get_item_metadata(index) == equipped_item:
				initial_index = index
				break
		item_list.select(initial_index)
		select_item(initial_index)
	else:
		detail_name.text = "No items collected."
		detail_text.text = "Items you collect will appear here."
	var note := Label.new()
	note.text = "Double-click: equip or use · Right-click: item menu · Drag to a slot"
	note.add_theme_font_size_override("font_size", 12)
	box.add_child(note)
	if item_list.item_count > 0: item_list.grab_focus()
	else: close_button.grab_focus()
	refresh_classic()
	# Item selection can reveal wider Use/Hold controls after the initial layout.
	docked_panel = panel
	panel.minimum_size_changed.connect(_dock_panel.bind(panel), CONNECT_DEFERRED)
	get_viewport().size_changed.connect(_dock_panel.bind(panel), CONNECT_DEFERRED)
	_dock_panel(panel)
	build_inventory_belt()

var docked_panel: Control
func dock() -> void: _dock_panel(docked_panel)

func _dock_panel(panel: Control) -> void:
	if not is_instance_valid(panel) or not panel.is_inside_tree(): return
	# Dock above the HUD cluster (85x73 at 2x plus its 12 px margin), right-aligned like the original.
	panel.reset_size()
	var panel_size := panel.get_combined_minimum_size()
	# The HUD cluster is 85x73 at 2x times the UI size (ui_scale.gd), 12 px from the corner.
	var ui := preload("res://scripts/lol2/ui_scale.gd")
	var view := get_viewport().get_visible_rect().size
	var k: float = ui.effective(view)
	var cluster := Vector2(85, 73) * 2.0 * ui.cluster_scale(view, Vector2(85, 73) * 2.0)
	# Above the cluster (the original layout) or, when that leaves the panel smaller, beside it on the left.
	var above := minf(k, minf((view.x - 24) / panel_size.x, (view.y - cluster.y - 34) / panel_size.y))
	var beside := minf(k, minf((view.x - cluster.x - 36) / panel_size.x, (view.y - 16) / panel_size.y))
	var s := maxf(maxf(above, beside), 0.5)
	panel.pivot_offset = panel_size
	panel.scale = Vector2(s, s)
	panel.offset_right = -12 if above >= beside else -12 - cluster.x - 12
	panel.offset_left = panel.offset_right - panel_size.x
	panel.offset_bottom = -(cluster.y + 12 + 6) if above >= beside else -12.0
	panel.offset_top = panel.offset_bottom - panel_size.y

func _input(event: InputEvent) -> void:
	if is_instance_valid(item_menu) and item_menu.visible:
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			item_menu.hide();get_viewport().set_input_as_handled();return
		if event is InputEventMouseButton and event.pressed and not item_menu.get_global_rect().has_point(event.position):item_menu.hide()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		if return_to_game.is_valid():
			return_to_game.call()
			previous_mouse = Input.mouse_mode
		get_viewport().set_input_as_handled()
		close()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_I,KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	if closed: return
	closed = true
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(session_tree): session_tree.paused = previous_pause
	Input.mouse_mode = previous_mouse

func select_item(index: int) -> void:
	if index < 0 or index >= item_list.item_count: return
	selected_index = index
	var id := str(item_list.get_item_metadata(index))
	hold_button.visible = hold_item.is_valid()
	hold_button.text = "Put away" if id == held_item_id else ("Hold Sk key" if id == "museum:control87:Sk_key" else hold_label)
	use_button.visible = (id == preload("res://scripts/lol2/hive_ancient_stone.gd").ITEM or id == preload("res://scripts/lol2/monastery_conversation.gd").FLUTE or preload("res://scripts/lol2/item_catalog.gd").use_kind(id) != "" or not preload("res://scripts/lol2/item_catalog.gd").target_hint(id).is_empty()) and use_item.is_valid()
	if is_instance_valid(mix_button):mix_button.visible=get_parent().get_node("L8Larkhon").can_mix(id)
	if get_parent().has_node("L12Citadel") and id==preload("res://scripts/lol2/l12_citadel_state.gd").PICTURE:use_button.visible=true
	if get_parent().has_node("L8Larkhon") and id==preload("res://scripts/lol2/l8_larkhon_state.gd").VAPORS:use_button.visible=true
	use_button.text = "Use Aloe" if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) == "aloe" else "Use stone" if id == preload("res://scripts/lol2/hive_ancient_stone.gd").ITEM or preload("res://scripts/lol2/player_item_effects.gd").is_champion_stone(id) else "Play flute"
	if use_button.text == "Play flute" and id != preload("res://scripts/lol2/monastery_conversation.gd").FLUTE: use_button.text = "Use"
	if not preload("res://scripts/lol2/item_catalog.gd").target_hint(id).is_empty():use_button.text="Prepare throw" if preload("res://scripts/lol2/item_throw_rules.gd").supported(preload("res://scripts/lol2/item_catalog.gd").definition(id)) else "Use on target"
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) == "mana_foil": use_button.text = "Use Mana Foil"
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) in ["black_lichen","mandrake","gorgonite","inert_food"]:use_button.text="Eat"
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id)=="mind_cluster":use_button.text="Use Mind Cluster"
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id)=="death_sac":use_button.text="Apply to weapon"
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) == "ironwood_sap": use_button.text = "Use sap"
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) == "vels_fruit": use_button.text = "Eat fruit"
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) == "fire_crystal": use_button.text = "Use crystal"
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) == "poison_paint": use_button.text = "Apply to weapon"
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) == "dampen_charm":
		use_button.text = "Use charm"
	if id==preload("res://scripts/lol2/l8_larkhon_state.gd").VAPORS:use_button.text="Activate vapors"
	if id==preload("res://scripts/lol2/l12_citadel_state.gd").PICTURE:use_button.text="Ready picture to throw"
	var is_armor := preload("res://scripts/lol2/player_equipment.gd").armor(id)
	var selected := equipped_armor if is_armor else equipped_item
	var supported := (is_armor and change_armor.is_valid()) or (preload("res://scripts/lol2/player_equipment.gd").weapon(id) and change_equipment.is_valid())
	if preload("res://scripts/lol2/player_equipment.gd").offhand(id):
		var controller = get_parent().get("item_effects")
		supported = controller != null and get_parent().player_form == 0
		selected = str(controller.state().get("offhand", "")) if controller != null else ""
	if preload("res://scripts/lol2/player_equipment.gd").accessory(id):
		var controller=get_parent().get("item_effects")
		supported=is_instance_valid(controller) and get_parent().player_form==0
		selected=id if id in _accessories() else ""
	equip_button.disabled = not supported
	equip_button.text = "Unequip" if id == selected else "Equip"
	detail_name.text = item_list.get_item_text(index)
	if id == selected: detail_name.text += " · Equipped"
	detail_icon.texture = item_list.get_item_icon(index)
	match str(item_list.get_item_metadata(index)):
		"museum:item11:Fine_Longsword":
			detail_text.text = "Collected from the table in Draracle’s museum."
		"museum:item10:Mail_Shirt":
			detail_text.text = "Collected in Draracle’s museum. Select it for the armor slot."
		"museum:item8:Champion_Stone", "museum:item9:Champion_Stone":
			detail_text.text = "Temporarily strengthens melee attacks. Use while human; consumed when used."
		"hive:item0:Wax":
			detail_name.text = "Wax"
			detail_text.text = "A piece of wax."
		"monastery:item94:Iron_Flute":
			detail_text.text = "Given by Julian at the monastery."
		"museum:control87:Sk_key":
			detail_text.text = "The museum skeleton key. Hold it, then press E at a lock."
		"draracle/prop/1108/sample":
			detail_text.text = "A find from the cavern. Its identity is unknown."
		_:
			detail_text.text = "Picked in Draracle’s caves. Item use is not available yet." if preload("res://scripts/lol2/cave_aloe.gd").valid_item(id) else (preload("res://scripts/lol2/item_catalog.gd").use_hint(id) if preload("res://scripts/lol2/item_catalog.gd").use_hint(id) != "" else "This item has not been identified.")

	var stored_school := preload("res://scripts/lol2/item_catalog.gd").stored_school(id)
	if not stored_school.is_empty():
		var cast_names := {"spark":"Spark III","mists":"Lesser Apparitions","prism":"Trinity","summon":"Ancient Imp"}
		if stored_school == "heal":
			detail_text.text = "Stored Healing. Use heals Luther; consumed only if the spell succeeds."
		elif stored_school == "spark":
			detail_text.text = "Stored Spark III. Use casts the spell; the scroll is consumed on a successful use."
		else:
			detail_text.text = "Stored %s. First use teaches the school; later uses cast %s. Consumed on a successful use." % [{"mists":"Mists","prism":"Prism","summon":"Summon"}[stored_school],cast_names[stored_school]]

	var target_hint:String=preload("res://scripts/lol2/item_catalog.gd").target_hint(id)
	if not target_hint.is_empty():detail_text.text=target_hint if preload("res://scripts/lol2/item_throw_rules.gd").supported(preload("res://scripts/lol2/item_catalog.gd").definition(id)) else target_hint+" Aim at the target, then press E. The item is kept until the target accepts it."
	if preload("res://scripts/lol2/item_catalog.gd").definition(id)==114:detail_text.text="Eat for one minute of low-light vision. Extra eggs are kept while it is active."
	var food_description:String=preload("res://scripts/lol2/item_consumables.gd").description(preload("res://scripts/lol2/item_catalog.gd").definition(id))
	if not food_description.is_empty():detail_text.text=food_description
	if preload("res://scripts/lol2/cave_captain_items.gd").valid(id):detail_text.text="Given by the surrendered captain."
	if id == preload("res://scripts/lol2/hive_ancient_stone.gd").ITEM: detail_text.text = "Grants one free highest-charge attack spell."
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) == "mana_foil": detail_text.text = "Restores up to 50 mana. Consumed even when your mana is full."
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) == "fire_crystal": detail_text.text = "A fire crystal. Each use hurls fire along your view and spends a charge; a burnt crystal can be rekindled at a lit sconce."
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id)=="fire_crystal" and is_instance_valid(get_parent().get("item_effects")):
		var charges:int=get_parent().item_effects.crystal_charges(id)
		detail_text.text+=" Charges: "+str(charges)+(". Burnt out; it must be rekindled." if charges==0 else ".")
	var device_hint:String=preload("res://scripts/lol2/item_device_status.gd").description(preload("res://scripts/lol2/item_catalog.gd").definition(id))
	if not device_hint.is_empty():detail_text.text=device_hint
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) == "dampen_charm": detail_text.text = "Given by Dawn after she translated the runes. Using it consumes the charm and calms a stirring curse."
	if not preload("res://scripts/lol2/player_stored_globes.gd").spell(id).is_empty():
		use_button.text="Cast globe"
		detail_text.text="A stored spell: use to cast, leaving an empty glass globe. It also fits its matching tomb socket."
	if preload("res://scripts/lol2/hive_rune_items.gd").valid(id): detail_text.text = "An impression of the Hive inscription in wax."
	match _larkhon_recipe(id):
		117: detail_text.text = "A leaf from the cemetery's trees. Offer one in the Wild Village. One mixes with the Amaranth Serum."
		119: detail_text.text = "It does nothing on its own. Drag it onto a Silverleaf to mix them."
		128: detail_text.text = "Activate the vapors, then use them on the Larkhon's upper chest."
	if preload("res://scripts/lol2/cave_stalagmite.gd").valid_item(id): detail_text.text = "Taken from a crystal formation in Draracle’s caves. Select it as your weapon."
	if preload("res://scripts/lol2/player_equipment.gd").offhand(id): detail_text.text = "Equip in your offhand. Stored while transformed."
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) == "poison_paint": detail_text.text = "Mauri's poison. Applying it coats the weapon for one strike; the weapon can hold nine coats."
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id)=="dragon_blood":detail_text.text="Place an explosive ahead of you. Six-second fuse; blast harms nearby creatures and you. Move away after use."
	if id=="hive:control121:Reaver_of_GO":detail_text.text="Equip as a weapon. Reduces total defense by 50 while equipped."
	if id.begins_with("cave:guard"): detail_text.text = "Dropped by a defeated cave guard. " + ("Equip in your offhand. Stored while transformed." if preload("res://scripts/lol2/player_equipment.gd").offhand(id) else "Select it as your weapon.")
	var catalog=preload("res://scripts/lol2/item_catalog.gd")
	if catalog.slot(id)!="":
		if detail_text.text=="This item has not been identified.":detail_text.text="Equip in the "+catalog.slot(id)+" slot."
		if catalog.slot(id)=="weapon":detail_text.text+=" Fixed damage: %d."%preload("res://scripts/lol2/player_combat.gd").base_damage(0,true)
		detail_text.text+=" Protection %d."%catalog.defense(id)
		if catalog.slot(id)=="accessory":detail_text.text+=" Worn in either accessory slot; special powers are not available yet."


	var protected:String=preload("res://scripts/lol2/quest_resource_protection.gd").removing(get_parent(),preload("res://scripts/lol2/item_grants.gd").pack(get_parent()),id)
	if not protected.is_empty():detail_text.text+="\n"+protected

func toggle_equipment() -> void:
	if equip_button.disabled or selected_index < 0: return
	var id := str(item_list.get_item_metadata(selected_index))
	if preload("res://scripts/lol2/player_equipment.gd").accessory(id):
		if get_parent().item_effects.equip_accessory(id):
			select_item(selected_index);refresh_classic()
		elif "" not in _accessories():detail_text.text="Both accessory slots are full. Unequip one first."
		return
	if preload("res://scripts/lol2/player_equipment.gd").offhand(id):
		var controller = get_parent().get("item_effects")
		if controller != null and controller.equip_offhand("" if controller.state().get("offhand", "") == id else id):
			select_item(selected_index)
			refresh_classic()
		return
	var is_armor := preload("res://scripts/lol2/player_equipment.gd").armor(id)
	var selected := equipped_armor if is_armor else equipped_item
	var next_item := "" if selected == id else id
	var action := change_armor if is_armor else change_equipment
	if action.call(next_item):
		if is_armor: equipped_armor = next_item
		else: equipped_item = next_item
		select_item(selected_index)
		refresh_classic()

func use_selected_item() -> void:
	if selected_index < 0 or not use_item.is_valid(): return
	if use_item.call(str(item_list.get_item_metadata(selected_index))): close()
	else:
		var owner:=get_parent()
		var effects:Variant=owner.get("item_effects") if is_instance_valid(owner) else null
		var reason:String=str(effects.get("item_refusal")) if is_instance_valid(effects) and effects.get("item_refusal") is String else ""
		detail_text.text=reason if not reason.is_empty() else "Nothing happens."

## --- Original-style presentation helpers (classic_interface pack) ---------------------------------------------------
const INTERFACE := "res://assets/lol2/generated/classic_interface/"
## Equipment block (2x3, intrface.shp ghosts 87-92). Roles of the empty slots are presentation adapters.
const SLOT_ROLES := ["offhand", "accessory0", "weapon", "accessory1", "armor", ""]
var stat_bars := {}
var equipment_slots: Array = []

func _interface_texture(index: int, scale := 1.0) -> Texture2D:
	var path := INTERFACE + "shape_%03d.png" % index
	if not FileAccess.file_exists(path): return null
	var image := Image.load_from_file(path)
	if scale != 1.0: image.resize(int(image.get_width() * scale), int(image.get_height() * scale), Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

func _tile_style(index: int, k: float) -> StyleBox:
	var texture := _interface_texture(index, k)
	if texture == null:
		var flat := StyleBoxFlat.new(); flat.bg_color = Color("5a1a14") if index == 78 else Color("555555")
		return flat
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return style

func _offhand() -> String:
	var controller = get_parent().get("item_effects") if get_parent() != null else null
	return str(controller.state().get("offhand", "")) if controller != null and controller.has_method("state") else ""

func _icon_for(id: String) -> Texture2D:
	for index in item_list.item_count:
		if str(item_list.get_item_metadata(index)) == id: return item_list.get_item_icon(index)
	return null

func refresh_classic() -> void:
	var worn := _worn()
	for index in equipment_slots.size():
		var role: String = SLOT_ROLES[index]
		var icon_rect: TextureRect = equipment_slots[index].get_node("Worn")
		icon_rect.texture = _icon_for(str(worn.get(role, ""))) if str(worn.get(role, "")) != "" else null
	var host := get_parent()
	if host == null: return
	var defense:int=preload("res://scripts/lol2/player_defense.gd").scalar(host)
	var magic = host.get("starting_magic")
	var health := float(PlayerHealth.MAXIMUM)
	if magic != null and is_instance_valid(magic) and magic.has_method("health"): health = float(magic.health())
	var form := int(host.get("player_form")) if host.get("player_form") != null else 0
	# This panel also runs as a standalone overlay (e.g. an F10 report).
	# Only a gameplay host supplies combat state; the root Window is not Luther.
	var attack:int=PlayerCombat.damage(host,true) if host.get("player_form")!=null and host.get("equipped_item") is String else 0
	if stat_bars.has("Defense"): stat_bars["Defense"].value = clampf(defense * 2.0, 0, 100); stat_bars["Defense"].tooltip_text = "Defense %d" % defense
	if stat_bars.has("Health"): stat_bars["Health"].value = clampf(health / float(PlayerHealth.limit_for(host)) * 100.0, 0, 100); stat_bars["Health"].tooltip_text = "Health %d / %d" % [int(health),PlayerHealth.limit_for(host)]
	if stat_bars.has("Attack"): stat_bars["Attack"].value = clampf(attack / 12.0 * 100.0, 0, 100); stat_bars["Attack"].tooltip_text = "Melee damage %d" % attack
	if stat_bars.has("Ranged"): stat_bars["Ranged"].value = 0; stat_bars["Ranged"].tooltip_text = "No ranged weapon"

## Double-click: equip an equippable item, otherwise use it.
func activate_item(index: int) -> void:
	select_item(index)
	if not equip_button.disabled: toggle_equipment()
	elif use_button.visible: use_selected_item()

func _drag_item(at: Vector2) -> Variant:
	var index := item_list.get_item_at_position(at, true)
	if index < 0: return null
	select_item(index)
	var preview := TextureRect.new()
	preview.texture = item_list.get_item_icon(index)
	preview.custom_minimum_size = Vector2(44, 44)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_list.set_drag_preview(preview)
	return {"inventory_item": str(item_list.get_item_metadata(index)), "index": index}

## Definition (117 Silverleaf, 119 Amaranth Serum, 128 Larkhon Vapors) of a Larkhon recipe item, else -1.
func _larkhon_recipe(id: String) -> int:
	var definition := preload("res://scripts/lol2/act2_items_catalog.gd").definition(id)
	return definition if definition in [117, 119, 128] else -1

## BJ13, book "combine the potion and the leaf": one pack item dropped on the other. Only this pair; there is no general alchemy.
func _combine_serum(at: Vector2, data: Variant) -> String:
	if not data is Dictionary or not data.has("inventory_item") or not get_parent().has_node("L8Larkhon"): return ""
	var index := item_list.get_item_at_position(at, true)
	if index < 0: return ""
	var pair: Array = [str(data.inventory_item), str(item_list.get_item_metadata(index))]
	var kinds: Array = pair.map(func(id): return _larkhon_recipe(id))
	if not (117 in kinds and 119 in kinds): return ""
	var serum: String = pair[kinds.find(119)]
	return serum if get_parent().get_node("L8Larkhon").can_mix(serum) else ""

func _can_combine(at: Vector2, data: Variant) -> bool:
	return not _combine_serum(at, data).is_empty()

func _combine(at: Vector2, data: Variant) -> void:
	var serum := _combine_serum(at, data)
	if not serum.is_empty(): _finish_combine.call_deferred(serum) # After the viewport has finished its drop.

func _try_larkhon_mix(serum: String) -> bool:
	var guardian:Node=get_parent().get_node("L8Larkhon")
	if guardian.mix(serum):return true
	var reason:Variant=guardian.get("mix_refusal")
	detail_text.text=reason if reason is String and not reason.is_empty() else "The mix needs the Amaranth Serum and a Silverleaf, as a man."
	return false

func _finish_combine(serum: String) -> void:
	if not _try_larkhon_mix(serum): return
	await get_tree().process_frame # Freeing the pack in the frame of its own drop raises an engine list error.
	close()

func _slot_for(id: String) -> String:
	var equipment := preload("res://scripts/lol2/player_equipment.gd")
	if equipment.accessory(id):return "accessory"
	if equipment.offhand(id): return "offhand"
	if equipment.armor(id): return "armor"
	if equipment.weapon(id): return "weapon"
	return ""

func _can_drop(role: String, data: Variant) -> bool:
	return role != "" and data is Dictionary and data.has("inventory_item") and (_slot_for(str(data.inventory_item)) == role or (role.begins_with("accessory") and _slot_for(str(data.inventory_item))=="accessory"))

func _drop(role: String, data: Variant) -> void:
	if not _can_drop(role, data): return
	select_item(int(data.index))
	var id := str(data.inventory_item)
	if role.begins_with("accessory"):
		if get_parent().item_effects.equip_accessory(id,int(role.trim_prefix("accessory"))):select_item(int(data.index));refresh_classic()
		return
	var already := (role == "weapon" and equipped_item == id) or (role == "armor" and equipped_armor == id) or (role == "offhand" and _offhand() == id)
	if not already and not equip_button.disabled: toggle_equipment()

## Clicking a worn slot takes the item off (selects it in the grid, then the existing toggle).
func unequip_slot(role: String) -> void:
	var id: String = str(_worn().get(role,""))
	if id == "": return
	for index in item_list.item_count:
		if str(item_list.get_item_metadata(index)) == str(id):
			item_list.select(index)
			select_item(index)
			if not equip_button.disabled: toggle_equipment()
			return

func _accessories()->Array:
	var controller:Variant=get_parent().get("item_effects")
	return controller.accessories() if is_instance_valid(controller) and controller.has_method("accessories") else ["",""]
func _worn()->Dictionary:
	var accessories:Array=_accessories()
	return {"weapon":equipped_item,"armor":equipped_armor,"offhand":_offhand(),"accessory0":accessories[0],"accessory1":accessories[1]}
## Right click opens an explicit choice; it never consumes merely by browsing.
var item_menu:PanelContainer
var belt_view:Control
func show_item_menu():
	if selected_index<0:return
	if is_instance_valid(item_menu):item_menu.queue_free()
	item_menu=PanelContainer.new();item_menu.name="ItemMenu";item_menu.z_index=100
	var menu_style:=StyleBoxFlat.new();menu_style.bg_color=Color("21190f");menu_style.border_color=Color("ad8e55");menu_style.set_border_width_all(2);menu_style.set_content_margin_all(6)
	item_menu.add_theme_stylebox_override("panel",menu_style)
	add_child(item_menu)
	var choices:=VBoxContainer.new();choices.name="Choices";item_menu.add_child(choices)
	var put:=Button.new();put.name="PutOnBelt";put.text="Put on belt";choices.add_child(put)
	put.pressed.connect(func():
		var id:=str(item_list.get_item_metadata(selected_index))
		var controller=get_parent().get("item_effects")
		if is_instance_valid(controller) and controller.put_on_belt(id):detail_text.text="Put on belt."
		item_menu.hide())
	if use_button.visible:
		var use:=Button.new();use.name="UseItem";use.text="Use";choices.add_child(use)
		use.pressed.connect(func():item_menu.hide();use_selected_item())
	if hold_item.is_valid() and not preload("res://scripts/lol2/player_stored_globes.gd").spell(str(item_list.get_item_metadata(selected_index))).is_empty():
		var hold:=Button.new();hold.name="UseOnTarget";hold.text="Use on target";choices.add_child(hold)
		hold.pressed.connect(func():
			item_menu.hide()
			if hold_item.call(str(item_list.get_item_metadata(selected_index))):close())
	item_menu.position=get_viewport().get_mouse_position().min(get_viewport().get_visible_rect().size-Vector2(200,100))
	put.grab_focus()
func build_inventory_belt():
	var controller=get_parent().get("item_effects")
	if not is_instance_valid(controller):return
	belt_view=preload("res://scripts/lol2/item_belt_view.gd").new();belt_view.controller=controller;belt_view.interactive=true
	add_child(belt_view)
	belt_view.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	belt_view.offset_left=24;belt_view.offset_right=352;belt_view.offset_top=-138;belt_view.offset_bottom=-8
