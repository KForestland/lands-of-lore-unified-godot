extends "res://scripts/lol2/cave_walkthrough.gd"
## Test-only packet omission. The inherited production sender must reject without leaving/mutating.
var omitted_field := ""
func _completion_state() -> Dictionary:
	var packet := super._completion_state()
	if not omitted_field.is_empty(): packet.erase(omitted_field)
	return packet
