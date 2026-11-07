extends RefCounted
## Bounded recovered Short Sword versus chain rule; not a general combat system.
## Input amount generation is external. Immediate script-state write is preview scheduling.
const BREAK_COMMAND := 5370
var remaining := 2
var script_state := 0

func strike(amount: int = 1, difficulty_byte: int = 1) -> int:
	if script_state != 0 or amount < 0 or amount > 255 or difficulty_byte < 0 or difficulty_byte > 2:
		return 0
	var scaled := amount
	if difficulty_byte == 0:
		scaled *= 2
	elif difficulty_byte == 2 and amount > 2:
		scaled = amount / 2
	var reduction := mini(remaining, maxi(1, scaled))
	remaining = maxi(remaining - reduction, 0)
	if remaining <= 1:
		script_state = 1
		return BREAK_COMMAND
	return 0

func reset() -> void:
	remaining = 2
	script_state = 0
