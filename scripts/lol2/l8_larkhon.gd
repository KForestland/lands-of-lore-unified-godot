extends Node3D
const State=preload("res://scripts/lol2/l8_larkhon_state.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const Tribe=preload("res://scripts/lol2/l8_tribe_state.gd")
const Trade=preload("res://scripts/lol2/l8_shaman_trade.gd")
const MyJournal=preload("res://scripts/lol2/my_journal.gd")
const NEAR:=600.0 # Guidance radius around the guardian (modern presentation, DEVIATIONS 0306).
var host:Node3D
var hint:Label
var gate_signature:=""
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l8_larkhon.gd").new();n.host=map;n.name="L8Larkhon";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(State.KEY,State.initial())
## Once the actual dose is used the guardian stays asleep (DEVIATIONS 0307, hintbook: "it still sleeps soundly");
## the saved 60 s clock only drives the falling-asleep frames, then the resting selector holds.
func asleep()->bool:return State.used(state())
## Journal id of the guidance that fits what Luther has earned so far, or "" when nothing is missing.
static func guidance_for(quests:Dictionary,carried:Array)->String:
 var s:Dictionary=quests.get(State.KEY,State.initial())
 if State.used(s) or s.get("active",false):return ""
 if State.mixed(s):return "larkhon_vapors_unactivated"
 if carried.any(func(id):return Items.definition(id)==119):return "larkhon_serum_needs_leaf"
 if Tribe.member(quests.get(Tribe.KEY,{})) and not Trade.completed(quests.get(Trade.KEY,Trade.initial())):return "larkhon_ask_shaman"
 if not Tribe.member(quests.get(Tribe.KEY,{})):return "larkhon_join_tribe"
 return "larkhon_must_sleep"
func guidance()->String:return guidance_for(host.quest_state,host.carried_collected)
func guidance_text()->String:
 var id:=guidance()
 return "" if id.is_empty() else str(MyJournal.hints().get(id,""))
func near()->bool:
 var pop=host.act2_creatures
 if pop==null or not pop.bodies.has("115"):return false
 var d:Vector3=pop.bodies["115"].global_position-host.player.global_position
 return Vector2(d.x,d.z).length()<NEAR
## Records the matching note (once) and returns its line for the caller's feedback.
func note_guidance()->String:
 var id:=guidance()
 if id.is_empty():return ""
 MyJournal.discover(host,id)
 return str(MyJournal.hints().get(id,""))
func _ready():
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,405);canvas.add_child(hint)
 restore()
func inventory_allowed()->bool:return host.player_form==0 and not host.flying and is_instance_valid(host.inventory) and host.starting_magic.health()>0
func can_mix(serum:String)->bool:
 return not State.mixed(state()) and Items.definition(serum)==119 and serum in host.carried_collected and not host.carried_collected.filter(func(id):return Items.definition(id)==117).is_empty()
func mix(serum:String)->bool:
 if not inventory_allowed() or not can_mix(serum):return false
 var leaf:String=host.carried_collected.filter(func(id):return Items.definition(id)==117)[0]
 var result:=State.mix(state(),host.carried_collected,leaf,serum)
 if not result.ok:host.save_feedback(result.reason);return false
 var history:Dictionary=host.quest_state.act2_items.duplicate(true);history.collected.append(State.VAPORS)
 host.quest_state.act2_items=history;host.carried_collected=result.inventory;host.quest_state[State.KEY]=result.state
 if host.hand_item in [leaf,serum]:host.hand_item=""
 Items.sync(host);host.save_feedback("You mix Silverleaf with Amaranth Serum to make Larkhon Vapors.");return true
func activate(item:String)->bool:
 if item!=State.VAPORS or not inventory_allowed() or item not in host.carried_collected or not State.mixed(state()) or State.used(state()) or state().active:return false
 var s:=state().duplicate(true);s.active=true;host.quest_state[State.KEY]=s
 host.save_feedback("The vapors are active. Aim at the Larkhon's upper chest and use the right mouse button.");return true
func aim()->Vector3:
 var pop=host.act2_creatures
 return pop.bodies["115"].position+Vector3.UP*float(pop.config.look["7"].height)*0.65
func reachable()->bool:
 var pop=host.act2_creatures
 if not pop.state.actors["115"].present or pop.state.actors["115"].health<=0:return false
 var delta:Vector3=aim()-host.camera.global_position
 if delta.length()>180 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.97:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,aim(),1,[host.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func offer(item:String)->Dictionary:
 if host.player_form!=0 or not host.starting_magic.world_active() or not reachable():return State.Kit.refuse("Aim the activated vapors at the Larkhon's upper chest.")
 var result:=State.apply(state(),host.carried_collected,item)
 if not result.ok:return result
 host.carried_collected=result.inventory;host.quest_state[State.KEY]=result.state
 if host.hand_item==item:host.hand_item=""
 Items.sync(host);restore()
 return {"ok":true,"reason":"The Larkhon falls asleep. The cave entrance is clear."}
func restore():
 var signature:="%s:%s"%[State.used(state()),asleep()]
 if gate_signature!=signature:
  gate_signature=signature
  var blockers=host.get_node_or_null("RegionBlockers")
  if blockers!=null:
   for id in [3277,3278]:blockers.set_region_blocked(id,not State.used(state()))
   # The later blocking set3455..3457 is never re-armed after the dose (DEVIATIONS 0307: no expiry softlock).
   for id in [3455,3456,3457]:blockers.set_region_blocked(id,false)
 apply_pose()
func apply_pose():
 if not asleep() or host.act2_creatures==null:return
 var pop=host.act2_creatures
 var elapsed:float=State.SLEEP-float(state().sleep)
 var selector:=9 if elapsed<17.0/pop.State.FPS else 8
 var frame:=mini(16,int(elapsed*pop.State.FPS)) if selector==9 else 0
 pop.library.present(pop.materials["115"],7,selector,frame,pop._view("115",pop.library.view_count(7,selector)))
 pop.bodies["115"].collision_layer=0
func _process(delta):
 if float(state().sleep)>0 and host.starting_magic.world_active():
  var s:=state().duplicate(true);s.sleep=maxf(0,float(s.sleep)-delta);host.quest_state[State.KEY]=s
 restore()
 hint.text=""
 if not host.starting_magic.world_active():return
 if state().active:hint.text="Right click — Apply activated vapors to the Larkhon's upper chest"
 elif near() and not guidance().is_empty():
  MyJournal.discover(host,guidance())
  hint.text=guidance_text()
func _unhandled_input(event:InputEvent):
 if event is not InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_RIGHT:return
 if not state().active or not host.starting_magic.world_active():return
 var result:=offer(State.VAPORS);host.save_feedback(result.reason);get_viewport().set_input_as_handled()
