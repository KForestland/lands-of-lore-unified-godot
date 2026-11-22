extends SceneTree
const Globals=preload("res://scripts/lol2/game_native_globals.gd")
const Session=preload("res://scripts/lol2/game_session.gd")
const Saves=preload("res://scripts/lol2/game_save.gd")
func row(cells:Dictionary)->Dictionary:
 return {"state":{},"locals":{"1":7},"locals_e58":cells,"record_state":{},"struck_durability":{}}
func _initialize():
 var bank:Dictionary={"L10_DC":row({"34":1,"13":2}),"L14_HT":row({"34":1,"13":0}),"L9_DR":row({"9":1}),"L13_RC":row({"9":2})}
 var legacy:=Globals.legacy(bank,"L14_HT")
 assert(legacy.locals_e58=={"34":1,"13":0},"Current old level wins; conflicting inactive cells remain unknown")
 var session:=Session.new()
 assert(session.replace_bank(bank,null,"L14_HT").is_empty(),"Old five-field bank migrates")
 assert(session.native_globals==legacy and session.native_bank.L10_DC.locals=={"1":7},"Promotion preserves per-level locals")
 for area in session.native_bank:assert(session.native_bank[area].locals_e58.is_empty(),"Per-level cells retired after migration")
 var cells:Dictionary={"version":1,"locals_e58":{"52":1,"13":2}}
 assert(session.replace_bank(bank,cells,"L14_HT").is_empty() and session.native_globals==cells,"Explicit new global table overrides old per-level copies")
 var before:=session.runtime_checkpoint()
 for bad in [{"version":1,"locals_e58":{"-1":0}},{"version":1,"locals_e58":{"52":256}},{"version":1,"locals_e58":{"52":0.5}},{"version":1,"locals_e58":[],"extra":0}]:
  assert(not session.replace_bank(bank,bad).is_empty() and session.runtime_checkpoint()==before,"Malformed global cell refuses both owners atomically")
 var migrated:=Saves.migrate({"format":Saves.FORMAT,"version":2,"area":"L14_HT","native_bank":bank})
 assert(migrated.error.is_empty() and migrated.state.native_globals==legacy,"Existing version2 envelopes gain the global table without losing old cells")
 var snapshot:=session.snapshot_bank()
 assert(snapshot.L14_HT.locals=={"1":7} and session.snapshot_globals()==cells,"Saved area locals and one global owner remain distinct")
 for area in snapshot:assert(snapshot[area].locals_e58.is_empty(),"No global values duplicated in saved area bank")
 session.reset_legacy();assert(session.native_globals==Globals.empty(),"New/legacy session clears previous global cells")
 session.restore_runtime(before);assert(session.native_globals==cells and session.runtime_checkpoint()==before,"Failed-load rollback restores global cells as well as level bank")
 session.free()
 print("PASS G04 one global table, old-bank/current-area migration, unknown ambiguity, byte bounds, atomic refusal, rollback and no per-area copies")
 quit()
