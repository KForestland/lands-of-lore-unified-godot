extends "res://tests/act2_body_fit_blood_earned_test.gd"
## BJ11 sitting l19a arrival -> horn -> bars, now through production input only.
## B1 uses the physical rim/cap above614, never its native floor band near-25.
const ARRIVAL_SHA := "f8ff0b0a144d201b8344ebebc0f4a7e51d749b1448fc2c166fbc58308446cb03"
func configure_clock()->void:pass # Acceptance uses the engine's ordinary 60 Hz / time scale1.
func proof_folder()->String:return "c10_l19a"
func route_path()->String:return "res://tests/fixtures/c10_l19a_route.json"
func crossing_complete(pass_index:int)->bool:
 proof["acceptance"]="C10: native arrival1 -> E horn -> physical rim/cap over614 -> linked613/18 -> bars; F9 repeat from earned pool approach. Ordinary engine clock; no body/terrain edits; legacy floor-load repair."
 proof["clock"]={"time_scale":Engine.time_scale,"physics_ticks_per_second":Engine.physics_ticks_per_second}
 if not check(is_equal_approx(Engine.time_scale,1.0) and Engine.physics_ticks_per_second==60,"C10 acceptance uses ordinary clock1/60"):return false
 proof["route_sha256"]=FileAccess.get_sha256(route_path())
 if not check(scene.get_node("L19BelialHorn").state().taken,"Horn remains earned at the bars"):return false
 forward(false)
 proof["bars_before%d"%pass_index]={"floor40":scene.progression.regions[40][1],"floor61":scene.progression.regions[61][1]}
 if int(scene.progression.regions[40][1])!=-40 or int(scene.progression.regions[61][1])!=-40:
  await shot("bars_before_click_failure")
  print("STOP C10 F9 restored a pre-click save with raised floors40/61 ",proof["bars_before%d"%pass_index]," [sol]")
  return check(false,"Before bars click%d expected native floors40/61=-40; got %s"%[pass_index,proof["bars_before%d"%pass_index]])
 aim(Vector3(-344.0,-20.0,-1667.0));await click()
 for wait_tick in 600:
  await physics_frame;sample()
  if failed:return false
  if int(scene.progression.regions[40][1])==-20:break
 if not check(int(scene.progression.regions[40][1])==-20 and int(scene.progression.regions[61][1])==-20,"Real Human click from earned bars stand raises corridor"):return false
 if not check(absf(scene.player.position.y-12.0)<4.0,"Raised floor supports Luther at the bars"):return false
 proof["bars%d"%pass_index]={"position":[scene.player.position.x,scene.player.position.y,scene.player.position.z],"floor40":scene.progression.regions[40][1],"floor61":scene.progression.regions[61][1],"horn_taken":true,"resets":scene.resets}
 print("C10 BARS pass",pass_index," earned horn, real click, floors40/61 raised, resets",scene.resets)
 return true
var pictured_horn:=false
var pictured_pool:=false
func after_sample()->bool:
 if not pictured_horn and bool(scene.get_node("L19BelialHorn").state().taken):
  pictured_horn=true;await shot("horn_taken")
 var fit:Dictionary=scene.player.get_meta("lol2_world_fit",{})
 if not pictured_pool and bool(fit.get("active",false)) and float(fit.height)<=10.0:
  pictured_pool=true;await shot("pool_fit")
 return not failed
func run():
 if not check(FileAccess.get_sha256(OS.get_environment("LOL2_BODY_FIT_ARRIVAL_SAVE"))==ARRIVAL_SHA,"C10 arrival input SHA256 pin"):return
 await super.run()
