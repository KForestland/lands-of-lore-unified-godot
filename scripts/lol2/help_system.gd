extends Control
## Original in-game help (docs/help-system.md, tools/prepare_help_system.py). Native rule: op2 subs 0x29..0x2E/0x32/0x33
## need player+0x22A bit0 (help enabled) and set a one-time bit at player+0x20C (topic t, bit 1 << (t-1)) before
## 73FF0(t) shows "Press [icon] for help on ..." (longplay 8:15, 10:30). The original help page art (help.pcx) and
## the banner icon are not in the GOG data: the page uses the original parchment scroll PRCHUNRL.PCX and the icon
## intrface.shp shape 119 (adapters, docs/DEVIATIONS.md); the help UI layout (15BB18) is not decoded.
## F1 (or the icon in cursor mode) opens the page for the shown topic; F1/Esc closes it; T on the page switches
## help messages off/on. The world pauses while the page is open.
const ROOT := "res://assets/lol2/generated/help_system/"
const UiScale := preload("res://scripts/lol2/ui_scale.gd")
const BANNER_SECONDS := 8.0
## '@' key placeholders per topic -> this version's controls; "(none)" where the port has no such key.
## The original pages describe the original controls; '@' stood for a configurable key and is shown as [key]. Each page
## ends with how this version actually does it (checked against the handlers; Grok/Codex help review 2026-10-21).
const VERSION_NOTES := {
	1: "In this version: press Tab to free the cursor, then I (or Inventory on the Character page) opens the inventory. Select an item to use, equip or hold it. E picks things up in the world.",
	2: "In this version: M opens the map (the game keeps running). Mouse wheel or -/+ zooms, drag pans, My position centres it.",
	3: "In this version: Q casts the loaded spell; 1 loads Spark, 2 loads Healing. In Tab mode click the Magic button to cast, right click it to switch.",
	4: "In this version: left click attacks whatever is in front of you. In Tab mode the Attack button does the same.",
	5: "In this version: W A S D move, the mouse looks around, Shift runs, Space jumps. F4 switches the modern walk (step bob, smooth start and stop).",
	6: "In this version: E uses or picks up what you aim at. F5 saves, F9 loads, F6 changes the interface size.",
	7: "In this version: look up, down and around with the mouse.",
	8: "In this version: aim with the centre of the view and left click to attack; Q casts the loaded spell. Tab frees the cursor for the interface.",
}

var data: Dictionary = {}
## Native player bits: enabled (+0x22A bit0) and seen (+0x20C topic bits).
var state := initial()
var banner_topic := 0
## Last page shown; F1 re-enters the help system there when no banner is up (native leave line: F1 leaves or enters).
var last_topic := 1
var banner_left := 0.0
var page_topic := 0
var banner: HBoxContainer
var banner_text: Label
var icon_button: TextureButton
var page: Control
var page_title: Label
var page_body: Label
var page_footer: Label
var previous_pause := false
var previous_mouse := Input.MOUSE_MODE_CAPTURED

static func initial() -> Dictionary:
	return {"version": 1, "enabled": true, "seen": 0}

static func validate(saved: Variant) -> String:
	if not saved is Dictionary or saved.size() != 3 or not saved.has_all(["version", "enabled", "seen"]): return "Invalid help state."
	if not saved.enabled is bool: return "Invalid help state."
	for key in ["version", "seen"]:
		if not (saved[key] is int or saved[key] is float) or float(saved[key]) != floorf(float(saved[key])): return "Invalid help state."
	if int(saved.version) != 1 or int(saved.seen) < 0 or int(saved.seen) > 255: return "Invalid help state."
	return ""

static func assets_ready() -> bool:
	return FileAccess.file_exists(ROOT + "texts.json") and FileAccess.file_exists(ROOT + "page.png") and FileAccess.file_exists(ROOT + "icon.png")

func _ready() -> void:
	name = "HelpSystem"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "texts.json"))
	data = parsed if parsed is Dictionary else {}
	var shared_theme := preload("res://scripts/lol2/museum_ui_theme.gd").create()
	banner = HBoxContainer.new()
	banner.name = "HelpBanner"
	banner.theme = shared_theme
	banner.position = Vector2(16, 40)
	banner.add_theme_constant_override("separation", 6)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	var press := Label.new(); press.text = "Press"
	banner.add_child(press)
	icon_button = TextureButton.new()
	icon_button.texture_normal = ImageTexture.create_from_image(Image.load_from_file(ROOT + "icon.png"))
	icon_button.ignore_texture_size = true
	icon_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	icon_button.custom_minimum_size = Vector2(26, 18)
	icon_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_button.tooltip_text = "Help (F1)"
	icon_button.pressed.connect(func(): open_page(banner_topic))
	banner.add_child(icon_button)
	banner_text = Label.new()
	banner.add_child(banner_text)
	for label in [press, banner_text]:
		label.add_theme_color_override("font_color", Color("8fa8ff"))
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
	banner.hide()
	page = Control.new()
	page.name = "HelpPage"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.theme = shared_theme
	add_child(page)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.55); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(dim)
	var scroll := TextureRect.new()
	scroll.name = "Scroll"
	scroll.texture = ImageTexture.create_from_image(Image.load_from_file(ROOT + "page.png"))
	scroll.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scroll.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scroll.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(scroll)
	var text := VBoxContainer.new()
	text.name = "Text"
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Inside the unrolled sheet (PRCHUNRL rows ~40..160 of 200, columns ~20..300 of 320) at any window aspect.
	text.anchor_left = 0.22; text.anchor_right = 0.78; text.anchor_top = 0.21; text.anchor_bottom = 0.70
	text.offset_left = 0; text.offset_right = 0; text.offset_top = 0; text.offset_bottom = 0
	text.add_theme_constant_override("separation", 8)
	page.add_child(text)
	page_title = Label.new(); page_title.add_theme_font_size_override("font_size", 26)
	page_body = Label.new(); page_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; page_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The body stays on the unrolled sheet; the leave line sits on its own just above the lower roll.
	page_body.add_theme_font_size_override("font_size", 14); page_body.clip_text = true
	page_footer = Label.new(); page_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; page_footer.add_theme_font_size_override("font_size", 13)
	page_footer.anchor_left = 0.22; page_footer.anchor_right = 0.78; page_footer.anchor_top = 0.71; page_footer.anchor_bottom = 0.76
	page_footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for label in [page_title, page_body, page_footer]:
		label.add_theme_color_override("font_color", Color("3a1a0c"))
		(page if label == page_footer else text).add_child(label)
	page.hide()

