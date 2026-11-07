extends SceneTree
## CFALL room 32 (CFALL_.WOM): source pins, callback effects, flags 5/6, the pool heal (D6A08(5)), entry regions, the op18
## placement and the room host on a stand-in Cave host (pause, overlay gate, cue order, Back refused while a cue plays).
const Cfall = preload("res://scripts/lol2/cave_cfall.gd")
const Room = preload("res://scripts/lol2/cave_cfall_room.gd")
const Body = preload("res://scripts/lol2/player_form_body.gd")
class FakeMagic extends RefCounted:
	var hp := 10
	func health() -> int: return hp
	func set_health(v: int) -> void: hp = v
class FakeHost extends Node3D:
	var native_translation := Vector3.ZERO
	var player: CharacterBody3D
	var camera: Camera3D
	var starting_magic: FakeMagic = FakeMagic.new()
	var video_overlay: CanvasLayer
	var interaction_requested := false
func fail(message: String) -> void:
	push_error(message);quit(1)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var src := Cfall.source()
	if src.is_empty() or not Room.assets_ready(): return fail("CFALL source/media not staged (tools/prepare_cave_cfall_room.py).")
	if src.room_name != "cfall_" or src.regions.size() != 3: return fail("Room identity.")
	for row in src.regions:
		if row.commands[0] != "0c03ca002000" or int(row.place.flags) != 0x0885: return fail("Region group pins.")
	if Cfall.hotspot_at(src, Vector2i(400,350)) != 0 or Cfall.hotspot_at(src, Vector2i(200,380)) != 1 or Cfall.hotspot_at(src, Vector2i(100,100)) != -1: return fail("Hotspots.")
	# Callback 9: quip 26 only on the first visit.
	var s := Cfall.initial()
	var first := Cfall.first_update(s, src)
	if first != [["ambient_start",344,130],["set_flag",5],["movie",2,26,24]]: return fail("First update: "+str(first))
	s.flags["5"] = 1
	if Cfall.first_update(s, src) != [["ambient_start",344,130]]: return fail("Later visits must stay silent.")
	if Cfall.click(0, src) != [["heal",5],["movie",2,55,24],["movie",2,20,24],["set_flag",6]] or Cfall.click(1, src) != Cfall.click(0, src) or not Cfall.click(2, src).is_empty(): return fail("Click effects.")
	if Cfall.heal(10,5) != 15 or Cfall.heal(28,5) != 30 or Cfall.heal(0,5) != 0: return fail("D6A08 heal.")
	if Cfall.validate({"version":1,"flags":{"5":2,"6":0}}).is_empty() or not Cfall.validate(Cfall.initial()).is_empty(): return fail("Validation.")
	# Entry regions: inside 1818 on its -192 floor; not from the wrong height; the op18 point is outside all three.
	if Cfall.region_at(src, Vector2(625,-11120), -192) != 1818 or Cfall.region_at(src, Vector2(625,-11120), -100) != -1: return fail("Region test.")
	for row in src.regions:
		if Cfall.region_at(src, Vector2(float(row.place.x), -float(row.place.y)), -192) != -1: return fail("op18 point inside an entry region.")
	# Room host on a stand-in Cave host.
	var host := FakeHost.new(); root.add_child(host)
	host.player = CharacterBody3D.new(); host.add_child(host.player); host.player.global_position = Vector3(625, -192+Body.FOOT_OFFSET, -11120)
	host.camera = Camera3D.new(); host.add_child(host.camera)
	var room := Room.new(); host.add_child(room)
	if not room.setup(host).is_empty(): return fail("Room setup.")
	room.was_inside = false
	if not room.advance(host.player.global_position, true): return fail("Grounded entry did not open the room.")
	if not paused or host.video_overlay != room or not room.active() or room.region != 1818: return fail("Room must pause the world and hold the overlay gate.")
	if int(room.state.flags["5"]) != 1 or not room.speaking(): return fail("First-visit quip.")
	if room.leave_room(): return fail("Back must wait for the cue.")
	while room.skip_line(): pass
	if room.speaking(): return fail("Cue queue did not drain.")
	if not room.click(Vector2i(400,350)): return fail("Pool click refused.")
	if host.starting_magic.hp != 15 or not room.speaking(): return fail("Heal before the quips: %d" % host.starting_magic.hp)
	if room.click(Vector2i(400,350)): return fail("Click accepted while a cue plays.")
	room.skip_line()
	if int(room.state.flags["6"]) != 0: return fail("Flag 6 must follow both quips.")
	room.skip_line()
	if int(room.state.flags["6"]) != 1 or room.speaking(): return fail("Flag 6 after the quips.")
	var saved=JSON.parse_string(JSON.stringify(room.checkpoint()))
	if not Cfall.validate(saved).is_empty() or saved.flags["5"] != 1.0: return fail("Checkpoint roundtrip.")
	if not room.leave_room(): return fail("Back refused.")
	if paused or room.active() or is_instance_valid(host.video_overlay): return fail("Leaving must resume the world.")
	var place: Dictionary = src.regions[2].place
	var p: Vector3 = host.player.global_position
	if absf(p.x-float(place.x)) > 0.01 or absf(p.z+float(place.y)) > 0.01 or absf(host.player.rotation.y-float(place.yaw)) > 1e-6: return fail("op18 placement: "+str(p))
	if room.advance(host.player.global_position, true): return fail("Room reopened at the placement point.")
	print("PASS cave CFALL room: room32 pins, hotspots, first-visit quip latch (flag5), pool heal +5 then quips 55/20 then flag6, entry regions with floor test, paused world + overlay gate, Back waits for cues, op18 placement outside the regions, checkpoint roundtrip.")
	host.queue_free(); await process_frame
	quit()
