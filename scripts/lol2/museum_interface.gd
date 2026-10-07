extends CanvasLayer
## Modern museum HUD; original interface artwork and character systems pending.
var walkthrough: Node3D
var geometry_path := "res://assets/lol2/generated/museum_review/museum.json"
var location_name := "Draracle’s museum"
var saves_enabled := true
var save_notice_remaining := 0.0
var save_location_name := "Museum"
var cursor_active := false
var atlas_opened_from_game := false
var hint: Label
var buttons: Array[Button] = []
var sheet: PanelContainer
var sheet_title: Label
var sheet_body: Label
var atlas: Control
var blink: TextureRect
var blink_textures: Array[ImageTexture] = []
var blink_elapsed := 0.0
var weapon_icon: TextureRect
var weapon_button: Button
var cursor_texture: ImageTexture
var atlas_controls: HBoxContainer
var character_controls: VBoxContainer
var save_button: Button
var load_button: Button
var save_status: Label
var save_path := preload("res://scripts/lol2/museum_save.gd").DEFAULT_PATH

func _ready() -> void:
	var cursor_image := Image.load_from_file("res://assets/lol2/generated/museum_interface/cursor.png")
	cursor_image.resize(18, 28, Image.INTERPOLATE_NEAREST)
	cursor_texture = ImageTexture.create_from_image(cursor_image)
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, Vector2.ZERO)
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shared_theme := preload("res://scripts/lol2/museum_ui_theme.gd").create()
	var bar := HBoxContainer.new()
	bar.theme = shared_theme
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 20
	bar.offset_right = -20
	bar.offset_top = -162
	bar.offset_bottom = -16
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)
	add_button(bar, "Character", "character")
	hint = Label.new()
	hint.text = "Tab — Interface · M — Atlas · F5/F9 — Save/Load"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	hint.custom_minimum_size.y = 64
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(hint)
	add_button(bar, "Magic Atlas", "atlas")
	add_button(bar, "Inventory", "inventory")
	sheet = PanelContainer.new()
	sheet.theme = shared_theme
	sheet.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sheet.offset_left = -240
	sheet.offset_right = 240
	sheet.offset_top = -220
	sheet.offset_bottom = 180
	sheet.add_theme_stylebox_override("panel", panel_style())
	add_child(sheet)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	sheet.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	sheet_title = Label.new()
	sheet_title.add_theme_font_size_override("font_size", 24)
	box.add_child(sheet_title)
	atlas = preload("res://scripts/lol2/museum_atlas.gd").new()
	atlas.walkthrough = walkthrough
	atlas.geometry_path = geometry_path
	atlas.custom_minimum_size = Vector2(420, 240)
	box.add_child(atlas)
	atlas_controls = HBoxContainer.new()
	atlas_controls.add_theme_constant_override("separation", 8)
	box.add_child(atlas_controls)
	for label in ["−", "+", "My position", "Overview"]:
		var control := Button.new()
		control.text = label
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		match label:
			"−": control.pressed.connect(func(): atlas.zoom_at(0.8, atlas.size / 2))
			"+": control.pressed.connect(func(): atlas.zoom_at(1.25, atlas.size / 2))
			"My position": control.pressed.connect(atlas.center_player)
			"Overview": control.pressed.connect(atlas.overview)
		atlas_controls.add_child(control)
	sheet_body = Label.new()
	box.add_child(sheet_body)
	character_controls = VBoxContainer.new()
	character_controls.add_theme_constant_override("separation", 10)
	box.add_child(character_controls)
	var equipment_button := Button.new()
	equipment_button.text = "Open inventory"
	equipment_button.pressed.connect(func(): open_page("inventory"))
	character_controls.add_child(equipment_button)
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 8)
	character_controls.add_child(save_row)
	save_row.visible = saves_enabled
	save_button = Button.new()
	save_button.text = "Save game · F5"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(func(): run_save_action(false))
	save_row.add_child(save_button)
	load_button = Button.new()
	load_button.text = "Load game · F9"
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.pressed.connect(func(): run_save_action(true))
	save_row.add_child(load_button)
	save_status = Label.new()
	save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_status.custom_minimum_size.y = 44
	character_controls.add_child(save_status)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close_sheet)
	box.add_child(close_button)
	sheet.hide()
	set_cursor(false)
	refresh_equipment()

