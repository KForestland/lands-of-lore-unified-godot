extends SceneTree
## Exact codec/geometry component. Native group/physics holds are explicit aids.
const World=preload("res://scripts/lol2/act2_world_checkpoint.gd")
func _initialize():run.call_deferred()
func run():
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();root.add_child(scene);current_scene=scene
 for i in 1800:
  await process_frame
  if scene.ready_for_review:break
 scene.set_physics_process(false);scene.progression.set_physics_process(false);scene.act2_creatures.set_physics_process(false)
 var progression:Node=scene.progression;var original:=World.snapshot(progression)
 var packet:Dictionary={"version":1,"floors":{"version":1,"clock":0.375,"motions":{"1893":{"height":59,"remaining":71,"fraction":32768,"speed":5}}}}
 packet.movers=original.movers.duplicate(true)
 var routes:int=progression.route_log.size();var changes:int=progression.level_changes.size()
 assert(World.restore(progression,packet).is_empty(),"Native floor checkpoint restores through shared code")
 var actual:=World.snapshot(progression)
 assert(JSON.parse_string(JSON.stringify(actual))==JSON.parse_string(JSON.stringify(packet)),"Exact mid-motion height/remainder/fraction/rate/clock restored before any tick")
 assert(int(progression.regions[1893][1])==59 and progression.floor_decks.has(1893),"Actual navigation/deck geometry projects checkpoint height")
 assert(progression.route_log.size()==routes and progression.level_changes.size()==changes,"No use, entry, enqueue or level event re-fired")
 for kind in ["region","fraction","rate","rate_byte","stopped","clock","clock_fraction","height","schema"]:
  var bad:Dictionary=packet.duplicate(true)
  match kind:
   "region":bad.floors.motions["65535"]=bad.floors.motions["1893"]
   "fraction":bad.floors.motions["1893"].fraction=65536
   "rate":bad.floors.motions["1893"].speed=-1
   "rate_byte":bad.floors.motions["1893"].speed=256
   "stopped":bad.floors.motions["1893"].speed=0
   "clock":bad.floors.clock=INF
   "clock_fraction":bad.floors.clock=1.0
   "height":bad.floors.motions["1893"].height=32768
   "schema":bad.extra=0
  assert(not World.restore(progression,bad).is_empty() and World.snapshot(progression)==actual,"Invalid checkpoint refuses before mutation: "+kind)
 var mover:String=actual.movers.keys()[0]
 for kind in ["position","scale","orientation","nan","shape","identity"]:
  var bad:Dictionary=actual.duplicate(true)
  match kind:
   "position":bad.movers[mover][9]+=1000000
   "scale":bad.movers[mover][0]=2.0
   "orientation":bad.movers[mover]=World.encode(Transform3D(Basis(Vector3.RIGHT,0.5),World.decode(bad.movers[mover]).origin))
   "nan":bad.movers[mover][10]=NAN
   "shape":bad.movers[mover].append(0)
   "identity":bad.movers["65535"]=bad.movers[mover]
  assert(not World.restore(progression,bad).is_empty() and World.snapshot(progression)==actual,"Invalid moving pose refuses before floor/body mutation: "+kind)
 assert(World.restore(progression,original).is_empty() and progression.floor_motion.is_empty(),"Reverse load removes all later floor motion")
 scene.free();await process_frame
 print("PASS G04 exact floor continuation/physical deck, fifteen malformed floor/pose refusals atomic, reverse load and zero replay")
 quit()
