extends "res://tests/generic_l10_ashes_ankh_test.gd"
## Rendered real-input visual component from this sitting's untouched chapel F5.
## No supplied body pose, health, clock, receiver calls or selector writes.
const CHAPEL_INPUT:="res://tmp/generic_l10_inputs/generic_l9_chapel.json"
const CHAPEL_PIN:="55785216ca9ed41b4692289ef0c739fb9dbc0a39b3a188686cd23ba63e594e6b"
func visible_colour(point:Vector3)->Color:
 await RenderingServer.frame_post_draw
 var at:Vector2=scene.camera.unproject_position(point)
 var frame:Image=root.get_texture().get_image()
 var colour:=Color(0,0,0,0)
 for y in range(-2,3):
  for x in range(-2,3):colour+=frame.get_pixel(int(at.x)+x,int(at.y)+y)
 return colour/25.0
func aimed_proof(point:Vector3,tag:String)->bool:
 if not await look(point):return require(false,"Actual mouse look reaches visual target "+tag)
 if not require(scene.camera.is_position_in_frustum(point),"Named proof target really lies in the camera frame: "+tag):return false
 return await proof_picture(tag)
func main():
 if not await start_from_f2():return
 if not require(FileAccess.get_sha256(CHAPEL_INPUT)==CHAPEL_PIN,"Untouched actual chapel F5 pin"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(CHAPEL_INPUT,Slots.slot_path(1))==OK,"Install actual chapel F5 for genuineF9"):return
 var old:int=scene.get_instance_id()
 await tap(KEY_F9);await adopt()
 if not require(scene.get_instance_id()!=old and area=="L9_DR" and hp()>0,"RealF9 resumes original chapel with earned urn"):return
 var pyre:Node=scene.get_node("L9Pyre")
 if not require(pyre.state().phase==0 and not pyre.state().holding and pyre.state().orbs.is_empty(),"Untouched pyre/receiver preconditions"):return
 var original_body:Vector3=pyre.body_position()
 if not await aimed_proof(original_body+Vector3.UP*10,"pyre_original_body_before"):return
 await act(original_body+Vector3.UP*10,"Grab original body for visible pyre case")
 if not require(pyre.state().holding,"ActualE grabs body"):return
 if not await walk([[10600,-12900],[10700,-12800],[10800,-12750],[10845,-12595]],"actual body drag for pixel case"):return
 await act(pyre.ALTAR+Vector3.UP*12,"Place original body for pyre pixels")
 if not require(pyre.state().phase==1 and not pyre.state().holding,"ActualE places body on pyre"):return
 if not await aimed_proof(pyre.ALTAR+Vector3.UP*10,"pyre_original_body_placed"):return
 var colours:Array=[]
 await tap(KEY_1)
 for id in ["1205","1206"]:
  var point:Vector3=pyre.meshes[id].global_position+Vector3.UP*48
  if not await aimed_proof(point,"pyre_orb"+id+"_off"):return
  var before:Color=await visible_colour(point)
  for attempt in 12:
   await act(point,"ActualQ changes pyre orb"+id,KEY_Q)
   if id in pyre.state().orbs:break
   await ticks(60)
  if not require(id in pyre.state().orbs,"ActualQ activates pyre receiver"+id):return
  await ticks(180) # Let the real Spark effect finish before measuring persistent artwork.
  if not await aimed_proof(point,"pyre_orb"+id+"_lit"):return
  var after:Color=await visible_colour(point)
  print("PYRE PIXEL ",id," native selector=",pyre.materials[id].get_meta("selector","")," before=",before," actual_after=",after)
  colours.append({"id":id,"off":[before.r,before.g,before.b],"lit":[after.r,after.g,after.b]})
  if not require(after.r>0.25 and after.r>after.g*1.2 and after.r>after.b*1.2,"Activated original pink/red pyre orb is really drawn in the viewport: "+id):return
  # Reproduce the original walk's lower receiver aim, excluding an angle-specific overlay.
  if not await aimed_proof(pyre.ORBS[id],"pyre_orb"+id+"_lit_receiver_aim"):return
  var receiver_colour:Color=await visible_colour(point)
  print("PYRE RECEIVER AIM ",id," actual_after=",receiver_colour)
  if not require(receiver_colour.r>0.25 and receiver_colour.r>receiver_colour.g*1.2 and receiver_colour.r>receiver_colour.b*1.2,"Persistent pink/red artwork also survives the original receiver-aim view: "+id):return
 for tick in 900:
  if pyre.state().phase==3:break
  await physics_frame
 if not require(pyre.state().phase==3,"Actual burn completes"):return
 if not await aimed_proof(pyre.ALTAR+Vector3.UP*12,"pyre_actual_ashes"):return
 await act(pyre.ALTAR+Vector3.UP*12,"Fill earned urn in visible pyre case")
 await act(pyre.ALTAR+Vector3.UP*12,"Retrieve actual filled urn in visible pyre case")
 if not require("act2:L9_DR:item0" in scene.carried_collected and scene.resets==0 and hp()>0,"RealE returns one filled urn without recovery/death"):return
 var f:=FileAccess.open("user://tests/generic_l10_sitting/pyre_pixel_receipt.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"REAL-INPUT VISUAL COMPONENT from genuine chapel checkpoint; no fresh whole-sitting claim","sha256":CHAPEL_PIN,"colours":colours,"resets":scene.resets},"  "));f.close()
 print("PASS pyre actual-input visual component: original body drag/place, realQ1205/1206 show published pink/red pixels, actual burn/ashes/Efilled urn; no supplied pose/health/clock/selectors or receiver calls")
 quit()
