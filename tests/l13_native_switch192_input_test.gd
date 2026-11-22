extends "res://tests/l13_native_switch193_input_test.gd"
const UPPER="res://tmp/l13_native_use_inputs/owner_044631.json"
const UPPER_PIN="047b763f4f52b4671d4f26c8a1aeea31ac795e84ac0ce223c3815db6a5e5480b"
func main()->void:
 if not require(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary1/60"):return
 if not require(FileAccess.get_sha256(UPPER)==UPPER_PIN,"Unedited upper owner F10 pin"):return
 var error:String=Save.load_file(self,UPPER)
 if not require(error.is_empty(),"Actual whole-game upper owner loader: "+error):return
 await adopt()
 if not captured():await lclick();await frames(3)
 # Existing earned road, exactly the same Spark/eye/vent steps as the
 # qualified Citadel sitting; no supplied state or pose after the loader.
 await tap(KEY_1)
 await act(Vector3(-3254,43.5,5330),"Spark original egg globe",KEY_Q)
 if not require(scene.get_node("L13EggDoor").state().opened,"Real Spark opens the saved closed egg door"):return
 if not await walk([[-3320,5500],[-3320,5200],[-3260,5000],[-3260,4800]],"Owner upper egg doorway"):quit(1);return
 if not await walk(fixture("l13_basin_walk.json").points,"Source eye corridor"):quit(1);return
 await act(Vector3(-3270,-26.5,4210),"Use original eye switch")
 if not require(scene.get_node("L13Eggs").state().eye_open,"Actual E opens the original irises"):return
 if not await walk([[-3100,4210],[-2900,4210],[-2650,4210],[-2460,4210]],"Earned egg chamber"):quit(1);return
 await act(Vector3(-2171,166,4165),"Spark original egg vent",KEY_Q)
 if not require(scene.get_node("L13Eggs").state().vent_broken,"Actual Q drains the basin"):return
 if not await walk([[-2200,4160],[-1900,4160],[-1690,4170]],"Native192 approach"):quit(1);return
 var native=scene.progression.native
 if not require(native.field("prop:192",native.FIELD_BYTE25,0)==0,"Native192 has not been credited by another modern puzzle"):return
 await look(Vector3(-1572,3.5,4170));await frames(4)
 var prompt:String=scene.get_node("GenericObjects").hint.text
 await tap(KEY_E);await frames(3)
 if not require(native.field("prop:192",native.FIELD_BYTE25,0)==1 and prompt.contains("switch"),"Actual E answers the source192 sprite and dispatches group576"):return
 if not await disk_cycle("native192_upper"):return
 if not require(scene.progression.native.field("prop:192",native.FIELD_BYTE25,0)==1 and hp()>0 and scene.resets==0 and deaths==0,"Real F5/F9 retains192 after a living ordinary-input approach"):return
 await picture("l13_switch192_used")
 print("PASS native192 actual upper-owner Spark/E/W/vent approach, realE/source576/F5F9 alive0resets; no supplied pose/resources/health/clock")
 quit()
