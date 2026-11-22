extends "res://tests/atlas_remaining_walk_test.gd"
func run() -> void:
 OS.set_environment("LOL2_ATLAS_AREA", "L1_DC")
 await super.run()
