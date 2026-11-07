extends SceneTree
const State=preload("res://scripts/lol2/player_spark_aura_state.gd")
const Magic=preload("res://scripts/lol2/hive_magic_reward.gd")
func _initialize():
 # Pure save-contract vectors, never injected into a gameplay save.
 for path in State.ACT2_SCENES:
  var aura:=State.initial();aura.area=path
  assert(State.validate(aura).is_empty(),path)
 for area in State.ACT2_AREAS:
  var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/act2_populations/%s.json"%area))
  for row in source.actors:
   assert(State.valid_target(area+"actor"+str(int(row.actor))))
  assert(not State.valid_target(area+"actor999999"))
 assert(not State.valid_target("L10_DCactor036"))
 assert(not State.valid_target("L11_BADactor36"))
 var saved:=preload("res://scripts/lol2/player_magic_state.gd").initial()
 var aura:=State.initial();aura.area="res://scenes/lol2/maps/L10_DC.tscn"
 aura.bolts=[{"target":"L10_DCactor36","effect":20,"position":[0,0,0],"life":1.0}]
 aura=State.canonical(aura)
 saved.spark_aura=aura
 var restored: Dictionary=Magic.restore(JSON.parse_string(JSON.stringify(saved)))
 assert(not restored.has("error") and restored.checkpoint.spark_aura==aura,str(restored))
 var reward: Dictionary=Magic.award_checkpoint(saved,1,[])
 assert(not reward.has("error") and reward.checkpoint.spark_aura==aura,str(reward))
 print("PASS Act2 Spark scene/actor save contracts, canonical reload and reward preservation; pure vectors, maximum-Spark runtime hit not claimed")
 quit()
