extends "res://scripts/lol2/hive_rune_population.gd"
## Test-only admission adapter: headless DisplayServer cannot capture the mouse.
## Rendered tests must exercise the production world_active gate separately.
func active() -> bool:
	return not get_tree().paused and not host.flying and host.get_node("Warriors").health>0
