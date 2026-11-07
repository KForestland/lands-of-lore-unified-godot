extends Node3D
const State=preload("res://scripts/lol2/l12_citadel_state.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const BODY=Vector3(4599,-590,-14076)
const BACCATA=Vector3(2858,-1230,-18172)
var host:Node3D
var hint:Label
var pending:Dictionary={}
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l12_citadel.gd").new();n.host=map;n.name="L12Citadel";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(State.KEY,State.initial())
func _ready():
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint)
func reachable(point:Vector3)->bool:
 var delta:Vector3=point-host.camera.global_position
 if delta.length()>170 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.85:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,point,1,[host.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func active()->bool:return host.player_form==0 and host.starting_magic.world_active()
func search_body()->Dictionary:
 if not active() or not reachable(BODY+Vector3.UP*12):return State.Kit.refuse("Approach Kenneth's body.")
 if state().searched:return State.Kit.refuse("You have already searched Kenneth.")
 if host.carried_collected.size()>=64:return State.Kit.refuse("Your inventory is full.")
 var s:=state().duplicate(true);s.searched=true;host.quest_state[State.KEY]=s
 host.carried_collected.append(State.PICTURE);host.quest_state.act2_items.collected.append(State.PICTURE);Items.sync(host)
 return {"ok":true,"reason":"You find a picture among Kenneth's belongings."}
func arm(item:String)->bool:
 if item!=State.PICTURE or not state().searched or State.broken(state()) or item not in host.carried_collected or host.player_form!=0 or not is_instance_valid(host.inventory):return false
 var s:=state().duplicate(true);s.armed=true;host.quest_state[State.KEY]=s
 host.save_feedback("Aim at nearby ground and right-click to throw the picture.");return true
func ground_hit()->Dictionary:
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,host.camera.global_position-host.camera.global_basis.z*170,1,[host.player.get_rid()])
 var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
 if hit.is_empty() or hit.normal.y<0.6:return {}
 return hit
func throw_picture(item:String)->Dictionary:
 if not active() or ground_hit().is_empty():return State.Kit.refuse("Aim at nearby ground.")
 var result:=State.impact(state(),host.carried_collected,item)
 if not result.ok:return result
 host.quest_state[State.KEY]=result.state;host.carried_collected=result.inventory;host.quest_state.act2_items.collected.append(State.CHARM)
 if host.hand_item==State.PICTURE:host.hand_item=""
 Items.sync(host)
 return {"ok":true,"reason":"The picture breaks. You recover Kenneth's charm from the frame."}
func talk()->bool:
 if not active() or state().talked or not state().baccata_seen or not host.act2_creatures.state.actors["30"].present or host.act2_creatures.state.actors["30"].health<=0 or not reachable(BACCATA+Vector3.UP*50):return false
 var s:=state().duplicate(true);s.talked=true;host.quest_state[State.KEY]=s
 host.save_feedback("You listen to Baccata's account before continuing toward the citadel.")
 return true
func entrance_aim()->Vector3:return Vector3(3684,-1240,-19361) # Original deck top -1251 plus11; modern aim point.
func begin_entry(change:Dictionary)->void:
 if not state().talked:host.save_feedback("Speak with Baccata before entering the citadel.");return
 if not pending.is_empty():return
 var Movie=preload("res://scripts/lol2/l12_citadel_movie.gd")
 if not Movie.assets_ready():host.save_feedback("The citadel entrance movie is not installed.");return
 pending=change.duplicate(true)
 var overlay=Movie.new();host.video_overlay=overlay
 overlay.ended.connect(func(_reason:String):
  host.video_overlay=null
  var s:=state().duplicate(true);s.movie_seen=true;host.quest_state[State.KEY]=s
  host.progression.call_deferred("_change_level",pending))
 host.add_child(overlay)
func _process(_delta):
 if active() and not state().baccata_seen and host.player.position.distance_to(BACCATA)<300 and host.quest_state.get("l8_baccata",{}).get("phase",0)==3:
  var s:=state().duplicate(true);s.baccata_seen=true;host.quest_state[State.KEY]=s
  host.act2_creatures.state.actors["30"].present=true;host.act2_creatures.sync_quests();host.act2_creatures.present()
 hint.text=""
 if not active():return
 if state().armed:hint.text="Right click — Throw picture at the ground"
 elif not state().searched and reachable(BODY+Vector3.UP*12):hint.text="E — Search Kenneth"
 elif state().baccata_seen and not state().talked and reachable(BACCATA+Vector3.UP*50):hint.text="E — Speak with Baccata"
func _unhandled_input(event:InputEvent):
 if not active():return
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and state().armed:
  var result:=throw_picture(State.PICTURE);host.save_feedback(result.reason);get_viewport().set_input_as_handled()
 elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
  if not state().searched and reachable(BODY+Vector3.UP*12):host.save_feedback(search_body().reason);get_viewport().set_input_as_handled()
  elif talk():get_viewport().set_input_as_handled()
