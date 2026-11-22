extends Node3D
const RESTORE_ON := ["load", "arrival"]
## L8 tree bridge. E at control 114 unlinks assembly 114 and links assembly 116.
## Opcode 9 arm 3 is the host link. Opcode 9 arm 2 is the host player release, not a mesh unlink.
## The port rule still unlinks 114 and links 116. Assembly 116 starts absent (flag 0x1000).
## OP9_ENTERED stays false: the calls after the link stores were not entered.
## Opcode 20 is sound 780 creaky2.aud. No movie is stored. Playback stays off. No fall distance is stored.
const KEY: String = "l8_tree_bridge"
const TREE := 114
const BRIDGE := 116
const AT := Vector3(5096, 0, 1916)
## Owner r17 stood at (5034, 1856), 86 from the trunk, and the chop did nothing. 64 only
## covers a body already pressed against the bark. 110 covers that stance on the west bank.
const REACH := 110.0
const OP9_ENTERED := false
const OP9_ARM2 := "player_release"
const OP9_ARM3 := "link"
const SOUND_ID := 780
const SOUND_NAME := "creaky2.aud"
const OP20_PLAYED := false
var host: Node3D

static func initial() -> Dictionary:
	return {"version": 1, "knocked": false}

static func validate(saved: Variant, quests: Dictionary) -> String:
	if not quests is Dictionary: return "Invalid tree bridge."
	if not saved is Dictionary or saved.size() != 2 or int(saved.get("version", 0)) != 1 or not saved.get("knocked") is bool:
		return "Invalid tree bridge."
	return ""

static func owns(face: Dictionary) -> bool:
	if face.get("kind") != "movable" or face.get("placement_kind") != "static_assembly": return false
	var id := int(face.get("source_index", -1))
	return id == TREE or id == BRIDGE

static func attach(map: Node3D) -> Node:
	var node: Node = load("res://scripts/lol2/l8_tree_bridge.gd").new()
	node.host = map
	node.name = "L8TreeBridge"
	map.add_child(node)
	return node

func state() -> Dictionary:
	return host.quest_state.get(KEY, initial())

func flat_distance() -> float:
	var delta: Vector3 = host.player.global_position - AT
	return Vector2(delta.x, delta.z).length()

## Human with a catalog weapon. A bare hand or another form does not fell the tree.
func armed() -> bool:
	if int(host.get("player_form")) != 0: return false
	return preload("res://scripts/lol2/item_catalog.gd").slot(str(host.get("equipped_item"))) == "weapon"

func hint_line() -> String:
	if bool(state().knocked) or flat_distance() > REACH: return ""
	if armed(): return "E — Chop the tree"
	return "Hold a weapon to chop the tree."

func use() -> bool:
	if host.get_tree().paused or bool(host.flying): return false
	if flat_distance() > REACH: return false
	if bool(state().knocked): return true
	if not armed():
		if host.has_method("save_feedback"): host.save_feedback(hint_line())
		return false
	host.quest_state[KEY] = {"version": 1, "knocked": true}
	restore()
	if host.has_method("save_feedback"): host.save_feedback("The tree lies across the chasm.")
	return true

## Assembly 116's walk slab is 12 wide. The human capsule radius is 15, so the body cannot
## rest on it, and the west bank (floor 0) is 26 below the slab. The deck is a flush floor
## across that hole. The log mesh stays where the file put it.
func _sync_deck(knocked: bool) -> void:
	var existing: Node = get_node_or_null("WalkDeck")
	if not knocked:
		if existing != null: existing.queue_free()
		return
	if existing != null: return
	var body := StaticBody3D.new()
	body.name = "WalkDeck"
	body.collision_layer = 1 << 8
	body.collision_mask = 0
	# West bank floor is 0 and ends near x 5121. East bank floor is -200. A flush deck
	# across that hole is what the body walks. The visual log stays where the file put it.
	var deck := CollisionShape3D.new()
	var deck_box := BoxShape3D.new()
	deck_box.size = Vector3(5365.0 - 5060.0, 8.0, 64.0)
	deck.shape = deck_box
	deck.position = Vector3((5060.0 + 5365.0) * 0.5, -3.0, 1908.0)
	body.add_child(deck)
	add_child(body)

func restore() -> void:
	var assemblies: Variant = host.get("preview_assemblies")
	if assemblies == null or not is_instance_valid(assemblies): return
	var knocked: bool = bool(state().knocked)
	assemblies.set_present(TREE, not knocked)
	assemblies.set_present(BRIDGE, knocked)
	# The stored slab is 12 wide and the human capsule radius is 15, so that body cannot
	# stand on it. The deck is the solid. The log mesh stays.
	if knocked and assemblies.solid_bodies.has(BRIDGE):
		assemblies.solid_bodies[BRIDGE].collision_layer = 0
	_sync_deck(knocked)

func _ready() -> void:
	restore()

func _process(_delta: float) -> void:
	var text: String = hint_line()
	if text.is_empty() or not is_instance_valid(host.get("interface_hud")): return
	host.interface_hud.hint.text = text
	host.interface_hud.save_notice_remaining = 0.2

func _playing() -> bool:
	if host.get_tree().paused or bool(host.flying): return false
	if is_instance_valid(host.get("inventory")): return false
	# Headless has no window, so a captured mouse cannot stick. A real window still requires it.
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"

func _input(event: InputEvent) -> void:
	if not _playing(): return
	var chop: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E
	if not chop and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chop = true
	if chop and use(): get_viewport().set_input_as_handled()
