extends RefCounted
## Actual production entry points, with target selection/receivers isolated.
## These are contract tests, not earned walks. Overrides never run in real-click cases.
class Host extends Node3D:
	var player_form := 0
	var equipped_item := ""
	var carried_inventory := {"equipped_item":""}
	var carried_collected: Array = []
	var item_effects: Node
	var starting_magic: Node
	var quest_state := {}
	var flying := false
	var player: CharacterBody3D
	var camera: Camera3D
	var act2_creatures: Node3D
	var roach: Node3D
	var roach_population := {"actors":{"spy":{"health":1000}}}
class Bonus extends Node:
	var enabled := false
	func melee_damage(base: int) -> int:
		var champion=preload("res://scripts/lol2/player_item_effects.gd").empty()
		champion.active=enabled
		return base+int(preload("res://scripts/lol2/player_item_effects.gd").melee_bonus(champion).bonus)
class Magic extends Node:
	func world_active() -> bool: return true
class Shared extends "res://scripts/lol2/scripted_creature_population.gd":
	var amount := -1
	func _ready(): pass
	func world_active() -> bool: return true
	func aimed() -> String: return "spy"
	func receive_damage(_id: String, damage: int, _melee: bool=true, _effect: int=20) -> bool: amount=damage;return true
	func net_hit(_id: String, _item: String) -> bool: return false
	func prism_hit(_id: String, _item: String) -> int: return 0
class Dino extends "res://scripts/lol2/jungle_dino_population.gd":
	var amount := -1
	func _ready(): pass
	func world_active() -> bool: return true
	func aimed() -> String: return "spy"
	func receive_damage(_id: String, damage: int, _melee: bool=true, _effect: int=20) -> bool: amount=damage;return true
	func net_hit(_id: String, _item: String) -> bool: return false
	func prism_hit(_id: String, _item: String) -> int: return 0
class CavePop extends "res://scripts/lol2/cave_roach_population.gd":
	var amount := -1
	func _ready(): pass
	func receive_damage(_id: String, damage: int, _melee: bool=true, _effect: int=20) -> bool: amount=damage;return true
class Roach extends "res://scripts/lol2/cave_roach.gd":
	var amount := -1
	func _ready(): pass
	func clear_ray(_start: Vector3, _end: Vector3) -> bool: return true
	func receive_strike(reach: bool, aim: bool, clear: bool, damage: int) -> bool:
		if not (reach and aim and clear): return false
		amount=damage;return true
class Prototype extends "res://scripts/lol2/cave_encounter.gd":
	func _ready(): add_child(curse);PlayerHealth.attach(self)
	func _clear_ray(_start: Vector3, _end: Vector3) -> bool: return true
	func _save_feedback(_message: String) -> void: pass
class Hive extends "res://scripts/lol2/hive_warriors.gd":
	var amount := -1
	var target: StaticBody3D
	func _ready(): pass
	func active() -> bool: return true
	func aimed_hit() -> Dictionary: return {"collider":target}
	func damage_guardian(_index: int, damage: int, _effect: int=-1) -> bool: amount=damage;return true
class Confidante extends "res://scripts/lol2/jungle_confidante.gd":
	func _ready(): pass
	func _aimed() -> Dictionary: return {"control":112}
	func context() -> Dictionary: return {}
	func apply(_effects: Array) -> void: pass
class Dam extends "res://scripts/lol2/jungle_river_dam.gd":
	var amount := -1
	func _ready(): pass
	func aimed() -> bool: return true
	func receive_hit(_mask0: int, _mask2: int, damage: int) -> bool: amount=damage;return true
class Bramble extends "res://scripts/lol2/jungle_bramble.gd":
	var amount := -1
	func _ready(): pass
	func _active() -> bool: return true
	func aimed_id() -> int: return 109
	func receive_hit(_id: int, _mask0: int, _mask2: int, damage: int) -> bool: amount=damage;return true
class Progression extends "res://scripts/lol2/act2_progression.gd":
	var amount := -1
	func _ready(): pass
	func fire(_ref: String, _event: int, input: Dictionary={}) -> Array: amount=int(input.dword_1e);return []
	func _store_struck() -> void: pass
class Orc extends "res://scripts/lol2/cave_old_orc.gd":
	var amount := -1
	func _ready(): pass
	func _world_active() -> bool: return true
	func aimed() -> bool: return true
	func receive_hit(damage: int) -> bool: amount=damage;return true
class Stalactite extends "res://scripts/lol2/cave_stalactites.gd":
	var amount := -1
	func _ready(): pass
	func aimed() -> String: return "spy"
	func receive_hit(_id: String, _mask0: int, _mask2: int, damage: int) -> bool: amount=damage;return true
class Pillar extends "res://scripts/lol2/cave_pillar_trap.gd":
	var amount := -1
	func _ready(): pass
	func aimed() -> bool: return true
	func receive_hit(_mask0: int, _mask2: int, damage: int) -> bool: amount=damage;return true
class Museum extends "res://scripts/lol2/museum_walkthrough.gd":
	func _ready(): add_child(curse);PlayerHealth.attach(self)

class Tribe extends "res://scripts/lol2/l8_tribe.gd":
	func _ready(): pass
class AimedDaniel extends Node3D:
	func aimed()->String:return "23"
