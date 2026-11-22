extends SceneTree
const Native=preload("res://scripts/lol2/native_script_host.gd")
const Binder=preload("res://scripts/lol2/act2_progression.gd")
class Host extends Node3D:
	var quest_state:Dictionary={}
func _initialize()->void:run.call_deferred()
func run()->void:
	var session:Node=preload("res://scripts/lol2/game_session.gd").for_tree(self)
	var host:=Host.new();root.add_child(host)
	var p:=Binder.new();host.add_child(p);p.host=host;p.area_id="L9_DR";p.native=Native.new()
	assert(p.native.load_area("res://scripts/lol2/native_scripts/L9_DR.json").is_empty())
	p.native.set_field("movable:115",Native.FIELD_BYTE25,2)
	p.native.record_state[9888]={"byte5":1};p.struck_durability={"movable:82":17}
	var row:Dictionary=p.native.snapshot();row.struck_durability=p.struck_durability.duplicate(true)
	assert(session.replace_bank({"L9_DR":row}).is_empty())
	host.quest_state.act2_struck={"version":1,"areas":{"L9_DR":{"durability":{"movable:82":9},"records":{"9888":{"byte5":0}},"fields":{"movable:115":{"byte_0x25":1}}}}}
	assert(p.restore_struck().is_empty())
	assert(p.native.field("movable:115",Native.FIELD_BYTE25,0)==2 and p.native.record_state[9888].byte5==1 and p.struck_durability["movable:82"]==17,"full bank wins conflicting legacy partial")
	var partial:Dictionary=host.quest_state.act2_struck.areas.L9_DR
	partial.durability["movable:82"]=17;partial.records["9888"].byte5=1;partial.fields["movable:115"].byte_0x25=2
	var before:Dictionary=p.native.snapshot()
	assert(p.restore_struck().is_empty() and p.native.snapshot()==before,"matching bank/partial agree")
	assert(session.replace_bank({}).is_empty())
	partial.durability["movable:82"]=9;partial.records["9888"].byte5=0;partial.fields["movable:115"].byte_0x25=1
	assert(p.restore_struck().is_empty())
	assert(p.native.field("movable:115",Native.FIELD_BYTE25,0)==1 and p.native.record_state[9888].byte5==0 and p.struck_durability["movable:82"]==9,"legacy-only partial behavior retained")
	host.free()
	print("PASS full native bank wins partial struck conflicts; matching copies agree; legacy-only restores unchanged")
	quit()
