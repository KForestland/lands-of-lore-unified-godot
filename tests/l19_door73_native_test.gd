extends SceneTree
const Actions=preload("res://scripts/lol2/generic_object_actions.gd")
const Native=preload("res://scripts/lol2/native_script_host.gd")
func _initialize():
 var regions:Array=[];regions.resize(134)
 for id in [103,100,133]:regions[id]=[[],-45,-45,[]]
 if not Actions.floors_raised(regions,{103:-45,100:-45,133:-45}):push_error("All three raised floors admit guide door");quit(1);return
 for id in [103,100,133]:
  regions[id][1]=-95
  if Actions.floors_raised(regions,{103:-45,100:-45,133:-45}):push_error("Any one low floor must refuse");quit(1);return
  regions[id][1]=-45
 var native=Native.new()
 if not native.load_area("res://scripts/lol2/native_scripts/L19_BC.json").is_empty():quit(1);return
 var sounds:=[]
 native.sound_request.connect(func(id):sounds.append(id))
 var result:Dictionary=native.execute_group(1,3264)
 print("DOOR73 group3264 ",JSON.stringify(result)," sounds=",sounds," travel=",native.field("movable:73",native.FIELD_TRAVEL,0))
 if result.status!="ran" or native.field("movable:73",native.FIELD_TRAVEL,0)!=0:push_error("Expected original3264 to mark/sound, without claiming it moves73");quit(1);return
 var opened:Array=native.fire_event("movable:73",6,{"caller_byte":2,"context":"movable:73"})
 print("DOOR73 native caller2 ",JSON.stringify(opened)," travel=",native.field("movable:73",native.FIELD_TRAVEL,0))
 if native.field("movable:73",native.FIELD_TRAVEL,0)<=0:push_error("Existing source door callback must open native73");quit(1);return
 print("PASS native source counterexample: group3264 only mark/sound, native73caller2->5858 supplies actual opening; no player input claim")
 quit()
