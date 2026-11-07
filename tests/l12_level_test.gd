extends "res://tests/act2_level_transition_case.gd"
func specification() -> Dictionary:
	return {"story_gate": true, "area": "L12_CM", "scene": "res://scenes/lol2/maps/L12_CM.tscn", "start": Vector3(2784,-1198,-18222),
		"object": "control:74", "event": 5, "input": {"caller_byte": 4, "caller_byte_2": 0, "context": "control:74"}, "group": 2808, "level": 13, "selector": 1,
		"destination": "res://scenes/lol2/maps/L13_RC.tscn", "position": Vector3(-3260,32,6631), "yaw": -TAU * 1.0 / 65536.0}
