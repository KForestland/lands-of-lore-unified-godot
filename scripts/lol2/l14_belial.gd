extends Node3D
##0305: source descriptor115 ->prop221 opcode18 admission; native operand modes UNKNOWN.
const KEY="l14_belial"
const ARRIVAL=Vector3(42,22,11041)
const FLOORS=[2137,2138,2139,2140,2141,2142]
var host:Node3D
var lowered:Node3D
var sides:Node3D
var hint:Label
static func initial()->Dictionary:return {"version":1,"entered":false,"spoken":false}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("entered") is bool or not s.get("spoken") is bool:return "Invalid Temple encounter."
 if s.spoken and not s.entered:return "Temple conversation precedes entry."
 if s.entered:
  var lift:Dictionary=quests.get("l14_hopper_platform",{})
  if lift.get("lowered",0)!=4 or not preload("res://scripts/lol2/l14_hopper_platform.gd").complete(lift):return "Temple encounter lacks weighted descent."
 return ""
static func owns(f:Dictionary)->bool:return f.get("kind") in ["floor","wall"] and f.get("region")!=null and int(f.region) in FLOORS
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_belial.gd").new();n.host=map;n.name="L14Belial";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 lowered=Node3D.new();add_child(lowered);sides=Node3D.new();add_child(sides)
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file));var floors:Array=[];var walls:Array=[]
 for f in pack.faces:
  if owns(f):
   if f.kind=="floor":floors.append(f)
   else:walls.append(f)
 host.get_node("L14Niche").build(lowered,floors)
 if not walls.is_empty():host.get_node("L14Niche").build(sides,walls)
 var canvas:=CanvasLayer.new();add_child(canvas);hint=Label.new();hint.position=Vector2(24,480);canvas.add_child(hint);restore()
func can_enter()->bool:
 if state().entered or host.player_form!=0 or not host.starting_magic.world_active() or not host.player.is_on_floor():return false
 var lift=host.get_node("L14HopperPlatform");var p:Vector3=host.player.position
 var back:Dictionary=lift.return_state()
 var settled:bool=(not back.started and back.raised==0) or (back.started and back.raised==4)
 var floor_y:float=-70+370*float(back.raised)/4
 return lift.state().lowered==4 and lift.complete(lift.state()) and settled and p.x>=-35 and p.x<=115 and p.z>=5814 and p.z<=6026 and absf(p.y-32-floor_y)<5
func enter()->bool:
 if not can_enter():return false
 var s:=initial();s.entered=true;host.quest_state[KEY]=s;restore()
 host.player.position=ARRIVAL;host.player.velocity=Vector3.ZERO;host.player.rotation.y=PI;host.camera.rotation=Vector3.ZERO
 host.save_feedback("The weighted elevator descends into the Chamber of Voices.")
 return true
func restore():
 if lowered==null:return
 lowered.position.y=-360 if state().entered else 0
 sides.visible=not state().entered
 for child in sides.get_children():
  if child is CollisionObject3D:child.collision_layer=0 if state().entered else 1
func _physics_process(_delta):restore()
func near_boss()->bool:
 if not state().entered or not host.starting_magic.world_active():return false
 return host.player.position.distance_to(host.act2_creatures.bodies["90"].position)<220
func talk()->bool:
 if not near_boss() or state().spoken:return false
 var s:=state().duplicate();s.spoken=true;host.quest_state[KEY]=s
 preload("res://scripts/lol2/scripted_creature_state.gd").wake(host.act2_creatures.state,"90")
 host.act2_creatures.sync_quests()
 host.save_feedback("The Hive Lord challenges you. Remember Dawn's warning: fight in Beast form.")
 return true
func choose_form()->bool:
 if not near_boss() or "act2:L13_RC:dreamstone" not in host.carried_collected or host.curse.state.phase in [1,3]:return false
 return host.curse.request_timed_form(1,120.0) if host.player_form==0 else host.curse.request_human() if host.player_form==1 else false
func permits_hit(melee:bool,amount:int)->bool:
 if amount<=0 or not state().spoken or not host.starting_magic.world_active():return false
 if not melee:
  host.starting_magic.set_health(maxi(0,host.starting_magic.health()-mini(amount,15)))
  host.save_feedback("The Hive Lord reflects the attack.");return false
 if host.player_form!=1:
  host.save_feedback("Only the Beast can wound this Hive Lord.");return false
 return true
func _process(_delta):
 hint.text="F — Descend to the Chamber of Voices" if can_enter() else ""
 if near_boss():hint.text="G — Change form"+("    E — Confront the Hive Lord" if not state().spoken else "")
func _unhandled_key_input(event:InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo:return
 if (event.keycode==KEY_F and enter()) or (event.keycode==KEY_E and talk()) or (event.keycode==KEY_G and choose_form()):get_viewport().set_input_as_handled()
