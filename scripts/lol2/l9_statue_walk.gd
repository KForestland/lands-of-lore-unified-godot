extends Node3D
## Original actor76/path0. One motion owner; movement speed and steering are modern.
const Bowl=preload("res://scripts/lol2/l9_statue_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
var host: Node3D
var population: Node3D
var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/l9_statue_path_source.json"))
var movie_active:=false
var overlay: CanvasLayer
var video: VideoStreamPlayer
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l9_statue_walk.gd").new();node.host=map;node.population=map.act2_creatures;node.name="L9StatueWalk";map.add_child(node);return node
static func initial()->Dictionary:return {"version":1,"marker":0,"arrived":false,"fight_done":false}
static func validate(s: Variant)->String:
 if not s is Dictionary or s.get("version")!=1:return "Invalid walking statue state."
 var n=s.get("marker")
 if not (n is int or n is float) or not is_finite(float(n)) or n!=floorf(n) or n<0 or n>11:return "Invalid statue path marker."
 if not s.get("arrived") is bool or (s.arrived and n!=11):return "Invalid statue arrival."
 if not s.get("fight_done") is bool or (s.fight_done and not s.arrived):return "Invalid statue fight."
 return ""
func state()->Dictionary:return host.quest_state.get("l9_statue_walk",initial())
func enabled()->bool:return Bowl.offered(host.quest_state.get("l9_statue",Bowl.initial()))
func restore():
 # Original offering group12766 clears region3565 with opcode197 arm2.
 # The modern Kit receipt owns this consequence; restore it on the shared physical body.
 var blockers=host.get_node_or_null("RegionBlockers")
 if blockers!=null:blockers.set_region_blocked(3565,not enabled())
func advance(delta: float):
 restore()
 if not enabled() or not population.world_active():return
 var s:=state();var a: Dictionary=population.state.actors["76"]
 if s.fight_done:
  a.present=false;population.bodies["76"].velocity=Vector3.ZERO;population.present();return
 if a.health<=0:return
 if not a.present and not s.arrived:
  Generic.spawn(population.state,"76")
  var p: Array=a.position;population.bodies["76"].position=Vector3(p[0],p[1],p[2])
 a.woken=true;a.rise=Generic.clip_seconds(int(population.src.definitions["5"].clips.rise.frames))
 var body: CharacterBody3D=population.bodies["76"]
 var goal: Array=source.path.points[int(s.marker)].position
 var difference:=Vector2(goal[0]-body.position.x,goal[1]-body.position.z)
 if difference.length()<8:
  if int(s.marker)==11:s.arrived=true
  else:
   s.marker=int(s.marker)+1;goal=source.path.points[int(s.marker)].position
   difference=Vector2(goal[0]-body.position.x,goal[1]-body.position.z)
 var direction:=difference.normalized()
 body.velocity=Vector3(direction.x*40,0 if body.is_on_floor() else body.velocity.y-128*delta,direction.y*40) if not s.arrived else Vector3.ZERO
 if body.velocity.y<=0 and preload("res://scripts/lol2/walk_step.gd").try_step(body,Vector3(body.velocity.x,0,body.velocity.z)*delta):
  body.velocity.x=0;body.velocity.z=0
 body.move_and_slide()
 a.position=[body.position.x,body.position.y,body.position.z]
 population.state.live["76"].merge({"mode":population.Live.PURSUE if not s.arrived else population.Live.IDLE,"heading":population.Live.heading_units(Vector2(direction.x,-direction.y)),"elapsed":0.0,"hit":false,"hits":0},true)
 population.clocks["76"]+=delta
 host.quest_state.l9_statue_walk=s;population.sync_quests();population.present()
 if s.arrived and in_fight_region() and host.player_form==0:begin_fight()
func in_fight_region()->bool:
 var p: Vector3=host.player.position
 for region in source.fight_regions:
  if p.y-32<region.floor[0]-4 or p.y-32>region.floor[1]+4:continue
  var polygon:=PackedVector2Array()
  for v in region.polygon:polygon.append(Vector2(v[0],v[1]))
  if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon):return true
 return false
func begin_fight()->bool:
 if movie_active or state().fight_done or not state().arrived or host.player_form!=0 or not in_fight_region():return false
 var path:="res://assets/lol2/generated/l9_statue_fight/fight.ogv"
 if not FileAccess.file_exists(path):host.save_feedback("The statue fight movie is unavailable.");return false
 movie_active=true;overlay=CanvasLayer.new();overlay.layer=100;overlay.process_mode=Node.PROCESS_MODE_ALWAYS;add_child(overlay)
 var shade:=ColorRect.new();shade.color=Color.BLACK;shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(shade)
 video=VideoStreamPlayer.new();video.expand=true;video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(video)
 var stream:=VideoStreamTheora.new();stream.file=path;video.stream=stream;video.finished.connect(finish_fight)
 get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;video.play();return true
func finish_fight():
 if not movie_active:return
 var s:=state();s.fight_done=true;host.quest_state.l9_statue_walk=s
 # The generic absent-actor save contract uses its original dormant row; the story receipt prevents respawn.
 population.state.actors["76"]=Generic.initial(population.src).actors["76"]
 population.state.live["76"].merge({"mode":population.Live.IDLE,"elapsed":0.0,"hit":false,"hits":0},true)
 population.sync_quests();population.present()
 # Source groups5918/6054/6190/6326 opcode18 return player to(4111,9959), original floor-20.
 host.player.position=Vector3(4111,12,-9959);host.player.velocity=Vector3.ZERO
 movie_active=false;overlay.queue_free();get_tree().paused=false
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;host.save_feedback("Water begins to rise in the ruins.")
