extends SceneTree
const S=preload("res://scripts/lol2/l9_flood_state.gd")
func _initialize():
 var s:=S.initial();assert(S.validate(s).is_empty())
 var row:={"floor":[-20,-20],"target":87}
 assert(S.height(row,0)==-20 and S.height(row,10)==0 and S.height(row,100)==87)
 S.advance(s,10,false);assert(s.elapsed==10 and s.breath==0)
 S.advance(s,7,true);assert(s.breath==7 and not s.dead)
 var restored: Dictionary=JSON.parse_string(JSON.stringify(s));assert(S.validate(restored).is_empty())
 S.advance(restored,1,false);assert(restored.breath==0)
 S.advance(s,8,true);assert(s.dead and s.breath==15 and S.validate(s).is_empty())
 var dead:=s.duplicate();S.advance(s,100,true);assert(s==dead)
 for field in ["elapsed","breath"]:
  var bad:=S.initial();bad[field]=NAN;assert(not S.validate(bad).is_empty())
 var bad:=S.initial();bad.dead=true;assert(not S.validate(bad).is_empty())
 var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/l9_flood_source.json"))
 assert(source.floor_commands.size()==91)
 for r in source.floor_commands:assert(r.speed==1 and S.height(r,S.LIMIT)==float(r.target))
 print("PASS source flood targets, bounded water clock, breath reset/death, JSON and malformed-state refusal; isolated state fixture")
 quit()
