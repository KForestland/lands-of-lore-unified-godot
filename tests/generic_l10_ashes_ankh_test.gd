extends "res://tests/generic_l10_blue_priest_test.gd"
const PRIEST_INPUT:="res://tmp/generic_l10_inputs/generic_l10_priest.json"
const PRIEST_PIN:="3fb4c360a3af123be3682cfab7ce3fcb1a80af02b0dec3cf0d60a92717aa4267"
func proof_picture(tag:String)->bool:
 # Let presentation owners publish the preceding real-input state before capture.
 await frames(2)
 var ray:=PhysicsRayQueryParameters3D.create(pos()+Vector3.UP*0.05,pos()-Vector3.UP*96,1|256,[scene.player.get_rid()])
 var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
 if not require(not hit.is_empty(),"Proof frame has an actual floor witness: "+tag):return false
 var height:float=scene.camera.global_position.y-hit.position.y
 if not require(height>0,"Reject a proof camera below its actual floor: "+tag):return false
 await picture(tag)
 var metadata:Dictionary={"caption":"Actual real-input frame; camera %.3f above actual floor %.3f"%[height,hit.position.y],"camera":str(scene.camera.global_position),"player":str(pos()),"floor":str(hit.position),"normal":str(hit.normal),"health":hp(),"resets":scene.resets}
 var file:=FileAccess.open("user://tests/generic_l10_sitting/"+tag+".json",FileAccess.WRITE);file.store_string(JSON.stringify(metadata,"  "));file.close()
 return true
func chapel_ashes_ankh()->bool:
 var route:Dictionary=fixture("l9_chapel_walk.json")
 if not await walk(route.statue.points,"priest urn to winged statue"):return false
 var row:Array=scene.progression.exit_objects["control:150"][0].position
 await act(Vector3(row[0],row[1],row[2]),"Use statue to Ruins with priest urn")
 if not await walk(route.mirror42.points,"original Ruins mirror",{"final_reach":2.0}):return false
 if not await travelled("Actual native Ruins mirror with earned urn"):return false
 if not require(area=="L9_DR" and "act2:L10_DC:priest_urn" in scene.carried_collected,"Earned urn arrives in Ruins"):return false
 if not await walk(route.upstairs.points.slice(0,74),"Noble north upstairs",{"jumps":[[-1050,-5940]]}):return false
 if scene.has_node("GenericObjects"):
  var binding:Node=scene.progression
  var door:Vector3=binding.hinges[101].transform*binding.mover_bounds[101].get_center()
  await act(door,"Open original north-house door101")
 if not await walk(route.upstairs.points.slice(74),"around open original door101 to upstairs"):return false
 if not await walk([[639,-5700],[639,-5655]],"original Noble balcony rail480"):return false
 await look(Vector3(639,160,-5596));await lclick();await ticks(8)
 if not require("480" in scene.get_node("L9NobleRails").state().broken,"Actual left-click breaks source north rail480"):return false
 if not await walk([[639,-5500]],"walk through broken north rail"):return false
 if not await walk(route.bank.points,"original west bank",{"jumps":[[2540,-7855],[2910,-8310],[3125.88,-8243.87],[3220,-8245]]}):return false
 if not await walk(route.bridge.points,"original bridge471/472"):return false
 if not await walk(route.chapel.points,"original east tunnel chapel"):return false
 if not await checkpoint("chapel_with_earned_urn"):return false
 var pyre:Node=scene.get_node("L9Pyre")
 await look(pyre.body_position()+Vector3.UP*10)
 if not await proof_picture("chapel_body_before"):return false
 await act(pyre.body_position()+Vector3.UP*10,"Drag original body2406")
 if not require(pyre.state().holding,"ActualE grabs original body"):return false
 if not await walk([[10600,-12900],[10700,-12800],[10800,-12750],[10845,-12595]],"drag original body to pyre301"):return false
 await act(pyre.ALTAR+Vector3.UP*12,"Lay body on original pyre")
 if not require(pyre.state().phase==1 and not pyre.state().holding,"ActualE lays original body on pyre"):return false
 await look(pyre.ALTAR+Vector3.UP*10)
 if not await proof_picture("chapel_body_placed"):return false
 await tap(KEY_1)
 for id in ["1205","1206"]:
  for attempt in 12:
   await act(pyre.ORBS[id],"Spark original pyre orb"+id,KEY_Q)
   if id in pyre.state().orbs:break
   await ticks(60)
  if not require(id in pyre.state().orbs,"ActualQ lights pyre orb"+id):return false
 for tick in 900:
  if pyre.state().phase==3:break
  await guard();await physics_frame
 if not require(pyre.state().phase==3,"Actual burn clock finishes to ashes"):return false
 await look(pyre.ALTAR+Vector3.UP*12)
 if not await proof_picture("chapel_ashes"):return false
 await act(pyre.ALTAR+Vector3.UP*12,"Fill original priest urn with ashes")
 if not require(not pyre.state().slots.get("chapel:ashes",{}).get("occupied","").is_empty(),"ActualE fills the earned urn"):return false
 await act(pyre.ALTAR+Vector3.UP*12,"Take original filled urn")
 if not require("act2:L9_DR:item0" in scene.carried_collected and "act2:L10_DC:priest_urn" not in scene.carried_collected,"ActualE retrieves one filled urn"):return false
 if not await checkpoint("original_filled_urn"):return false
 var back:Dictionary=fixture("l9_ashes_return_walk.json")
 for part in ["chapel","bridge","bank","gallery"]:
  var jumps:Array={"bank":[[3090,-8308],[2700,-7790],[-300,-6560]],"gallery":[[-1120,-6100]]}.get(part,[])
  if not await walk(back[part].points,"ashes return "+part,{"jumps":jumps,"sprint":not jumps.is_empty()}):return false
 if not await walk(back.cemetery_mirror.points,"original Cemetery ashes mirror",{"final_reach":2.0}):return false
 if not await travelled("Actual Cemetery return with filled urn"):return false
 if not require(area=="L10_DC" and "act2:L9_DR:item0" in scene.carried_collected,"Filled urn survives actual original map journey"):return false
 var priest_points:Array=route.statue.points.duplicate(true);priest_points.reverse()
 if not await walk(priest_points,"return original ashes to priest"):return false
 var priest:Node=scene.get_node("L10Priest")
 await act(priest.AIM,"Give ashes to priest for original ankh")
 if not require("act2:L10_DC:priest_ankh" in scene.carried_collected and "act2:L9_DR:item0" not in scene.carried_collected,"ActualE gives the original ankh once"):return false
 if not await proof_picture("earned_original_ankh"):return false
 return await checkpoint("earned_original_ankh")
func main():
 if not await start_from_f2():return
 if not require(FileAccess.get_sha256(PRIEST_INPUT)==PRIEST_PIN,"Untouched priest-urn F5 pin"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(PRIEST_INPUT,Slots.slot_path(1))==OK,"Install untouched actualF5 priest urn for F9"):return
 await tap(KEY_F9);await adopt()
 if not require(area=="L10_DC" and hp()>0,"Living realF9 priest-urn state"):return
 if not await chapel_ashes_ankh():await picture("stop");quit(1);return
 if not require(hp()>0 and scene.resets==0 and stops.is_empty(),"Living ordinary chapel/ashes/ankh sitting without recovery"):return
 print("PASS B actualW/statue/mirrors, realleft rail480, original chapel/body/pyre/Qorbs/Eurn, on-foot return and actualEpriest gives ankh/F5; continuation only, no supplied pose/health/clock/action calls")
 quit()