func add_button(bar: HBoxContainer, label: String, page: String) -> void:
	var button := Button.new()
	button.text = label
	button.size_flags_vertical = Control.SIZE_SHRINK_END
	button.custom_minimum_size.y = 64
	button.custom_minimum_size.x = 130
	button.pressed.connect(func(): open_page(page))
	buttons.append(button)
	bar.add_child(button)
	if page == "character": add_portrait(button)

func set_cursor(active: bool, update_mouse_mode := true) -> void:
	cursor_active = active
	if update_mouse_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if active else Input.MOUSE_MODE_CAPTURED
	hint.text = "Tab — Return to game" if active else ("Tab — Interface · M — Atlas" + (" · F5/F9 — Save/Load" if saves_enabled else ""))
	for button in buttons:
		button.disabled = not active
		button.focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
	weapon_button.disabled = not active
	weapon_button.focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
	if not active:
		sheet.hide()
		atlas_opened_from_game = false

func open_page(page: String) -> void:
	if not cursor_active or get_tree().paused: return
	atlas_opened_from_game = false
	sheet.hide()
	if page == "inventory":
		walkthrough.open_inventory()
		return
	sheet.show()
	atlas.visible = page == "atlas"
	atlas_controls.visible = atlas.visible
	character_controls.visible = not atlas.visible
	save_status.text = ""
	sheet_title.text = "Magic Atlas" if page == "atlas" else "Character"
	sheet_body.text = location_name + " · Local map\nScroll to zoom · Drag to move\nGold marker: your position and facing" if page == "atlas" else character_text()

