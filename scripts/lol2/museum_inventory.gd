extends CanvasLayer
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
	var background := ColorRect.new()
	background.theme = preload("res://scripts/lol2/museum_ui_theme.gd").create()
	background.color = Color(0,0,0,0.72)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540,420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("202322")
	style.border_color = Color("8f7950")
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side,24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",14)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size",26)
	box.add_child(title)
	item_list = ItemList.new()
	item_list.custom_minimum_size = Vector2(390,160)
	item_list.fixed_icon_size = Vector2i(96,24)
	item_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(item_list)
	var seen: Array = []
	for id in item_ids:
		if id in seen: continue
		seen.append(id)
		var name_text := "Unidentified item"
		var icon: Texture2D
		if preload("res://scripts/lol2/cave_captain_items.gd").valid(id):
			name_text=preload("res://scripts/lol2/cave_captain_items.gd").label(id)
			icon=ImageTexture.create_from_image(Image.load_from_file(preload("res://scripts/lol2/cave_captain_items.gd").icon(id)))
		elif id == "museum:item11:Fine_Longsword":
			name_text = "Fine Longsword"
			icon = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/museum_sword_transfer/sword.png"))
		elif id == "museum:item10:Mail_Shirt":
			name_text = "Mail Shirt"
			icon = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/museum_mail/mail.png"))
		elif id in ["museum:item8:Champion_Stone", "museum:item9:Champion_Stone"]:
			name_text = "Champion Stone"
			icon = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/museum_stones/stone.png"))
		elif preload("res://scripts/lol2/hive_rune_items.gd").valid(id):
			name_text = "Wax runes"
			icon = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/hive_wax_runes/runes.png"))
		elif id == preload("res://scripts/lol2/hive_ancient_stone.gd").ITEM:
			name_text = "Ancients’ Stone"
			icon = ImageTexture.create_from_image(Image.load_from_file(preload("res://scripts/lol2/hive_ancient_stone.gd").ROOT+"stone.png"))
		elif id == preload("res://scripts/lol2/hive_wax.gd").ITEM:
			name_text = "Wax"
			icon = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/hive_wax/wax.png"))
		elif not preload("res://scripts/lol2/shop_item_inventory.gd").info(id).is_empty():
			var info := preload("res://scripts/lol2/shop_item_inventory.gd").info(id)
			name_text = info.label
			icon = ImageTexture.create_from_image(Image.load_from_file(info.icon))
		elif id in preload("res://scripts/lol2/weapon_shop_state.gd").ITEMS.values():
			name_text = str(id).get_slice(":",2).replace("_"," ")
			icon = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/weapon_shop/"+str(id).get_slice(":",2)+".png"))
		elif id == preload("res://scripts/lol2/monastery_conversation.gd").FLUTE: name_text = "Iron Flute"
		elif id == "draracle/prop/1108/sample": name_text = "Cavern find (unidentified)"
		elif preload("res://scripts/lol2/cave_aloe.gd").valid_item(id): name_text = "Cave Aloe"
		elif preload("res://scripts/lol2/cave_stalagmite.gd").valid_item(id):
			name_text = "Stalagmite"
			icon = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/cave_stalagmite/icon.png"))
		# Generic catalog presentation for identities without a dedicated branch (e.g. cave guard drops).
		if name_text == "Unidentified item" and preload("res://scripts/lol2/item_catalog.gd").known(id):
			name_text = preload("res://scripts/lol2/item_catalog.gd").label(id)
			var path := preload("res://scripts/lol2/item_catalog.gd").icon(id)
			if icon == null and not path.is_empty() and FileAccess.file_exists(path): icon = ImageTexture.create_from_image(Image.load_from_file(path))
		item_list.add_item(name_text,icon)
		item_list.set_item_metadata(item_list.item_count - 1, id)
	var details := HBoxContainer.new()
	details.add_theme_constant_override("separation", 16)
	box.add_child(details)
	detail_icon = TextureRect.new()
	detail_icon.custom_minimum_size = Vector2(144, 64)
	detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	details.add_child(detail_icon)
	var description := VBoxContainer.new()
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(description)
	detail_name = Label.new()
	detail_name.add_theme_color_override("font_color", Color("e5be72"))
	description.add_child(detail_name)
	detail_text = Label.new()
	detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_text.custom_minimum_size = Vector2(290, 64)
	description.add_child(detail_text)
	equip_button = Button.new()
	equip_button.text = "Equip"
	equip_button.disabled = true
	equip_button.pressed.connect(toggle_equipment)
	box.add_child(equip_button)
	use_button = Button.new()
	use_button.text = "Play flute"
	use_button.hide()
	use_button.pressed.connect(use_selected_item)
	box.add_child(use_button)
	hold_button = Button.new()
	hold_button.hide()
	hold_button.pressed.connect(func():
		if selected_index >= 0 and hold_item.is_valid() and hold_item.call(str(item_list.get_item_metadata(selected_index))): close())
	box.add_child(hold_button)
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
	note.text = "Choose an item to equip or use."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var close_button := Button.new()
	close_button.text = "Close · I / Esc"
	close_button.pressed.connect(close)
	box.add_child(close_button)
	if item_list.item_count > 0: item_list.grab_focus()
	else: close_button.grab_focus()