## Native gate (D86B6 etc.): help enabled and the topic's one-time bit clear; sets the bit and shows the banner.
func request(topic: int) -> bool:
	if data.is_empty() or not data.topics.has(str(topic)): return false
	if not bool(state.enabled): return false
	var bit := 1 << (topic - 1)
	if int(state.seen) & bit: return false
	state.seen = int(state.seen) | bit
	show_banner(topic)
	return true

func show_banner(topic: int) -> void:
	banner_topic = topic
	# F1 later (banner gone) reopens the most recently announced topic, so an expired banner is not lost.
	last_topic = topic
	banner_left = BANNER_SECONDS
	# "Press for help on X." -> "Press [icon] for help on X." as in the longplay.
	banner_text.text = str(data.topics[str(topic)].banner).trim_prefix("Press ")
	var s := UiScale.effective(banner.get_viewport().get_visible_rect().size) if banner.is_inside_tree() else UiScale.factor()
	banner.scale = Vector2(s, s)
	banner.show()

func page_text(topic: int) -> Dictionary:
	var raw: String = str(data.topics[str(topic)].page).replace("\r", "\n")
	var index := 0
	var at := raw.find("@")
	while at >= 0:
		var key := "[key]"
		raw = raw.substr(0, at) + key + raw.substr(at + 1)
		index += 1
		at = raw.find("@")
	var lines := raw.split("\n", true, 1)
	var title := lines[0].trim_prefix("^").strip_edges()
	var body := (lines[1] if lines.size() > 1 else "").strip_edges()
	while body.contains("\n\n\n"): body = body.replace("\n\n\n", "\n\n")
	return {"title": title, "body": body}

func open_page(topic: int) -> bool:
	if topic <= 0 or data.is_empty() or not data.topics.has(str(topic)) or page.visible: return false
	page_topic = topic
	last_topic = topic
	var text := page_text(topic)
	page_title.text = text.title
	# The original pages space paragraphs with blank lines; single breaks keep this version's key line on the sheet.
	page_body.text = text.body.replace("\n\n", "\n") + "\n\n" + str(VERSION_NOTES.get(topic, ""))
	page_footer.text = footer_text()
	previous_pause = get_tree().paused
	previous_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	banner.hide()
	page.show()
	return true

func close_page() -> bool:
	if not page.visible: return false
	page.hide()
	page_topic = 0
	get_tree().paused = previous_pause
	Input.mouse_mode = previous_mouse
	return true

func page_open() -> bool: return page.visible

## Native leave line plus this version's page keys: Left/Right browse all eight topics.
func footer_text() -> String:
	return "%sF1%s · ←/→ topics · T: messages %s" % [str(data.leave[0]), str(data.leave[1]), "on" if bool(state.enabled) else "off"]

func show_topic(step: int) -> void:
	var count: int = data.topics.size()
	var next := wrapi(page_topic - 1 + step, 0, count) + 1
	page.hide(); page_topic = 0
	# Re-open in place: the world stays paused with the same saved pause/mouse state.
	var pause_before := previous_pause
	var mouse_before := previous_mouse
	open_page(next)
	previous_pause = pause_before
	previous_mouse = mouse_before

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if page.visible:
		if event.keycode in [KEY_F1, KEY_ESCAPE]:
			close_page(); get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_LEFT, KEY_RIGHT]:
			show_topic(-1 if event.keycode == KEY_LEFT else 1); get_viewport().set_input_as_handled()
		elif event.keycode == KEY_T:
			state.enabled = not bool(state.enabled)
			page_footer.text = footer_text()
			get_viewport().set_input_as_handled()
		return
	# F1 enters the help system at any time the world is not already paused by another page: the banner's topic, else the
	# last page viewed. This works with help messages off (Codex review: T off + close must not lock F1 out).
	if event.keycode == KEY_F1 and not get_tree().paused:
		open_page(banner_topic if banner.visible else last_topic); get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not banner.visible or get_tree().paused: return
	banner_left -= delta
	if banner_left <= 0: banner.hide()

func checkpoint() -> Dictionary: return state.duplicate()

func restore(saved: Variant) -> String:
	var proposed: Variant = saved if saved != null else initial()
	var error := validate(proposed)
	if not error.is_empty(): return error
	state = {"version": 1, "enabled": bool(proposed.enabled), "seen": int(proposed.seen)}
	# A loaded state never carries a banner from the session before it (Codex review: stale banner after restore).
	banner.hide()
	banner_topic = 0
	return ""