func _input(event: InputEvent) -> void:
	# Modal inventory and story overlays own input while the tree is paused.
	if get_tree().paused: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5 and saves_enabled:
			run_save_action(false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F9 and saves_enabled:
			run_save_action(true)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M:
			toggle_atlas()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB:
			set_cursor(not cursor_active)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and cursor_active:
			if sheet.visible: close_sheet()
			else: set_cursor(false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_I and cursor_active:
			open_page("inventory")
			get_viewport().set_input_as_handled()

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("202322")
	style.border_color = Color("8f7950")
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	return style

func add_portrait(button: Button) -> void:
	button.text = ""
	button.tooltip_text = "Character"
	button.custom_minimum_size = Vector2(170, 146)
	for state in ["normal", "disabled", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var face := TextureRect.new()
	face.texture = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/museum_interface/portrait.png"))
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.position = Vector2(82, 18)
	face.size = Vector2(76, 104)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(face)
	blink = TextureRect.new()
	blink.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blink.position = Vector2(10, 26)
	blink.size = Vector2(58, 30)
	blink.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in [1,2,3]:
		blink_textures.append(ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/museum_interface/blink_%d.png" % index)))
	blink.hide()
	face.add_child(blink)
	var frame := TextureRect.new()
	frame.texture = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/museum_interface/portrait_frame.png"))
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.size = Vector2(170, 146)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(frame)
	weapon_icon = TextureRect.new()
	weapon_icon.texture = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/museum_sword_transfer/sword.png"))
	weapon_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_icon.position = Vector2(10, 22)
	weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon_icon.size = Vector2(48, 30)
	weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(weapon_icon)
	weapon_button = Button.new()
	weapon_button.position = Vector2(4, 8)
	weapon_button.size = Vector2(60, 60)
	for state in ["normal", "disabled", "hover", "pressed"]:
		weapon_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	weapon_button.pressed.connect(func(): open_page("inventory"))
	weapon_button.mouse_entered.connect(func():
		if not weapon_button.disabled: weapon_icon.modulate = Color(1.5, 1.5, 1.5))
	weapon_button.mouse_exited.connect(func(): weapon_icon.modulate = Color.WHITE)
	frame.add_child(weapon_button)
	button.mouse_entered.connect(func():
		if not button.disabled: frame.modulate = Color(1.2, 1.2, 1.2))
	button.mouse_exited.connect(func(): frame.modulate = Color.WHITE)
	button.focus_entered.connect(func(): frame.modulate = Color(1.2, 1.2, 1.2))
	button.focus_exited.connect(func(): frame.modulate = Color.WHITE)

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)

func toggle_atlas() -> void:
	if get_tree().paused: return
	if sheet.visible and atlas.visible:
		close_sheet()
		return
	var from_game := not cursor_active
	set_cursor(true)
	open_page("atlas")
	atlas_opened_from_game = from_game

func close_sheet() -> void:
	sheet.hide()
	if atlas_opened_from_game: set_cursor(false)
	atlas_opened_from_game = false

func character_text() -> String:
	var weapon := preload("res://scripts/lol2/player_equipment.gd").label(walkthrough.equipped_item) if walkthrough.equipped_item != "" else "None"
	if walkthrough.get("player_form") != null and not preload("res://scripts/lol2/player_form_rules.gd").can_use_weapon(int(walkthrough.player_form)): weapon += " (stored while transformed)"
	var armor := preload("res://scripts/lol2/player_equipment.gd").armor_label(walkthrough.equipped_armor)
	return "Weapon: " + weapon + "\nArmor: " + armor + "\nChange equipment in Inventory.\nCombat and character statistics are not available yet."

func refresh_equipment() -> void:
	var weapon_available: bool = walkthrough.get("player_form") == null or preload("res://scripts/lol2/player_form_rules.gd").can_use_weapon(int(walkthrough.player_form))
	if is_instance_valid(weapon_button):
		weapon_button.tooltip_text = (preload("res://scripts/lol2/player_equipment.gd").label(walkthrough.equipped_item) if walkthrough.equipped_item != "" else "No weapon selected") + " — open Inventory"
	if is_instance_valid(weapon_button) and not weapon_available:
		weapon_button.tooltip_text = "Weapons unavailable in this form — open Inventory"
	if is_instance_valid(weapon_icon):
		weapon_icon.visible = weapon_available and walkthrough.equipped_item != ""
		var icon_path := preload("res://scripts/lol2/player_equipment.gd").icon(walkthrough.equipped_item)
		weapon_icon.texture = ImageTexture.create_from_image(Image.load_from_file(icon_path))
	if is_instance_valid(sheet) and sheet.visible and not atlas.visible:
		sheet_body.text = character_text()

func _process(delta: float) -> void:
	if save_notice_remaining > 0:
		save_notice_remaining = maxf(0, save_notice_remaining - delta)
		if save_notice_remaining == 0:
			hint.text = "Tab — Return to game" if cursor_active else ("Tab — Interface · M — Atlas" + (" · F5/F9 — Save/Load" if saves_enabled else ""))
	if not get_tree().paused: advance_blink(delta)

func advance_blink(delta: float) -> void:
	blink_elapsed = fposmod(blink_elapsed + delta, 4.8)
	blink.visible = blink_elapsed >= 4.5
	if blink.visible:
		var index := mini(int((blink_elapsed - 4.5) / 0.1), 2)
		blink.texture = blink_textures[index]

func run_save_action(load_game: bool) -> void:
	if not saves_enabled: return
	var error: String = walkthrough.quickload(save_path) if load_game else walkthrough.quicksave(save_path)
	if not error.is_empty():
		save_status.text = ("Load failed: " if load_game else "Save failed: ") + error
	else:
		save_status.text = save_location_name + (" save loaded." if load_game else " saved.")
	hint.text = save_status.text
	save_notice_remaining = 4.0
