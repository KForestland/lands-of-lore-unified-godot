extends Node3D
## Lead-approved source103/movie31/arena admission adapter; native18 semantics unclaimed.
const KEY="l13_belial"
const WEB=Vector3(-5482,4,-155)
const ARRIVAL=Vector3(-2974,-1108,-2680) # Source X/Z, region577 floor-1140 + shared foot offset32.
const Movie=preload("res://scripts/lol2/l13_belial_movie.gd")
var host:Node3D
var hint:Label
var playing:=false
static func initial()->Dictionary:return {"version":1,"entered":false,"cured":false,"poison_clock":0.0}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=4 or s.get("version")!=1 or not s.get("entered") is bool or not s.get("cured") is bool:return "Invalid Citadel encounter."
 var clock=s.get("poison_clock")
 if not (clock is int or clock is float) or not is_finite(float(clock)) or clock<0 or clock>=2:return "Invalid Citadel poison clock."
 if not s.entered and (s.cured or clock!=0):return "Citadel cure precedes entry."
 if s.cured and clock!=0:return "Cured Citadel poison retains clock."
 if s.entered and not quests.get("l13_bridge",{}).get("started",false):return "Citadel encounter precedes bridge."
 return ""
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l13_belial.gd").new();n.host=map;n.name="L13Belial";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint)
func can_enter()->bool:
 if playing or state().entered or host.player_form!=0 or not host.starting_magic.world_active() or not Movie.assets_ready():return false
 var d:Vector3=host.camera.global_position-(WEB+Vector3.UP*32)
 return d.length()<125 and (-host.camera.global_basis.z).dot(-d.normalized())>0.85 and host.player.is_on_floor() and host.get_node("L13Prison").all_ruloi_dead()
func enter()->bool:
 if not can_enter():return false
 playing=true
 var overlay=Movie.new();host.video_overlay=overlay
 overlay.ended.connect(func(_reason:String):
  host.video_overlay=null;playing=false
  var s:=state().duplicate(true);s.entered=true;host.quest_state[KEY]=s
  host.player.position=ARRIVAL;host.player.velocity=Vector3.ZERO;host.player.rotation.y=-PI/2;host.camera.rotation=Vector3.ZERO
  host.save_feedback("The creature waits beyond the web. Cast Healing III to counter its poison."))
 host.add_child(overlay);return true
func cure_available()->bool:return state().entered and not state().cured and not playing
func cure()->void:
 var s:=state().duplicate(true);s.cured=true;s.poison_clock=0.0;host.quest_state[KEY]=s
func _physics_process(delta):
 if not host.starting_magic.world_active() or not state().entered or state().cured:return
 var s:=state().duplicate(true);s.poison_clock+=delta
 if s.poison_clock>=2:
  s.poison_clock=fmod(s.poison_clock,2.0);host.starting_magic.set_health(maxi(0,host.starting_magic.health()-1))
 host.quest_state[KEY]=s
func _process(_delta):hint.text="E — Enter the web doorway" if can_enter() else ""
func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and enter():get_viewport().set_input_as_handled()
