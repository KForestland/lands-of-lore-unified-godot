extends SceneTree
const Trigger=preload("res://scripts/lol2/cave_rapids_trigger.gd")
const Save=preload("res://scripts/lol2/walkthrough_save.gd")
func _initialize() -> void:
	var packet:=Trigger.initial_packet()
	assert(Trigger.validate_packet(packet).is_empty())
	assert(Trigger.State.hit(packet.state,1,1,1,0).released)
	assert(not Trigger.validate_packet(packet).is_empty())
	packet.view_effect_pending=true
	for time in [0.0,1.25,Trigger.DURATION]:
		packet.sound_time=time
		assert(Trigger.validate_packet(JSON.parse_string(JSON.stringify(packet))).is_empty())
	packet.sound_time=Trigger.DURATION+1
	assert(not Trigger.validate_packet(packet).is_empty())
	packet=Trigger.initial_packet();Trigger.State.hit(packet.state,1,1,1,1)
	assert(Trigger.validate_packet(packet).is_empty())
	packet.sound_time=1;assert(not Trigger.validate_packet(packet).is_empty())
	print("PASS rapids trigger packet: source sound bounds, released versus refused hit, pending source view receipt and JSON. Controller and main-save scripts compile; actual input/audio integration awaits rendered test.")
	quit()
