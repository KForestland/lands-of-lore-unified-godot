extends SceneTree
const Controls=preload("res://scripts/lol2/cave_guard_controls.gd")
const Curse=preload("res://scripts/lol2/player_curse.gd")
class Host extends Node3D:
	var player_form:=0
	var starting_magic:Node=null
	var curse:Node
class Probe extends Controls:
	var emitted:Array=[]
	func apply(effects:Array) -> void:emitted.append_array(effects)
var host:Host
var controls:Probe
func _initialize() -> void:run.call_deferred()
func check(ok:bool,text:String) -> bool:
	if ok:return true
	push_error(text);controls.free();host.free();quit(1);return false
func reset(form:int) -> void:
	host.player_form=form
	host.curse.restore(Curse.initial())
	controls.state=controls.State.initial()
	controls.state.contact.owner=114
	controls.emitted.clear()
func run() -> void:
	host=Host.new();root.add_child(host)
	host.curse=Curse.new();host.add_child(host.curse);host.curse.set_physics_process(false)
	controls=Probe.new();controls.host=host
	for form in [1,2]:
		reset(form)
		controls.apply_plate(114,4)
		if not check(not controls.input_locked() and controls.state.controls["114"]==0 and controls.state.groups.is_empty(),"Nonhuman contact started the cutscene or consumed its trigger"):return
		if not check(controls.state.contact.owner==-1 and host.curse.state.phase==3 and host.curse.state.target==0,"Contact not replayable or human return not requested"):return
		if not check(Curse.valid(host.curse.snapshot(),form) and controls.State.validate(controls.state,controls.src,controls.media).is_empty(),"Pending state is not save-valid"):return
		# Round-trip the real pending state; the body transition itself belongs to rendered integration.
		controls.state=controls.State.canonical(JSON.parse_string(JSON.stringify(controls.state)))
		host.curse.restore(JSON.parse_string(JSON.stringify(host.curse.snapshot())))
		var plate:Dictionary={}
		for row in controls.src.plates:
			if int(row.id)==114:plate=row
		var centre:=Vector2.ZERO
		for point in plate.polygon:centre+=Vector2(point[0],point[1])
		centre/=plate.polygon.size()
		var contacts:Array=controls.Contact.update(controls.state.contact,controls.src,centre,float(plate.height),true,form,controls.state.controls)
		if not check(contacts.size()==1 and int(contacts[0].owner)==114 and int(contacts[0].value)==4,"Reloaded pending support did not emit its contact again"):return
		controls.apply_plate(int(contacts[0].owner),int(contacts[0].value))
		if not check(not controls.input_locked(),"Pending/reloaded request started a nonhuman cutscene"):return
		host.player_form=0;host.curse.restore(Curse.initial())
		controls.apply_plate(114,4)
		if not check(controls.input_locked() and controls.state.controls["114"]==1 and controls.state.groups.count(10266)==1,"Human arrival did not start original sequence once"):return
		var once:Dictionary=controls.state.duplicate(true)
		controls.apply_plate(114,4)
		if not check(controls.state==once,"Repeated contact replayed the sequence"):return
	reset(0);controls.apply_plate(114,4)
	if not check(controls.input_locked() and host.curse.state.phase==0,"Human trigger changed"):return
	reset(1);controls.apply_plate(109,9)
	if not check(controls.state.branch109=="beast" and host.curse.state.phase==0,"Other form-specific encounter changed"):return
	reset(2);host.curse.set_requests_enabled(false);controls.apply_plate(114,4)
	if not check(not controls.input_locked() and controls.state.contact.owner==-1 and host.curse.state.phase==0,"Disabled requests lost trigger or bypassed admission"):return
	host.curse.set_requests_enabled(true);controls.apply_plate(114,4)
	if not check(host.curse.state.phase==3,"Re-enabled request did not retry"):return
	controls.free();host.free()
	print("PASS Cave guard human gate: nonhuman waits, pending save roundtrip, retry, human once, other plate unchanged; body/camera integration separate")
	quit(0)
