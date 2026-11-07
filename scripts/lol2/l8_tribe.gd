extends Node3D
## Original offer speech/arena placement, modern saved nonlethal bout.
const State=preload("res://scripts/lol2/l8_tribe_state.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const ROOT:="res://assets/lol2/generated/l8_initiation/"
var host:Node3D
var voice:AudioStreamPlayer
var clips:Array=[]
var loaded:=-1
var hint:Label
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l8_tribe.gd").new();n.host=map;n.name="L8Tribe";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(State.KEY,State.initial())
func input_locked()->bool:return state().phase=="intro"
func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS
 clips=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json")).clips
 voice=AudioStreamPlayer.new();add_child(voice)
 var canvas:=CanvasLayer.new();canvas.layer=36;add_child(canvas);hint=Label.new();hint.position=Vector2(24,410);canvas.add_child(hint)
func offer(item:String)->Dictionary:
 if get_tree().paused or host.flying or host.player_form!=0 or not host.starting_magic.world_active() or host.get_node("L8Journey").target()!="village":return State.Kit.refuse("Offer the Silverleaf at the Wild Village as Human.")
 if not host.quest_state.get("l8_journey",{}).get("admitted",false) or not host.quest_state.get("l10_silverleaf",{}).get("grown",false):return State.Kit.refuse("Bring Silverleaf from the cemetery after meeting the shaman.")
 var result:=State.offer(state(),host.carried_collected,item)
 if not result.ok:return result
 host.quest_state[State.KEY]=result.state;host.carried_collected=result.inventory;Items.sync(host)
 return {"ok":true,"reason":"The shaman accepts the Silverleaf and prepares your initiation."}
func play_current():
 if not input_locked():voice.stop();loaded=-1;return
 var index:int=state().index
 if loaded!=index:
  voice.stream=AudioStreamWAV.load_from_file(ROOT+clips[index].wav);loaded=index;voice.play(state().elapsed)
 elif absf(voice.get_playback_position()-float(state().elapsed))>0.5:voice.play(state().elapsed)
 voice.pitch_scale=Engine.time_scale
 voice.stream_paused=not host.starting_magic.movie_world_active()
func next_line():
 if not input_locked():return
 var s:=state().duplicate(true);s.index+=1;s.elapsed=0.0
 if s.index==clips.size():
  s.index=0;s.phase="fight"
  # Source SHAMAN callback place(2679,4187), hostF0(45); source floor is0.
  # This occurs only after the earned offering and speech, never during load.
  host.player.position=Vector3(2679,32,-4187);host.player.velocity=Vector3.ZERO;host.player.rotation.y=deg_to_rad(-45.0);host.camera.rotation.x=0;host.player.reset_physics_interpolation()
  var pop=host.act2_creatures
  pop.State.spawn(pop.state,"23");pop.State.wake(pop.state,"23",true);pop.sync_quests();pop.present()
 host.quest_state[State.KEY]=s;play_current()
func finish(s:Dictionary):
 s.phase="complete";s.counter=0.0;host.quest_state[State.KEY]=s
 host.save_feedback("The initiation ends without a death. You are accepted into the tribe.")
func receive_strike(amount:int,melee:bool)->bool:
 if state().phase!="fight" or not melee or amount<=0 or not host.starting_magic.world_active() or host.player_form!=0:return false
 if host.act2_creatures.aimed()!="23":return false
 var s:=state().duplicate(true);s.daniel=maxi(0,int(s.daniel)-amount)
 if s.daniel==0:finish(s)
 else:host.quest_state[State.KEY]=s
 return true
func yield_bout()->bool:
 if state().phase!="fight" or not host.starting_magic.world_active():return false
 var s:=state().duplicate(true)
 if s.player==State.PLAYER_STAMINA and s.daniel==State.DANIEL_STAMINA:return false
 s.player=0;finish(s);return true
func _physics_process(delta):
 if state().phase!="fight" or not host.starting_magic.world_active():return
 var pop=host.act2_creatures;var body:CharacterBody3D=pop.bodies["23"]
 var direction:Vector3=host.player.position-body.position;direction.y=0
 var distance:=direction.length()
 var ray:=PhysicsRayQueryParameters3D.create(body.position+Vector3.UP*40,host.player.position+Vector3.UP*8,1,[body.get_rid(),host.player.get_rid()])
 var sight:bool=host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
 body.velocity=direction.normalized()*40 if distance>65 and distance<400 and sight else Vector3.ZERO
 body.velocity.y=-32;body.move_and_slide()
 pop.state.actors["23"].position=pop.Live.saved_position(body.position);pop.moving["23"]=Vector2(body.velocity.x,body.velocity.z).length()>1;pop.sync_quests();pop.present()
 var s:=state().duplicate(true)
 if distance<100 and sight:
  s.counter+=delta
  if s.counter>=1.2:s.counter=0.0;s.player=maxi(0,int(s.player)-8)
 else:s.counter=0.0
 if s.player==0:finish(s)
 else:host.quest_state[State.KEY]=s
func _process(delta):
 hint.text=""
 if input_locked():
  play_current();hint.text="The shaman speaks. Enter — skip this line"
  if not host.starting_magic.movie_world_active():return
  var s:=state().duplicate(true);s.elapsed+=delta
  if s.elapsed>=float(clips[int(s.index)].duration):next_line()
  else:host.quest_state[State.KEY]=s
 elif state().phase=="fight":hint.text="Initiation stamina — You %d   Daniel %d   Left click — spar   E — yield"%[state().player,state().daniel]
 elif state().phase=="complete":hint.text="E — Return to the village"
 elif loaded!=-1:play_current()
func _unhandled_input(event:InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo:return
 if input_locked() and event.keycode==KEY_ENTER and host.starting_magic.movie_world_active():next_line();get_viewport().set_input_as_handled()
 elif event.keycode==KEY_E and state().phase=="fight" and yield_bout():get_viewport().set_input_as_handled()
 elif event.keycode==KEY_E and state().phase=="complete" and leave_arena():get_viewport().set_input_as_handled()

func offer_shaman(item:String)->Dictionary:
 var Trade=preload("res://scripts/lol2/l8_shaman_trade.gd")
 if not host.starting_magic.world_active() or host.player_form!=0 or host.get_node("L8Journey").target()!="village" or not State.member(state()):return State.Kit.refuse("Return to the shaman after your initiation.")
 var result:Dictionary=Trade.exchange(host.quest_state.get(Trade.KEY,Trade.initial()),host.carried_collected,item)
 if not result.ok:return result
 var history:Dictionary=host.quest_state.act2_items.duplicate(true);history.collected.append(Trade.SERUM)
 host.carried_collected=result.inventory;host.quest_state[Trade.KEY]=result.state;host.quest_state.act2_items=history;Items.sync(host)
 return {"ok":true,"reason":"The shaman accepts another Silverleaf and gives you Amaranth Serum. Keep it for the journey ahead."}

func leave_arena()->bool:
 if state().phase!="complete" or not host.starting_magic.world_active() or host.player_form!=0:return false
 var point:Vector3=host.act2_creatures.bodies["23"].position+Vector3.UP*45
 var direction:Vector3=point-host.camera.global_position
 if direction.length()>180 or direction.length()<0.01 or (-host.camera.global_basis.z).dot(direction.normalized())<0.8:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,point,1,[host.player.get_rid()])
 if not host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return false
 var s:=state().duplicate(true);s.phase="departed";host.quest_state[State.KEY]=s
 # Collapse the unhosted settlement views to original SETTLE1 world exit531/4414.
 host.player.position=Vector3(531,32,-4414);host.player.velocity=Vector3.ZERO;host.player.rotation.y=deg_to_rad(90.0);host.camera.rotation.x=0;host.player.reset_physics_interpolation()
 host.save_feedback("You return to the Wild Village after your initiation.")
 return true
