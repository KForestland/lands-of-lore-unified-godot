extends Node3D
## Original eleven plates and counter180; modern reveal wave and 60Hz lifetime.
const KEY="l13_bridge"
const ORDER=[90,100,95,99,94,98,93,97,92,96,91]
const PERIOD=9.0
const SPACING=0.45
const LIFE=3.0
var host:Node3D
var plates:Dictionary={}
static func initial()->Dictionary:return {"version":1,"started":false,"phase":0.0}
static func validate(s:Variant)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("started") is bool:return "Invalid Citadel bridge."
 var p=s.get("phase")
 if not (p is int or p is float) or not is_finite(float(p)) or p<0 or p>=PERIOD or (not s.started and p!=0):return "Invalid bridge clock."
 return ""
static func owns(f:Dictionary)->bool:return f.get("placement_kind")=="static_assembly" and int(f.get("source_index",-1)) in ORDER+[84]
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l13_bridge.gd").new();n.host=map;n.name="L13Bridge";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for id in ORDER+[84]:
  var plate:=Node3D.new();plate.name="OriginalPlate"+str(id);add_child(plate);plates[id]=plate
  var faces:Array=[]
  for f in pack.faces:
   if owns(f) and int(f.source_index)==id:faces.append(f)
  host.get_node("L13Eggs").build(plate,faces)
 restore()
func lit(id:int)->bool:
 if id==84:return not host.get_node("L13Spires").dawn_ready()
 var age:float=float(state().phase)-ORDER.find(id)*SPACING
 return state().started and age>=0 and age<LIFE
func restore():
 for id in plates:
  plates[id].visible=lit(id);plates[id].get_node("Collision").collision_layer=1 if lit(id) else 0
  if host.preview_assemblies.solid_bodies.has(id):host.preview_assemblies.solid_bodies[id].collision_layer=0
func _physics_process(delta):
 if not host.starting_magic.world_active():return
 var s:=state().duplicate(true);var p:Vector3=host.player.position
 if not s.started and p.y>0 and p.x> -3190 and p.x< -3000 and absf(p.z+130)<90:s.started=true
 if s.started:s.phase=fmod(float(s.phase)+delta,PERIOD);host.quest_state[KEY]=s
 restore()
