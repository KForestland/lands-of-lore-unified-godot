extends "res://tests/dark_halls_objects_earned_test.gd"
func run() -> void:
	OS.set_environment("LOL2_DH_OBJECTS", "bookcases:51")
	await super.run()
