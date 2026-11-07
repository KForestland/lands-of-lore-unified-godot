extends Node3D
const KEY="l14_hopper_platform"
const IDS=["91","92","93","94","95"]
const POINT=Vector3(41,310,5919)
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const Actors=preload("res://scripts/lol2/scripted_creature_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const FLOORS=[2421,2420,2419,2422,2449,2452,2451,2450,2457,2456,2455,2454,2416,2415,2414,2417,2447]
var host:Node3D
var floors:Dictionary={}
var corpses:Dictionary={}
var hint:Label
static func item(id:String)->String:return "act2:L14_HT:hopper_corpse"+id
static func initial()->Dictionary:return {"version":1,"activated":false,"collected":[],"slots":{},"stepped":false,"lowered":0.0}
static func complete(s:Dictionary)->bool:
 for id in IDS:
  if not Kit.slot(s,id).committed:return false
 return true
static func recipe(id:String)->Dictionary:return {"target":id,"accepts":[item(id)],"output":"{item}","retrievable":false,"repeatable":false,"forms":["human"]}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=6 or s.get("version")!=1 or not s.get("activated") is bool or not s.get("collected") is Array or not s.get("slots") is Dictionary or not s.get("stepped") is bool:return "Invalid hopper platform."
 if not preload("res://scripts/lol2/walkthrough_save.gd")._number(s.get("lowered")) or not is_finite(s.lowered) or s.lowered<0 or s.lowered>4:return "Invalid hopper lift motion."
 if not s.activated:return "" if s==initial() else "Hopper puzzle changed before activation."
 if quests.get("l14_idol_pedestals",{}).get("assembled",0)!=4:return "Hopper encounter lacks idol crossing."
 var seen:Array=[]
 for id in s.collected:
  if id not in IDS or id in seen or quests.get("act2_creatures_L14_HT",{}).get("actors",{}).get(id,{}).get("health",-1)!=0 or item(id) not in quests.get("act2_items",{}).get("collected",[]):return "Corpse lacks unique real defeat and pickup."
  seen.append(id)
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid corpse transaction."
 for id in s.slots:
  var slot:=Kit.slot(s,id)
  if id not in seen or slot.occupied!=item(id) or not slot.committed or slot.receipts!=[id]:return "Invalid platform corpse receipt."
 if s.stepped and not complete(s):return "Platform lacks five bodies."
 if s.lowered>0 and not s.stepped:return "Platform lacks player weight."
 return ""
static func return_initial()->Dictionary:return {"version":1,"started":false,"raised":0.0}
static func validate_return(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("started") is bool:return "Invalid weighted platform return."
 if not preload("res://scripts/lol2/walkthrough_save.gd")._number(s.get("raised")) or not is_finite(s.raised) or s.raised<0 or s.raised>4:return "Invalid return motion."
 if not s.started:return "" if s==return_initial() else "Return lacks activation."
 if quests.get(KEY,{}).get("lowered",0)!=4 or not complete(quests.get(KEY,initial())):return "Return lacks weighted descent."
 return ""
func return_state()->Dictionary:return host.quest_state.get("l14_hopper_return",return_initial())
func return_point()->Vector3:return POINT+Vector3.DOWN*370*(float(state().lowered)-float(return_state().raised))/4
func return_to_gallery()->Dictionary:
 if state().lowered!=4 or return_state().started or not reach(return_point()):return Kit.refuse("Approach the lowered platform's return control.")
 var s:=return_initial();s.started=true;host.quest_state.l14_hopper_return=s;return {"ok":true,"reason":"The weighted platform rises back to the gallery."}
static func owns(f:Dictionary)->bool:return f.get("kind")=="floor" and int(f.get("region",-1)) in FLOORS
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_hopper_platform.gd").new();n.host=map;n.name="L14HopperPlatform";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for id in FLOORS:
  var n:=Node3D.new();n.name="OriginalWeightFloor"+str(id);add_child(n);floors[id]=n
  var faces:Array=[]
  for f in pack.faces:
   if f.get("kind")=="floor" and int(f.get("region",-1))==id:faces.append(f)
  assert(not faces.is_empty(),"Missing original weight floor")
  host.get_node("L14Niche").build(n,faces)
 for i in IDS.size():
  var sprite:=Sprite3D.new();sprite.texture=ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/l14_hopper_platform/corpse.png"));sprite.pixel_size=0.4;sprite.position=Vector3(12+(i%2)*55,306,5860+i*26);sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;add_child(sprite);corpses[IDS[i]]=sprite
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func active()->bool:return host.player_form==0 and not host.flying and host.starting_magic.world_active()
func reach(point:Vector3)->bool:
 if not active():return false
 var d:Vector3=point-host.camera.global_position
 if d.length()<0.01 or d.length()>145 or (-host.camera.global_basis.z).dot(d.normalized())<0.86:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,point,1,[host.player.get_rid()]);var hit:Dictionary=host.get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.is_empty() or hit.position.distance_to(point)<18
func take(id:String,capacity:int=64)->Dictionary:
 var pop=host.act2_creatures
 if id not in IDS or not state().activated or pop.state.actors[id].health>0 or id in state().collected:return Kit.refuse("That is not an uncollected hopper corpse.")
 if not reach(pop.bodies[id].global_position+Vector3.UP*8):return Kit.refuse("Approach the fallen hopper.")
 if host.carried_collected.size()>=capacity:return Kit.refuse("Make room for the corpse.")
 var s:=state().duplicate(true);s.collected.append(id);host.quest_state[KEY]=s;host.carried_collected.append(item(id))
 var inventory:Dictionary=host.quest_state.get("act2_items",Items.initial()).duplicate(true);inventory.collected.append(item(id));host.quest_state.act2_items=inventory;Items.sync(host);restore()
 return {"ok":true,"reason":"You carry the hopper corpse."}
func place(body_item:String,capacity:int=64)->Dictionary:
 if not reach(POINT):return Kit.refuse("Approach the wooden platform from its side.")
 var id:String=body_item.trim_prefix("act2:L14_HT:hopper_corpse")
 if id not in state().collected:return Kit.refuse("The platform needs a defeated hopper's body.")
 if host.carried_collected.size()>=capacity:return Kit.refuse("Make room before setting the body down.")
 var s:=state().duplicate(true);var snap:=Kit.empty_snapshot(host.carried_collected,capacity);snap.slots=s.slots
 var result:=Kit.offer(snap,recipe(id),body_item,{"form":"human"})
 if not result.ok:return result
 result=Kit.occupy(snap,result.proposal)
 if not result.ok:return result
 result=Kit.commit(result.snapshot,recipe(id),id)
 if not result.ok:return result
 s.slots=result.snapshot.slots;host.quest_state[KEY]=s;host.carried_collected=result.snapshot.inventory
 if host.hand_item==body_item:host.hand_item=""
 Items.sync(host);restore();return {"ok":true,"reason":"Five bodies weigh down the platform. Step aboard." if complete(s) else "The body rests on the platform."}
func restore():
 var f:float=(float(state().lowered)-float(return_state().raised))/4
 for id in floors:floors[id].position.y=(-370 if id==2447 else 200)*f
 for id in corpses:
  corpses[id].visible=Kit.slot(state(),id).committed;corpses[id].position.y=306-370*f
 if host.act2_creatures!=null:
  for id in IDS:host.act2_creatures.meshes[id].visible=id not in state().collected
func advance_creatures(delta:float):
 if not state().activated or not host.starting_magic.world_active():return
 var pop=host.act2_creatures;var changed:=false
 for id in IDS:
  if not pop.state.actors[id].present:continue
  var body:CharacterBody3D=pop.bodies[id]
  if pop.state.actors[id].health<=0:
   if id not in state().collected:
    body.velocity=Vector3(0,-80,0);body.move_and_slide()
    pop.state.actors[id].position=Live.saved_position(body.position-pop.origin());changed=true
   continue
  var direction:Vector3=host.player.global_position-body.global_position;direction.y=0
  var horizontal:Vector3=direction.normalized()*Actors.SPEED if pop.state.live[id].mode==Live.PURSUE and not pop.moving[id] else Vector3.ZERO
  body.velocity=Vector3(horizontal.x,clampf((340-body.position.y)/maxf(delta,0.001),-80,80),horizontal.z);body.move_and_slide()
  pop.state.actors[id].position=Live.saved_position(body.position-pop.origin());changed=true
 if changed:pop.sync_quests();pop.present()
func _physics_process(delta):
 if host.act2_creatures!=null and host.starting_magic.world_active():
  var s:=state().duplicate(true);var p:Vector3=host.player.position
  if not s.activated and host.quest_state.get("l14_idol_pedestals",{}).get("assembled",0)==4 and p.z>=6040 and p.z<=6800 and p.y-32>=290 and p.y-32<=350:
   s.activated=true
   for id in IDS:Actors.spawn(host.act2_creatures.state,id);Actors.wake(host.act2_creatures.state,id)
   host.act2_creatures.sync_quests();host.act2_creatures.present();host.save_feedback("Five hoppers stir beyond the gallery.")
  if complete(s) and host.player_form==0 and host.player.is_on_floor() and p.x>=-35 and p.x<=115 and p.z>=5814 and p.z<=6026 and absf(p.y-32-(300-370*float(s.lowered)/4))<5:s.stepped=true
  if s.stepped:s.lowered=minf(4,s.lowered+delta)
  if s.activated:host.quest_state[KEY]=s
  if return_state().started and return_state().raised<4:
   var back:=return_state().duplicate(true);back.raised=minf(4,back.raised+delta);host.quest_state.l14_hopper_return=back
 restore()
func _process(_delta):
 hint.text=""
 if state().lowered==4 and not return_state().started and reach(return_point()):hint.text="E — Raise platform to gallery";return
 if host.act2_creatures!=null:
  for id in IDS:
   if host.act2_creatures.state.actors[id].health==0 and id not in state().collected and reach(host.act2_creatures.bodies[id].global_position+Vector3.UP*8):hint.text="E — Carry hopper corpse";return
 if reach(POINT) and not complete(state()):hint.text="E — Place hopper corpse on platform"
func _unhandled_key_input(event:InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 if state().lowered==4 and not return_state().started and reach(return_point()):host.save_feedback(return_to_gallery().reason);get_viewport().set_input_as_handled();return
 for id in IDS:
  if host.act2_creatures.state.actors[id].health==0 and id not in state().collected and reach(host.act2_creatures.bodies[id].global_position+Vector3.UP*8):host.save_feedback(take(id).reason);get_viewport().set_input_as_handled();return
 if reach(POINT):
  var candidate:String=host.hand_item
  if candidate.is_empty():
   for id in IDS:
    if item(id) in host.carried_collected:candidate=item(id);break
  host.save_feedback(place(candidate).reason);get_viewport().set_input_as_handled()
