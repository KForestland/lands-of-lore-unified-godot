extends CanvasLayer
## Shared area HUD (Cave/Museum/Jungle/Hive; docs/classic-hud.md): the original bottom-right cluster from the manual
## (intrface.shp shape 2 with portrait, Attack/Magic Buttons, health/mana slots, Blue Button + Spell Bar) and the
## original cursor. The Character/Atlas sheet and the prompt line are modern.
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
var atlas_offset := Vector2.ZERO

func _ready() -> void:
	var cursor_image := Image.load_from_file("res://assets/lol2/generated/museum_interface/cursor.png")
	cursor_image.resize(18, 28, Image.INTERPOLATE_NEAREST)
	cursor_texture = ImageTexture.create_from_image(cursor_image)
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, Vector2.ZERO)
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shared_theme := preload("res://scripts/lol2/museum_ui_theme.gd").create()
	build_cluster()
	# Prompt/notice line (modern text; the original screen has no such line).
	hint = Label.new()
	hint.theme = shared_theme
	hint.text = "Tab — Interface · M — Atlas · F5/F9 — Save/Load"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Bottom line from the left edge up to the cluster, so it never runs under the cluster at any window width.
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_left = 16; hint.offset_right = cluster.offset_left - 16; hint.offset_top = -44; hint.offset_bottom = -12
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
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
	atlas.origin_offset = atlas_offset
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

func set_cursor(active: bool, update_mouse_mode := true) -> void:
	cursor_active = active
	if update_mouse_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if active else Input.MOUSE_MODE_CAPTURED
	hint.text = "Tab — Return to game" if active else ("Tab — Interface · M — Atlas" + (" · F5/F9 — Save/Load" if saves_enabled else ""))
	for button in buttons:
		button.disabled = not active
		button.focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
	for control in [weapon_button, magic_button, blue_button] + spell_buttons.values():
		control.disabled = not active
		control.focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
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

