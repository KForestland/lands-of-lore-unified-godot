extends Node
## RIX (L7 actor57) on the Dark Halls creature owner. His death runs the source death group 14414 (soul -1,
## GV_RIX_DEAD = 1; the cellar room already hides him by GV_RIX_DEAD); E on his body then gives the event4/
## predicate216 grant "14-Plasma staff" (group 14496). State: quests.dark_halls_rix {"dead","staff"}. His talk and
## give-item branches (soul +2) are not hosted (docs/DEVIATIONS.md).
const SOURCE := "res://scripts/lol2/dark_halls_loot_source.json"
const ID := "57"
const REACH := 110.0
var host: Node3D
var rix: Dictionary = {}

func setup(walkthrough: Node3D) -> void:
	name = "DarkHallsRix"
	host = walkthrough
	rix = JSON.parse_string(FileAccess.get_file_as_string(SOURCE)).rix

func state() -> Dictionary:
	var quests: Dictionary = host.quest_state
	if not quests.get("dark_halls_rix") is Dictionary: quests.dark_halls_rix = {"dead": false, "staff": false}
	return quests.dark_halls_rix

static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != 2 or not value.get("dead") is bool or not value.get("staff") is bool: return "Invalid Rix state."
	if value.staff and not value.dead: return "Rix staff taken before his death."
	return ""

func population_dead() -> bool:
	var pop = host.get("creatures")
	return pop != null and is_instance_valid(pop) and pop.state.actors.has(ID) and int(pop.state.actors[ID].health) == 0

## Source group 14414: ce00000000ff (soul -1) and c70000003001 (GV_RIX_DEAD = 1), once.
func apply_death() -> bool:
	if bool(state().dead) or not population_dead(): return false
	var monastery: Dictionary = host.quest_state.get("monastery", {})
	if monastery.get("globals") is Dictionary:
		var globals: Dictionary = monastery.globals
		preload("res://scripts/lol2/shared_global_defaults.gd").add_soul(globals, -1)  # SOUL-SYSTEM: clamped 0..10
		globals.GV_RIX_DEAD = 1
	state().dead = true
	if host.has_method("save_feedback"): host.save_feedback("Rix is dead.")
	return true

func take_staff() -> bool:
	if not bool(state().dead) or bool(state().staff) or not host.get("carried_collected") is Array: return false
	var pop = host.get("creatures")
	if pop == null or not pop.bodies.has(ID): return false
	var offset: Vector3 = pop.bodies[ID].global_position + Vector3(0, 20, 0) - host.camera.global_position
	if offset.length() > REACH or (-host.camera.global_basis.z).dot(offset.normalized()) < 0.75: return false
	var id: String = rix.corpse.id
	if not id in host.carried_collected:
		if host.carried_collected.size() >= preload("res://scripts/lol2/item_catalog.gd").MAX_CARRIED:
			if host.has_method("save_feedback"): host.save_feedback("Inventory full.")
			return false
		host.carried_collected.append(id)
	state().staff = true
	if host.has_method("save_feedback"): host.save_feedback("Plasma staff taken.")
	return true

func _physics_process(_delta: float) -> void:
	if host != null: apply_death()

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or get_tree().paused: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and take_staff():
		get_viewport().set_input_as_handled()
