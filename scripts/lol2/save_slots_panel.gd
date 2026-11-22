extends CanvasLayer
## Minimal shared slot list for the opening screen and the existing Tab interface.
const Save = preload("res://scripts/lol2/game_save.gd")
var host: Node
var saving := false
var verify_load := Callable()
var rows: VBoxContainer
var message: Label
var confirmation: HBoxContainer
var confirm_yes: Button
var overwrite_id := -1
signal closed

func _ready() -> void:
	var session:Node=preload("res://scripts/lol2/game_session.gd").for_tree(get_tree())
	if session!=null:session.manual_save_finished.connect(_manual_finished)
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.theme = preload("res://scripts/lol2/museum_ui_theme.gd").create()
	panel.custom_minimum_size = Vector2(620,0)
	center.add_child(panel)
	var box := VBoxContainer.new();box.add_theme_constant_override("separation",8);panel.add_child(box)
	var title := Label.new();title.text = "Save game" if saving else "Load game";box.add_child(title)
	var scroll := ScrollContainer.new();scroll.custom_minimum_size = Vector2(620,350);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;box.add_child(scroll)
	rows = VBoxContainer.new();rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL;scroll.add_child(rows)
	message = Label.new();message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;box.add_child(message)
	var close := Button.new();close.text="Close";close.pressed.connect(dismiss);box.add_child(close)
	confirmation=HBoxContainer.new();box.add_child(confirmation)
	var question:=Label.new();question.text="Replace this slot?";confirmation.add_child(question)
	confirm_yes=Button.new();confirm_yes.text="Replace";confirmation.add_child(confirm_yes)
	confirm_yes.pressed.connect(func(): _save(overwrite_id))
	var cancel:=Button.new();cancel.text="Cancel";confirmation.add_child(cancel);cancel.pressed.connect(confirmation.hide)
	confirmation.hide()
	refresh()

func _button(text: String, action: Callable, enabled: bool = true) -> Button:
	var button := Button.new();button.text=text;button.disabled=not enabled
	button.clip_text=true;button.tooltip_text=text.replace("\n"," · ");button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.pressed.connect(action);rows.add_child(button)
	return button

static func describe(row: Dictionary) -> String:
	if not row.exists:return "Empty"
	if not row.valid:return "Damaged — "+str(row.error)
	var seconds:=int(row.play_seconds)
	var area: String = Save.Areas.ROWS[row.area].label
	var label: String = str(row.label)
	var heading := area if label == row.area or label == area else label + " · " + area
	return "%s\n%s · %d:%02d played" % [heading,Time.get_datetime_string_from_unix_time(int(row.written_unix),true),seconds/3600,(seconds/60)%60]

func refresh() -> void:
	for child in rows.get_children():rows.remove_child(child);child.queue_free()
	for row in Save.slots():
		var title: String="Autosave" if row.id==Save.AUTOSAVE else "Slot %02d"%row.id
		var button:=_button(title+" — "+describe(row), choose.bind(row),row.id!=Save.AUTOSAVE if saving else row.valid)
		button.name="Slot_%02d"%row.id
		if not saving and row.backup.valid:
			var backup:=_button("    Previous save — "+describe(row.backup),_load.bind(row.id,true));backup.name="Backup_%02d"%row.id
	if not saving:
		for row in Save.legacy_saves():
			var date:=Time.get_datetime_string_from_unix_time(int(row.written_unix),true)
			var legacy_button:=_button("Old save: %s · %s"%[row.label,date],_legacy.bind(row.area),row.valid)
			legacy_button.name="Legacy_"+row.area
			var warning:=Label.new();warning.text="Level puzzles on other maps may be reset." if row.valid else row.error
			warning.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(warning)

func choose(row: Dictionary) -> void:
	if confirmation.visible:return
	if not saving:_load(row.id,false);return
	if row.exists:
		overwrite_id=row.id;confirmation.show()
	else:_save(row.id)

func _save(id: int) -> void:
	confirmation.hide()
	var request:=Save.request_manual_save(host,id)
	message.text="Saving…" if request.pending else ("Saved to slot %02d."%id if request.error.is_empty() else request.error)
	if request.error.is_empty() and not request.pending:refresh()

func _manual_finished(id:int,error:String):
	if not saving:return
	message.text="Saved to slot %02d."%id if error.is_empty() else error
	if error.is_empty():refresh()

func _verified() -> bool:
	if not verify_load.is_valid():return true
	var error: String=verify_load.call()
	message.text=error
	return error.is_empty()

func _load(id: int, backup: bool) -> void:
	if not _verified():return
	var error:=Save.load(get_tree(),id,backup)
	if error.is_empty():dismiss()
	else:message.text=error

func _legacy(area: String) -> void:
	if not _verified():return
	var error:=Save.load_legacy(get_tree(),area)
	if error.is_empty():dismiss()
	else:message.text=error

func dismiss() -> void:
	closed.emit();queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE,KEY_TAB]:
		dismiss();get_viewport().set_input_as_handled()
