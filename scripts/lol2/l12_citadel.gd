extends Node3D
const Grants=preload("res://scripts/lol2/item_grants.gd")
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
 Grants.grant(host,State.PICTURE,{"cap":false,"duplicate":"allow","history":"act2","sync":true})
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
 var admission:=Grants.transition(host,result.inventory,{State.KEY:result.state},{"history":"act2","history_id":State.CHARM})
 if not admission.ok:return admission
 if host.hand_item==State.PICTURE:host.hand_item=""
 Items.sync(host)
 return {"ok":true,"reason":"The picture breaks. You recover Kenneth's charm from the frame."}
func talk()->bool:
 if not active() or state().talked or not state().baccata_seen or not host.act2_creatures.state.actors["30"].present or host.act2_creatures.state.actors["30"].health<=0 or not reachable(BACCATA+Vector3.UP*50):return false
 var s:=state().duplicate(true);s.talked=true;host.quest_state[State.KEY]=s
 # Lead 2026-11-15: after the Citadel the line points home, not back at the citadel.
 host.save_feedback("You listen to Baccata's account. The Dreamstone must go back to the Huline Temple." if preload("res://scripts/lol2/l13_journal_hints.gd").carrying_dreamstone(host) else "You listen to Baccata's account before continuing toward the citadel.")
 return true
## Owner F10 06-47-40 ("ruloi entrance do not work"): the corridor first shows the Citadel about 900 units from the deck,
## where the passage control 74 is (the original triggers group 2808 only from that control; no region entry does). While the
## deck is ahead and out of reach, a hint line says where the way in is (presentation adapter, ledger 0636).
const ENTRANCE_HINT := "The Citadel lies ahead. The way in is on the deck."
func entrance_ahead()->bool:
 var delta:Vector3=entrance_aim()-host.camera.global_position
 var flat:=Vector3(delta.x,0,delta.z)
 if flat.length()<=preload("res://scripts/lol2/act2_progression.gd").REACH or flat.length()>1000.0:return false
 # Once control 74 can be aimed the normal E prompt takes over.
 if host.get("progression")!=null and host.progression.aimed_exit()=="control:74":return false
 var look:Vector3=-host.camera.global_basis.z;look.y=0
 return look.length()>0.01 and look.normalized().dot(flat.normalized())>0.9
func entrance_aim()->Vector3:return Vector3(3684,-1240,-19361) # Original deck top -1251 plus11; modern aim point.
func begin_entry(change:Dictionary)->void:
 # Native control74/group2808 carries no Baccata predicate (BJ05 2026-11-08): his account is optional, so a player who never
 # cut him down in L8 (he then never stands here) is not held at the gate.
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
## Way back with the Dreamstone (lead 2026-11-15, DEVIATIONS row 0671). The tunnel from the Citadel ends on ice openings
## over the river (floor -950); the original way on is a jump onto a passing ice floe (l12_river_rafts.gd), then the bank,
## an ice bridge, the glacier logs and the gulch. Beside it, while the stone is carried and the Savage Jungle temple door
## does not hold it, E climbs down to the bottom of the icy gulch (gulch path region 1333, about 1000 west of the jungle
## exit), facing the exit. Adapter; the floe route is unchanged.
const OPENINGS:=[Vector2(2420,-15710),Vector2(2764,-14866)]
const OPENING_FLOOR:=-950.0
const GULCH_LANDING:=Vector3(-1066,32,-5587)
const OPENING_LINE:="The way on is down: jump onto an ice floe on the river, or E — Climb down to the icy gulch"
## Owner F10 2026-11-16T16-27-05: the line showed about 1 s (on the opening floor only, under 220). It now holds while he
## is within reach: up to 300 from an opening and between 15 below and 60 above its floor (a hop or a step off the edge).
func at_opening()->bool:
 var rise:float=host.player.position.y-32-OPENING_FLOOR
 if not active() or rise< -15 or rise>60:return false
 if not preload("res://scripts/lol2/l13_journal_hints.gd").dreamstone_home_open(host):return false
 var at:=Vector2(host.player.position.x,host.player.position.z)
 for spot:Vector2 in OPENINGS:
  if at.distance_to(spot)<300:return true
 return false
func climb_down()->bool:
 if not at_opening():return false
 host.player.position=GULCH_LANDING;host.player.velocity=Vector3.ZERO;host.player.rotation.y=-PI/2;host.camera.rotation=Vector3.ZERO
 if host.has_method("reset_position"):
  host.set("tracked_region",-1);host.set("tracker_last",Vector3.INF)
 host.player.force_update_transform()
 host.save_feedback("You climb down the ice to the bottom of the gulch. The way to the jungle lies east.")
 return true
func _process(_delta):
 if active() and not state().baccata_seen and host.player.position.distance_to(BACCATA)<300 and host.quest_state.get("l8_baccata",{}).get("phase",0)==3:
  var s:=state().duplicate(true);s.baccata_seen=true;host.quest_state[State.KEY]=s
  host.act2_creatures.state.actors["30"].present=true;host.act2_creatures.sync_quests();host.act2_creatures.present()
 hint.text=""
 if not active():return
 if state().armed:hint.text="Right click — Throw picture at the ground"
 elif not state().searched and reachable(BODY+Vector3.UP*12):hint.text="E — Search Kenneth"
 elif state().baccata_seen and not state().talked and reachable(BACCATA+Vector3.UP*50):hint.text="E — Speak with Baccata"
 elif not state().movie_seen and entrance_ahead():hint.text=ENTRANCE_HINT
 elif at_opening():hint.text=OPENING_LINE
func _unhandled_input(event:InputEvent):
 if not active():return
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and state().armed:
  var result:=throw_picture(State.PICTURE);host.save_feedback(result.reason);get_viewport().set_input_as_handled()
 elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
  if not state().searched and reachable(BODY+Vector3.UP*12):host.save_feedback(search_body().reason);get_viewport().set_input_as_handled()
  elif talk():get_viewport().set_input_as_handled()
  elif climb_down():get_viewport().set_input_as_handled()
