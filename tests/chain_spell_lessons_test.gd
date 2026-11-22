extends SceneTree
## Unit admission/provenance matrix, not earned or input evidence.
const Teaching=preload("res://scripts/lol2/player_spell_teaching.gd")
const Book=preload("res://scripts/lol2/player_spell_book.gd")
class Host extends Node3D:
 var area_id:=""
 var player_form:=0
class Receiver extends Node:
 var eligible:=false
 var queries:=0
 func check()->bool:queries+=1;return eligible
 func needs_shape_lesson()->bool:return check()
 func needs_mists_lesson()->bool:return check()
 func at_mouth()->bool:return check()
 func accepts_player_spell(_id:String)->bool:return check()
func _initialize():
 var casts:Dictionary={}
 var expected:Dictionary={"dampen":"curse1","control":"curse3","mists":"mists1","prism":"prism5","summon":"summon3"}
 var full:Dictionary=Book.initial()
 for group:String in expected:full=Book.learn(full,group)
 for row:Dictionary in Teaching.table().live_lessons:
  assert(row.group in expected and not str(row.message).is_empty())
  var script:Script=load("res://scripts/lol2/"+str(row.script))
  assert(script.get_script_method_list().any(func(method):return method.name==str(row.query)),"Actual production owner query exists: "+str(row.owner))
  var host:=Host.new();host.area_id=row.area
  host.player_form=2 if row.has("forms") else 0 # Fixture only; no body/form change claim.
  var owner:=Receiver.new();owner.name=row.owner;host.add_child(owner)
  var empty:Dictionary=Book.initial();var before:Dictionary=empty.duplicate(true)
  assert(Teaching.live_candidates(host,empty).is_empty(),"No eligibility means no live chapter grant: "+str(row.owner))
  owner.eligible=true
  var candidates:Array=Teaching.live_candidates(host,empty)
  assert(candidates.any(func(candidate):return candidate.group==row.group),"Each requirement has a live lesson, including JSON numeric form2: "+str(row.owner))
  if row.has("forms"):
   host.player_form=0
   assert(not Teaching.live_candidates(host,empty).any(func(candidate):return candidate.group==row.group),"Lizard-only return lesson never appears for Human")
   host.player_form=2
  for cast:String in Book.GROUPS[str(row.group)]:casts[cast]=true
  owner.queries=0
  assert(Teaching.live_candidates(host,full).is_empty() and owner.queries==0,"A complete book never repeats lessons or expensive queries")
  assert(empty==before,"Eligibility never changes book or casts")
  # Knowing the relevant charge alone is enough: a modern partial Control
  # book must not re-teach Expel while the story is refusing its actual cast.
  var partial:Dictionary=Book.initial();partial.learned=[Teaching.required_cast(row,host.player_form)]
  owner.queries=0
  assert(not Teaching.live_candidates(host,partial).any(func(candidate):return candidate.owner==row.owner and candidate.group==row.group),"Known required cast does not re-teach a partial group")
  host.free()
 for id:String in Book.CASTS:assert(casts.has(id),"All eight quest casts covered: "+id)
 # Real six-map robot life, not a constructed legacy packet or an F2 start.
 var pin:="res://tests/fixtures/chain_spell_lessons/sixth_life_before_heads.json"
 assert(FileAccess.get_sha256(pin)=="ad5b66a596456d626d2213b96655596b41cb8239349f8915eb4f1ded3acf9ce5")
 var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(pin))
 var magic:Dictionary=doc.area_save.quests.player_magic_reward_state
 assert(doc.area=="L19_BC" and not "mists1" in magic.spellbook.learned and magic.spellbook.learned.size()==6,"Actual modern continuous life reaches L19 without the optional Mists scroll")
 assert(Teaching.migrate(magic,doc.area_save.quests,"L19_BC")==magic,"Modern loaded book remains authoritative away from the live requirement")
 print("PASS all eight chain casts: named production queries, optional eligibility/no global grant, numeric form admission, learned skip, pure query, pinned genuine unlearned sixth-life book")
 quit()
