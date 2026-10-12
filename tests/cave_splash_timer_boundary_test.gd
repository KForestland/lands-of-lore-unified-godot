extends SceneTree
class Ambient:
	extends "res://scripts/lol2/cave_side_chamber.gd"
	var shown := {}
	func _show(key: String, index: int) -> void: shown[key] = index
func _initialize() -> void:
	var a := Ambient.new()
	a.source = {"frame_seconds":0.1,"props":{},"sequencer":{"period_seconds":1.0,"random_states":1,"order":{"0":558}}}
	a.textures["558"] = range(15)
	a.advance(1.0)
	var age: float = a.splash.get("558", -1.0)
	if a.shown.get("558", -1) != 0: push_error("Trigger did not show frame0"); quit(1); return
	print("New splash age at exact timer boundary: ", age)
	a.advance(1.25)
	var b := Ambient.new()
	b.source = a.source.duplicate(true)
	b.textures["558"] = range(15)
	for i in 9: b.advance(0.25)
	var matched := a.triggers == b.triggers and absf(a.splash.get("558", -1.0) - b.splash.get("558", -1.0)) < 0.000001
	print("Large versus split steps match: ", matched, " age=", a.splash.get("558", -1.0))
	a.free(); b.free()
	if not matched: quit(1); return
	if absf(age) > 0.000001:
		push_error("New splash aged before its trigger boundary")
		quit(1)
	else:
		print("PASS cave_splash_timer_boundary: fresh frame0 at exact boundary; large and split steps agree")
		quit(0)
