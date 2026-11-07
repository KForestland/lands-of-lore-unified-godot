extends Node3D
## Original control54/group8152; logged modern contact/transport persistence.
const KEY="l13_return_pad"
const PAD=Vector3(-2347,-1049,-3828)
const ARRIVAL=Vector3(-3267,32,6385)
var host:Node3D
var latched:=false
static func initial()->Dictionary:return {"version":1,"used":false}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=2 or s.get("version")!=1 or not s.get("used") is bool:return "Invalid Citadel return pad."
 if s.used and not quests.get("l13_altar",{}).get("stone_taken",false):return "Citadel return precedes Dreamstone."
 return ""
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l13_return_pad.gd").new();n.host=map;n.name="L13ReturnPad";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func can_enter()->bool:
 if latched or host.player_form!=0 or not host.starting_magic.world_active() or not host.quest_state.get("l13_altar",{}).get("stone_taken",false):return false
 var p:Vector3=host.player.position
 return Vector2(p.x-PAD.x,p.z-PAD.z).length()<45 and p.y-32>PAD.y+10 and p.y-32<PAD.y+90 and not host.player.is_on_floor()
func enter()->bool:
 if not can_enter():return false
 latched=true;host.quest_state[KEY]={"version":1,"used":true}
 host.player.position=ARRIVAL;host.player.velocity=Vector3.ZERO;host.player.rotation.y=-PI;host.camera.rotation=Vector3.ZERO
 host.curse.set_requests_enabled(true)
 host.save_feedback("The pad returns you to the citadel entrance.");return true
func _physics_process(_delta):
 if host.player.is_on_floor():latched=false
 enter()
