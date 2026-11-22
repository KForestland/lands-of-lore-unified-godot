extends SceneTree
const Teaching=preload("res://scripts/lol2/player_spell_teaching.gd")
const Magic=preload("res://scripts/lol2/player_magic_state.gd")
const Owner=preload("res://scripts/lol2/player_starting_magic.gd")
func _initialize():
 var old:=Magic.initial();assert(not old.has("spellbook"))
 var before:=old.duplicate(true)
 var early:=Teaching.migrate(old,{},"L1_DC")
 assert(early.spellbook.learned.is_empty() and old==before,"Early legacy save stays unlearned; original untouched")
 var fresh:Node=Owner.new()
 assert(fresh.fallback.spellbook.learned.is_empty(),"New-game fallback carries explicit unlearned marker")
 assert(Teaching.migrate(fresh.fallback,{},"L20_BB")==fresh.fallback,"Late new-map component does not acquire unearned spells")
 fresh.free()
 for row in [["L12_CM",6],["L13_RC",6],["L14_HT",6],["L16_CA",8],["L17_HC",8],["L19_BC",8],["L20_BB",8]]:
  var next:=Teaching.migrate(old,{},row[0])
  assert(next.spellbook.learned.size()==row[1],"One table's post-teaching chapter: "+row[0])
  assert(Teaching.migrate(next,{},row[0])==next,"Idempotent modern migration")
  var stripped:Dictionary=next.duplicate(true);stripped.erase("spellbook")
  assert(stripped==before,"Only learned packet changes, no mana/spell/health/history rewrite")
 var receipt:={"l8_dawn":{"slots":{"dawn:bracers":{"committed":true}}}}
 assert("curse2" in Teaching.migrate(old,receipt,"L8_SJ").spellbook.learned,"Actual Dawn receipt teaches before later map")
 assert("curse1" in Teaching.migrate(old,{},"L4_HJ",[],["monastery:item70:Dampen_charm"]).spellbook.learned,"Consumed charm still proves old teaching")
 var modern:=old.duplicate(true);modern.spellbook={"version":1,"learned":[]}
 assert(Teaching.migrate(modern,receipt,"L20_BB")==modern,"Explicit modern empty book is never retro-granted")
 var packet:={"quests":{"player_magic_reward_state":modern},"inventory":{"collected":[]}}
 var original:Dictionary=packet.duplicate(true)
 var start:=Teaching.prepare_start(packet,"L19_BC")
 assert(start.quests.player_magic_reward_state.spellbook.learned.size()==8 and packet==original,"Explicit F2 adapter fills even a partial modern pin on a detached copy")
 print("PASS G15 single-table legacy lessons, old input unchanged, fresh/modern no grants, receipts/spent, all seven F2 chapter capability contracts")
 quit()
