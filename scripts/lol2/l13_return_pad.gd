extends Node3D
## Original control54/group8152; logged modern contact/transport persistence.
const KEY="l13_return_pad"
const PAD=Vector3(-2347,-1049,-3828)
const ARRIVAL=Vector3(-3267,32,6385)
## Lead 2026-11-15 (Grok r19o3: only a jump fired it, the stand showed only the key legend): control54 is a kind-5
## step-on pad like control:53, so walking onto it fires it too (grounded on its floor, having moved), and a line near it
## says what it does. The jump admission stays. DEVIATIONS row 0670.
const FLOOR:=-1050.0
const NEAR_HINT:="Step onto the pad to return to the citadel entrance"
var host:Node3D
var latched:=false
var last_step:=Vector2.INF
var hint:Label
static func initial()->Dictionary:return {"version":1,"used":false}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=2 or s.get("version")!=1 or not s.get("used") is bool:return "Invalid Citadel return pad."
 if s.used and not quests.get("l13_altar",{}).get("stone_taken",false):return "Citadel return precedes Dreamstone."
 return ""
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l13_return_pad.gd").new();n.host=map;n.name="L13ReturnPad";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func usable()->bool:
 return host.player_form==0 and host.starting_magic.world_active() and host.quest_state.get("l13_altar",{}).get("stone_taken",false)
func walked_on(p:Vector3)->bool:
 # A step, not a placement: some movement this tick, and less than a teleport (a load or transport onto the pad).
 var step:=Vector2(p.x,p.z).distance_squared_to(last_step)
 return host.player.is_on_floor() and absf(p.y-32-FLOOR)<=6 and step>0.0625 and step<400.0
func can_enter()->bool:
 if latched or not usable():return false
 var p:Vector3=host.player.position
 if Vector2(p.x-PAD.x,p.z-PAD.z).length()>=45:return false
 return (p.y-32>PAD.y+10 and p.y-32<PAD.y+90 and not host.player.is_on_floor()) or walked_on(p)
func enter()->bool:
 if not can_enter():return false
 latched=true;host.quest_state[KEY]={"version":1,"used":true}
 host.player.position=ARRIVAL;host.player.velocity=Vector3.ZERO;host.player.rotation.y=-PI;host.camera.rotation=Vector3.ZERO
 host.curse.set_requests_enabled(true)
 host.save_feedback("The pad returns you to the citadel entrance.");return true
func _ready():
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,410);canvas.add_child(hint)
func _physics_process(_delta):
 var p:Vector3=host.player.position
 if last_step==Vector2.INF:last_step=Vector2(p.x,p.z);return # a load standing on the pad does not fire it
 if Vector2(p.x-PAD.x,p.z-PAD.z).length()>=45:latched=false
 enter()
 last_step=Vector2(host.player.position.x,host.player.position.z)
func _process(_delta):
 var p:Vector3=host.player.position
 hint.text=NEAR_HINT if not latched and usable() and absf(p.y-32-FLOOR)<=6 and Vector2(p.x-PAD.x,p.z-PAD.z).length()<105 else ""
