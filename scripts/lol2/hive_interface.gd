extends "res://scripts/lol2/museum_interface.gd"
## Shared original-art interface with Hive health and conversation input guards.
func conversation_active() -> bool:
	var actor = walkthrough.get_node("ConversationReview")
	return actor.started and not actor.completed
func _input(event: InputEvent) -> void:
	if is_instance_valid(walkthrough.runes) and walkthrough.runes.active(): return
	if conversation_active() and event is InputEventKey and event.pressed and event.keycode in [KEY_TAB,KEY_I,KEY_M]:
		get_viewport().set_input_as_handled()
		return
	super._input(event)
func open_page(page: String) -> void:
	if conversation_active(): return
	super.open_page(page)
func toggle_atlas() -> void:
	if conversation_active(): return
	super.toggle_atlas()
func character_text() -> String:
	var weapon := preload("res://scripts/lol2/player_equipment.gd").label(walkthrough.equipped_item) if walkthrough.equipped_item != "" else "Unarmed"
	if walkthrough.get("player_form") != null and not preload("res://scripts/lol2/player_form_rules.gd").can_use_weapon(int(walkthrough.player_form)): weapon += " (stored while transformed)"
	var armor := "Mail Shirt" if walkthrough.equipped_armor != "" else "None"
	var mana_text := ""
	if not walkthrough.player_magic_checkpoint.is_empty():
		var magic: Dictionary = walkthrough.player_magic_checkpoint.player
		mana_text = "\nMana: %d / %d" % [magic.mana,magic.maximum]
	return "Health: %d / 30\nForm: %s\nWeapon: %s\nArmor: %s\nChange equipment in Inventory." % [walkthrough.get_node("Warriors").health,walkthrough.curse.message(),weapon,armor]+mana_text

var wax_hint := false
func _process(delta: float) -> void:
	super._process(delta)
	if save_notice_remaining > 0 or cursor_active:
		wax_hint = false
		return
	var show_lift: bool = is_instance_valid(walkthrough.elevator) and walkthrough.elevator.target_control() >= 0
	var show_wax: bool = is_instance_valid(walkthrough.wax) and walkthrough.wax.target()
	var show_runes: bool = is_instance_valid(walkthrough.runes) and walkthrough.runes.target()
	var show_light: bool = is_instance_valid(walkthrough.rune_light) and walkthrough.rune_light.target()
	if show_light: hint.text = "G — Cast Spark"
	elif show_runes: hint.text = "E — Examine rune room"
	elif show_wax: hint.text = "E — Take wax"
	elif show_lift: hint.text = "E — Use lift control"
	elif walkthrough.curse.state.phase in [1,3]: hint.text = walkthrough.curse.message()
	elif wax_hint: hint.text = "Tab — Interface · M — Atlas · F5/F9 — Save/Load"
	wax_hint = show_light or show_runes or show_wax or show_lift or walkthrough.curse.state.phase in [1,3]