## The original bottom-right cluster (manual printed 7/10/39; classic_hud_source.json): intrface.shp shape 2 at 2x with
## Luther's portrait in the oval, the Attack Button (upper ring), the Magic Button (lower ring), health/mana fills in
## the two slots, and the Blue Button that slides out the Spell Bar (shape 62) to the left.
const HUD_ROOT := "res://assets/lol2/generated/classic_hud/"
var hud_source: Dictionary
var cluster: Control
var magic_button: Button
var magic_icon: TextureRect
var hand_icon: TextureRect
var blue_button: Button
var spell_bar: TextureRect
var spell_buttons: Dictionary = {}
var health_fill: TextureRect
var mana_fill: TextureRect
var spell_textures: Dictionary = {}
func _texture(path: String) -> ImageTexture: return ImageTexture.create_from_image(Image.load_from_file(path))
func _shape(index: int) -> ImageTexture: return _texture(HUD_ROOT + str(hud_source.shapes[str(index)].file))
func _rect(parent: Control, r: Dictionary, k: float) -> Rect2: return Rect2(Vector2(r.x, r.y) * k, Vector2(r.width, r.height) * k)
func _flat(button: Button) -> void:
	for state in ["normal", "disabled", "hover", "pressed", "focus"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
func _icon(parent: Control, texture: Texture2D, rect: Rect2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture; icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = rect.position; icon.size = rect.size; icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon
func build_cluster() -> void:
	hud_source = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/classic_hud_source.json"))
	var k: float = float(hud_source.scale)
	var g: Dictionary = hud_source.cluster
	cluster = Control.new()
	cluster.name = "ClassicCluster"
	var size: Vector2 = Vector2(hud_source.shapes["2"].width, hud_source.shapes["2"].height) * k
	cluster.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cluster.offset_left = -size.x - 12; cluster.offset_top = -size.y - 12; cluster.offset_right = -12; cluster.offset_bottom = -12
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cluster)
	# Portrait (buttons[0], Character page) under the frame.
	var portrait := Button.new(); portrait.name = "Portrait"; _flat(portrait); portrait.tooltip_text = "Character"
	var oval := _rect(cluster, g.portrait, k); portrait.position = oval.position; portrait.size = oval.size
	portrait.pressed.connect(func(): open_page("character"))
	cluster.add_child(portrait); buttons.append(portrait)
	var face := _icon(portrait, _texture("res://assets/lol2/generated/museum_interface/portrait.png"), Rect2(Vector2.ZERO, oval.size))
	blink = TextureRect.new()
	blink.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blink.position = Vector2(5, 13) * k; blink.size = Vector2(29, 15) * k
	blink.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; blink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in [1,2,3]: blink_textures.append(_texture("res://assets/lol2/generated/museum_interface/blink_%d.png" % index))
	blink.hide(); face.add_child(blink)
	# Ring discs, bar fills, then the frame art on top.
	for ring in [g.attack_ring, g.magic_ring]: _icon(cluster, _shape(1), _rect(cluster, ring, k))
	health_fill = _icon(cluster, _shape(57), _rect(cluster, g.health_slot, k)); health_fill.stretch_mode = TextureRect.STRETCH_SCALE
	mana_fill = _icon(cluster, _shape(59), _rect(cluster, g.mana_slot, k)); mana_fill.stretch_mode = TextureRect.STRETCH_SCALE
	var frame := _icon(cluster, _shape(2), Rect2(Vector2.ZERO, size)); frame.name = "Frame"; frame.stretch_mode = TextureRect.STRETCH_SCALE
	# Attack Button (weapon_button, buttons[2]): attacks through the existing world dispatch (attack_from_interface).
	weapon_button = Button.new(); weapon_button.name = "AttackButton"; _flat(weapon_button)
	var attack := _rect(cluster, g.attack_ring, k); weapon_button.position = attack.position; weapon_button.size = attack.size
	weapon_button.pressed.connect(attack_from_interface)
	weapon_button.mouse_entered.connect(func():
		if not weapon_button.disabled: weapon_icon.modulate = Color(1.5, 1.5, 1.5))
	weapon_button.mouse_exited.connect(func(): weapon_icon.modulate = Color.WHITE)
	cluster.add_child(weapon_button)
	hand_icon = _icon(weapon_button, _shape(6), Rect2(Vector2.ZERO, attack.size))
	weapon_icon = _icon(weapon_button, _texture("res://assets/lol2/generated/museum_sword_transfer/sword.png"), Rect2(Vector2.ZERO, attack.size).grow(-2))
	# Magic Button: left click casts the loaded spell, right click cycles Spark/Heal (manual printed 10/39).
	magic_button = Button.new(); magic_button.name = "MagicButton"; _flat(magic_button)
	var magic := _rect(cluster, g.magic_ring, k); magic_button.position = magic.position; magic_button.size = magic.size
	magic_button.gui_input.connect(_magic_input)
	cluster.add_child(magic_button)
	spell_textures = {"spark": _shape(65), "heal": _shape(63)}
	magic_icon = _icon(magic_button, spell_textures.spark, Rect2(Vector2.ZERO, magic.size))
	# Compass (buttons[1]): opens the atlas (adapter; the native compass action is not established).
	var compass := Button.new(); compass.name = "Compass"; _flat(compass); compass.tooltip_text = "Magic Atlas"
	compass.position = Vector2(oval.position.x + oval.size.x * 0.55, 0); compass.size = Vector2(oval.size.x * 0.45, oval.position.y + 8)
	compass.pressed.connect(func(): open_page("atlas"))
	cluster.add_child(compass); buttons.append(compass)
	buttons.append(weapon_button)
	# Blue Button beside the Magic Button, and the Spell Bar to the cluster's left (placement adapter).
	blue_button = Button.new(); blue_button.name = "BlueButton"; _flat(blue_button); blue_button.tooltip_text = "Spell Book"
	blue_button.icon = _shape(25); blue_button.expand_icon = true
	blue_button.size = Vector2(11, 13) * k; blue_button.position = Vector2(magic.position.x - blue_button.size.x - 2, magic.position.y + (magic.size.y - blue_button.size.y) / 2)
	blue_button.pressed.connect(toggle_spell_bar)
	cluster.add_child(blue_button)
	spell_bar = TextureRect.new(); spell_bar.name = "SpellBar"
	spell_bar.texture = _shape(62); spell_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spell_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; spell_bar.stretch_mode = TextureRect.STRETCH_SCALE
	spell_bar.size = Vector2(hud_source.shapes["62"].width, hud_source.shapes["62"].height) * k
	spell_bar.position = Vector2(blue_button.position.x - spell_bar.size.x, size.y - spell_bar.size.y)
	spell_bar.hide()
	cluster.add_child(spell_bar)
	var rings: Array = hud_source.spell_bar.rings
	for entry in [["heal", 0], ["spark", 1]]:
		var r: Rect2 = _rect(spell_bar, rings[entry[1]], k)
		_icon(spell_bar, _shape(1), r)
		var pick := Button.new(); _flat(pick); pick.position = r.position; pick.size = r.size
		pick.tooltip_text = "Healing" if entry[0] == "heal" else "Spark"
		var spell: String = entry[0]
		pick.pressed.connect(func(): load_spell(spell))
		spell_bar.add_child(pick); spell_buttons[spell] = pick
		_icon(pick, spell_textures[spell], Rect2(Vector2.ZERO, r.size))
	refresh_vitals()

func _magic_input(event: InputEvent) -> void:
	if not cursor_active or not event is InputEventMouseButton or not event.pressed: return
	var magic = walkthrough.get("starting_magic")
	if magic == null or not is_instance_valid(magic): return
	if event.button_index == MOUSE_BUTTON_LEFT and magic.cast_from_interface():
		# Cursor mode keeps the hint for the shell, so show the cast feedback here; a save/area notice keeps priority.
		if save_notice_remaining <= 0 and not magic.notice_text().is_empty():
			hint.text = magic.notice_text()
			save_notice_remaining = 1.5
	elif event.button_index == MOUSE_BUTTON_RIGHT: load_spell("heal" if loaded_spell() == "spark" else "spark")
	refresh_vitals()

## Attack Button (manual printed 7/10): the port has no single attack API; each host's hit owners take an ordinary
## left click while the mouse is captured. So the click returns to play and delivers exactly one left press/release
## through the engine input pipeline; the same handlers resolve the hit (no combat change). Refused while paused.
var attack_requests := 0
func attack_from_interface() -> bool:
	if get_tree().paused or not cursor_active: return false
	set_cursor(false)
	attack_requests += 1
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT; click.pressed = pressed
		click.position = get_viewport().get_visible_rect().size / 2.0
		Input.parse_input_event(click)
	return true

func loaded_spell() -> String:
	var magic = walkthrough.get("starting_magic") if walkthrough != null else null
	if magic == null or not is_instance_valid(magic) or not magic.has_method("magic_state"): return "spark"
	return str(magic.magic_state().get("spell","spark"))

func load_spell(spell: String) -> void:
	var magic = walkthrough.get("starting_magic")
	if magic != null and is_instance_valid(magic): magic.select_spell(spell)
	refresh_vitals()

func toggle_spell_bar() -> void:
	spell_bar.visible = not spell_bar.visible
	blue_button.icon = _shape(26 if spell_bar.visible else 25)

## Health/mana fills (fraction of the slot) and the loaded spell icon, from the shared starting-magic owner.
func refresh_vitals() -> void:
	if not is_instance_valid(cluster) or walkthrough == null: return
	var magic = walkthrough.get("starting_magic")
	var health := 1.0; var mana := 1.0
	if magic != null and is_instance_valid(magic):
		health = clampf(float(magic.health()) / 30.0, 0.0, 1.0)
		var saved: Dictionary = magic.magic_state() if magic.has_method("magic_state") else {}
		if saved.get("player") is Dictionary and float(saved.player.maximum) > 0: mana = clampf(float(saved.player.mana) / float(saved.player.maximum), 0.0, 1.0)
	var k: float = float(hud_source.scale)
	health_fill.size.x = float(hud_source.cluster.health_slot.width) * k * health
	mana_fill.size.x = float(hud_source.cluster.mana_slot.width) * k * mana
	magic_icon.texture = spell_textures.get(loaded_spell(), spell_textures.spark)

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
	return vitals_text() + "Weapon: " + weapon + "\nArmor: " + armor + "\nChange equipment in Inventory."

## Health and mana from the shared starting-magic owner (the same values in every area).
func vitals_text() -> String:
	var magic = walkthrough.get("starting_magic")
	if magic == null or not is_instance_valid(magic): return ""
	var text := "Health: %d / 30\n" % int(magic.health())
	text += "Spell: %s · Q — Cast · 1/2 or the Spell Bar to change\n" % ("Healing" if loaded_spell() == "heal" else "Spark")
	if magic.has_method("status_lines"):
		for line in magic.status_lines(): text += str(line) + "\n"
	var saved = magic.magic_state() if magic.has_method("magic_state") else {}
	if saved is Dictionary and saved.get("player") is Dictionary: text += "Mana: %d / %d\n" % [int(saved.player.mana),int(saved.player.maximum)]
	return text

func refresh_equipment() -> void:
	var weapon_available: bool = walkthrough.get("player_form") == null or preload("res://scripts/lol2/player_form_rules.gd").can_use_weapon(int(walkthrough.player_form))
	if is_instance_valid(weapon_button):
		weapon_button.tooltip_text = (preload("res://scripts/lol2/player_equipment.gd").label(walkthrough.equipped_item) if walkthrough.equipped_item != "" else "Unarmed") + " — Attack"
	if is_instance_valid(weapon_button) and not weapon_available:
		weapon_button.tooltip_text = "Weapons unavailable in this form — Attack"
	if is_instance_valid(hand_icon): hand_icon.visible = not (weapon_available and walkthrough.equipped_item != "")
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
	refresh_vitals()
	magic_hint()

## Cast notices, the aura timer and item status on the shared hint line (replacing the modern spell panel). Area
## prompts (Hive/Cave subclasses) are applied after this and take priority.
var magic_status_shown := false
func magic_hint() -> void:
	if save_notice_remaining > 0 or cursor_active or walkthrough == null: return
	var magic = walkthrough.get("starting_magic")
	if magic == null or not is_instance_valid(magic) or not magic.has_method("status_lines"): return
	var lines: Array = []
	if not magic.notice_text().is_empty(): lines.append(magic.notice_text())
	lines.append_array(magic.status_lines())
	if not lines.is_empty():
		hint.text = " · ".join(lines)
		magic_status_shown = true
	elif magic_status_shown:
		hint.text = "Tab — Interface · M — Atlas" + (" · F5/F9 — Save/Load" if saves_enabled else "")
		magic_status_shown = false

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
