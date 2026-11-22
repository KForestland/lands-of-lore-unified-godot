extends SceneTree
const Admission = preload("res://scripts/lol2/save_admission.gd")
class Magic extends Node:
	var value := 30
	func health() -> int: return value
class Body extends Node3D:
	var grounded := true
	func is_on_floor() -> bool: return grounded
class Liquid extends Node:
	func polygon_at(_point: Vector3) -> Dictionary: return {"surface":1000}
class SpeechProbe extends RefCounted:
	static func active(packet:Dictionary)->bool:return packet.speaking
class Room extends Node:
	const State=SpeechProbe
	var speaking:=true
	func active()->bool:return true
	func state()->Dictionary:return {"speaking":speaking}
class Host extends Node3D:
	var starting_magic := Magic.new()
	var player := Body.new()
	var ready_for_review := true
	var flying := false
	var locked := false
	var video_overlay: Node
	var liquid_drowning: Node
	var magic_shop:Node
	var chamber_arrival_state:="not_started"
	func _ready() -> void: add_child(starting_magic); add_child(player)
	func actor_input_locked() -> bool: return locked
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var host := Host.new(); root.add_child(host); current_scene = host
	assert(Admission.reason(host).is_empty())
	paused = true; assert(not Admission.reason(host).is_empty()); paused = false
	host.flying = true; assert(not Admission.reason(host).is_empty()); host.flying = false
	host.starting_magic.value = 0; assert(not Admission.reason(host).is_empty()); host.starting_magic.value = 30
	host.player.grounded = false; assert(not Admission.reason(host).is_empty()); host.player.grounded = true
	host.ready_for_review = false; assert(not Admission.reason(host).is_empty()); host.ready_for_review = true
	host.locked = true; assert(not Admission.reason(host).is_empty()); host.locked = false
	for key in Admission.TRANSFERS:
		set_meta(key, {}); assert(not Admission.reason(host).is_empty()); remove_meta(key)
	host.chamber_arrival_state="playing";assert(not Admission.reason(host).is_empty());host.chamber_arrival_state="not_started"
	host.magic_shop=Room.new();host.add_child(host.magic_shop)
	assert(not Admission.reason(host).is_empty(),"active room speech blocks saving")
	host.magic_shop.speaking=false;assert(Admission.reason(host).is_empty(),"idle room remains saveable")
	host.magic_shop.free()
	host.video_overlay = Node.new(); host.add_child(host.video_overlay)
	assert(not Admission.reason(host).is_empty()); host.video_overlay.free()
	host.liquid_drowning = Liquid.new(); host.add_child(host.liquid_drowning)
	assert(not Admission.reason(host).is_empty())
	host.player.position.y = 1100
	assert(Admission.reason(host).is_empty(), "standing above a liquid is safe")
	host.free(); current_scene = null
	print("PASS save admission: loading/pause/flight/death/air/scene/transfer/wading; solid dry play admitted")
	quit()