func _input(event: InputEvent) -> void:
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
	hold_button.text = "Put away" if id == held_item_id else hold_label
	use_button.visible = (id == preload("res://scripts/lol2/hive_ancient_stone.gd").ITEM or id == preload("res://scripts/lol2/monastery_conversation.gd").FLUTE or preload("res://scripts/lol2/item_catalog.gd").use_kind(id) != "") and use_item.is_valid()
	use_button.text = "Use Aloe" if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) == "aloe" else "Use stone" if id == preload("res://scripts/lol2/hive_ancient_stone.gd").ITEM or preload("res://scripts/lol2/player_item_effects.gd").is_champion_stone(id) else "Play flute"
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) == "ironwood_sap": use_button.text = "Use sap"
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) == "vels_fruit": use_button.text = "Eat fruit"
	var is_armor := preload("res://scripts/lol2/player_equipment.gd").armor(id)
	var selected := equipped_armor if is_armor else equipped_item
	var supported := (is_armor and change_armor.is_valid()) or (preload("res://scripts/lol2/player_equipment.gd").weapon(id) and change_equipment.is_valid())
	if preload("res://scripts/lol2/player_equipment.gd").offhand(id):
		var controller = get_parent().get("item_effects")
		supported = controller != null and get_parent().player_form == 0
		selected = str(controller.state().get("offhand", "")) if controller != null else ""
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
		"draracle/prop/1108/sample":
			detail_text.text = "A find from the cavern. Its identity is unknown."
		_:
			detail_text.text = "Picked in Draracle’s caves. Item use is not available yet." if preload("res://scripts/lol2/cave_aloe.gd").valid_item(id) else "This item has not been identified."

	if preload("res://scripts/lol2/cave_captain_items.gd").valid(id):detail_text.text="Given by the surrendered captain."
	if id == preload("res://scripts/lol2/hive_ancient_stone.gd").ITEM: detail_text.text = "Grants one free highest-charge attack spell."
	if preload("res://scripts/lol2/hive_rune_items.gd").valid(id): detail_text.text = "An impression of the Hive inscription in wax."
	if preload("res://scripts/lol2/cave_stalagmite.gd").valid_item(id): detail_text.text = "Taken from a crystal formation in Draracle’s caves. Select it as your weapon."
	if preload("res://scripts/lol2/player_equipment.gd").offhand(id): detail_text.text = "Equip in your offhand. Defense +%d. Stored while transformed." % preload("res://scripts/lol2/item_catalog.gd").defense(id)
	if id.begins_with("cave:guard"): detail_text.text = "Dropped by a defeated cave guard. " + ("Equip in your offhand. Defense +%d. Stored while transformed." % preload("res://scripts/lol2/item_catalog.gd").defense(id) if preload("res://scripts/lol2/player_equipment.gd").offhand(id) else "Select it as your weapon.")

func toggle_equipment() -> void:
	if equip_button.disabled or selected_index < 0: return
	var id := str(item_list.get_item_metadata(selected_index))
	if preload("res://scripts/lol2/player_equipment.gd").offhand(id):
		var controller = get_parent().get("item_effects")
		if controller != null and controller.equip_offhand("" if controller.state().get("offhand", "") == id else id): select_item(selected_index)
		return
	var is_armor := preload("res://scripts/lol2/player_equipment.gd").armor(id)
	var selected := equipped_armor if is_armor else equipped_item
	var next_item := "" if selected == id else id
	var action := change_armor if is_armor else change_equipment
	if action.call(next_item):
		if is_armor: equipped_armor = next_item
		else: equipped_item = next_item
		select_item(selected_index)

func use_selected_item() -> void:
	if selected_index < 0 or not use_item.is_valid(): return
	if use_item.call(str(item_list.get_item_metadata(selected_index))): close()
	else: detail_text.text = "Nothing happens."
