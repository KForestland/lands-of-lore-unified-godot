extends RefCounted
## Shared source command state. External commands remain explicit pending effects.
const Sequence=preload("res://scripts/lol2/cave_guard_sequence_state.gd")
const Movement=preload("res://scripts/lol2/cave_guard_movement_state.gd")
const Delayed=preload("res://scripts/lol2/cave_guard_delayed_state.gd")
const Values=preload("res://scripts/lol2/save_value_rules.gd")
## Kind-4 use groups by lever (state 0 group; state 1 group = +24). 67 -> gate 71 is g12490/g12514.
const LEVERS:={64:12346,65:12394,66:12442,67:12490,72:12568}
## Movables added after the first eight (saves made before r12m lack them: upgrade_packet).
const ADDED_MOVABLES:=[67,71]
static func initial(src: Dictionary, geometry: Dictionary) -> Dictionary:
	var owners: Dictionary={}
	for row in geometry.movables:owners[str(int(row.motion.index))]=0
	return {"version":1,"sequence":Sequence.initial(),"movement":Movement.initial(geometry),"movable_states":owners,"input_locked":false,"focus":false,"prop_present":true,"definition_flags":{},"definition_release_at":-1,"region_flags":{"10":3,"29":35},"delayed":Delayed.initial(),"pending":[],"groups":[]}
static func validate(s: Variant, src: Dictionary, geometry: Dictionary) -> String:
	if not s is Dictionary or not Values.integer(s.get("version"),1) or s.version!=1:return "Invalid encounter version."
	var error:=Sequence.validate(s.get("sequence"),src)
	if not error.is_empty():return error
	error=Movement.validate(s.get("movement"),geometry)
	if not error.is_empty():return error
	for key in ["input_locked","focus","prop_present"]:
		if not s.get(key) is bool:return "Invalid encounter latch."
	if s.input_locked!=(s.sequence.phase in ["armed","playing"]) or s.focus!=s.input_locked:return "Encounter focus/control phase mismatch."
	if not s.get("movable_states") is Dictionary or s.movable_states.size()!=geometry.movables.size():return "Invalid encounter owner bank."
	for row in geometry.movables:
		if not Values.integer(s.movable_states.get(str(int(row.motion.index))),1):return "Invalid encounter owner state."
	if not s.get("definition_flags") is Dictionary or s.definition_flags.size()>1:return "Invalid encounter definition flag bank."
	if not s.definition_flags.is_empty() and (not s.definition_flags.has("28") or (s.definition_flags["28"]!=0 and s.definition_flags["28"]!=2)):return "Invalid crossbow definition flag."
	if not s.get("groups") is Array or s.groups.size()>4096 or not s.get("pending") is Array or s.pending.size()>128:return "Invalid encounter receipts."
	for id in s.groups:
		if not (id is int or id is float) or not Values.integer(id,65535) or not src.groups.has(str(int(id))):return "Unknown encounter group."
	for effect in s.pending:
		if not effect is Dictionary or not effect.get("raw") is String or not effect.get("group") is float and not effect.get("group") is int:return "Invalid pending encounter effect."
		if not src.groups.has(str(int(effect.group))):return "Unknown pending group."
		var found:=false
		for c in src.groups[str(int(effect.group))].commands:
			if c.raw==effect.raw:found=true
		if not found:return "Pending effect has no source command."
	var expected_pending: Array=[]
	for group in s.groups:
		if int(group) not in [9994,4376]:continue
		for c in src.groups[str(int(group))].commands:
			var b:=str(c.raw).hex_decode()
			if b[0]==18 or (b[0]==2 and b[1]==1 and b[4]==32):expected_pending.append({"group":int(group),"raw":c.raw})
	if s.pending.size()!=expected_pending.size():return "Missing pending encounter effect."
	for i in range(expected_pending.size()):
		if s.pending[i].raw!=expected_pending[i].raw or s.pending[i].group!=expected_pending[i].group:return "Pending encounter order mismatch."
	# Group4076 property27 can reverse group56 property26. Record its position among
	# encounter groups so a later legitimate group56 can set the same bank again.
	var release: Variant=s.get("definition_release_at",-1)
	if not (release is int or release is float) or not is_finite(float(release)) or float(release)!=floorf(float(release)) or release< -1 or release>s.groups.size():return "Invalid crossbow release receipt."
	var last_flag: int=-1
	for index in s.groups.size():
		if int(s.groups[index])==56:last_flag=index
	if s.definition_flags.has("28")!=(last_flag>=0 or release>=0):return "Crossbow flag receipt mismatch."
	if s.definition_flags.has("28"):
		var expected_flag:=2 if last_flag>=int(release) else 0
		if s.definition_flags["28"]!=expected_flag:return "Crossbow definition command order mismatch."
	if not s.get("region_flags") is Dictionary or s.region_flags.size()!=2:return "Invalid encounter region bank."
	for id in ["10","29"]:
		var expected: int=(0 if id=="10" else 32) if s.sequence.phase!="idle" else (3 if id=="10" else 35)
		if not Values.integer(s.region_flags.get(id),255) or s.region_flags[id]!=expected:return "Encounter region marker mismatch."
	var fired_receipt:=false
	for group in s.groups:
		if int(group)==5050:
			if fired_receipt:return "Repeated delayed guard sound."
			fired_receipt=true
	error=Delayed.validate(s.get("delayed"),s.sequence.phase=="complete",fired_receipt)
	if not error.is_empty():return error
	if not s.prop_present and s.movable_states["68"]!=1:return "Guard prop disappeared without barrier callback."
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var r:=s.duplicate(true);r.version=1;r.sequence=Sequence.canonical(s.sequence);r.movement=Movement.canonical(s.movement)
	for id in r.movable_states:r.movable_states[id]=int(r.movable_states[id])
	for id in r.definition_flags:r.definition_flags[id]=int(r.definition_flags[id])
	r.definition_release_at=int(s.get("definition_release_at",-1))
	r.delayed=Delayed.canonical(r.delayed)
	for id in r.region_flags:r.region_flags[id]=int(r.region_flags[id])
	r.groups=r.groups.map(func(n):return int(n))
	for effect in r.pending:effect.group=int(effect.group)
	return r
static func apply(s: Dictionary, src: Dictionary, geometry: Dictionary, batches: Array, local7: int) -> void:
	for batch in batches:
		var group:=int(batch.group);s.groups.append(group)
		for command in batch.commands:
			var b:=str(command.raw).hex_decode();var op:=int(b[0]);var kind:=int(b[1]);var id:=int(b.decode_u16(2));var arg:=int(b[4])
			if op==197 and kind==144 and id in [10,29] and arg==5:s.region_flags[str(id)]=int(s.region_flags[str(id)])&252;continue
			# Gate 71 endpoints (g12556 value15 / g12562 value16): op197 sub5 clears and sub4 sets region1143 bits 0|1
			# (handler 0x64D54 / 0x64D5F). The port's gate 71 collision body stands for the region bits (DEVIATIONS).
			if op==197 and kind==144 and id==1143 and arg in [4,5]:continue
			if op==14 and kind==3 and id==515 and arg==3:Delayed.start(s.delayed);continue
			if op==14 and kind==3 and id==515 and arg==4:continue # Fired latch stops the source one-shot.
			if op==20 and kind==3 and id==515 and b.decode_u16(4)==323:continue # Delayed.step starts the saved voice clock.
			if op==1 and kind==32:
				assert(Movement.command(s.movement,geometry,id,arg));continue
			if op==16 and kind==32:s.movable_states[str(id)]=arg;continue
			if op==2 and kind==1 and arg in [0,1]:s.input_locked=arg==0;continue
			if op==2 and kind==3 and id==456 and arg in [5,6]:s.focus=arg==5;continue
			if op==9 and kind==3 and id==456:
				if arg==2:s.prop_present=false;continue
				if arg==10:continue # Native render latch is represented by sequence.armed.
			if op==9 and kind==3 and id==21 and arg==21:
				if local7==0:apply(s,src,geometry,[{"group":56,"commands":src.groups["56"].commands}],local7)
				continue
			if op==9 and kind==4 and id==4 and arg==26:s.definition_flags["28"]=2;continue
			if kind==3 and id==456 and op in [5,8,16]:continue # Owned by Sequence callback/selector state.
			if kind==16 and id==104 and op in [9,16]:continue # One-shot support admitted by Sequence.control_state.
			s.pending.append({"group":group,"raw":command.raw})
static func enter(s: Dictionary, src: Dictionary, geometry: Dictionary, point: Vector2, foot: float, grounded: bool, form: int, local7: int) -> void:
	apply(s,src,geometry,Sequence.enter(s.sequence,src,point,foot,grounded,form),local7)
static func rendered(s: Dictionary, src: Dictionary, geometry: Dictionary, local7: int) -> void:
	apply(s,src,geometry,Sequence.rendered(s.sequence,src),local7)
static func movie_step(s: Dictionary, src: Dictionary, geometry: Dictionary, delta: float, local7: int) -> void:
	apply(s,src,geometry,Sequence.advance(s.sequence,src,delta),local7)
static func movement_step(s: Dictionary, src: Dictionary, geometry: Dictionary, tick_fixed: int, local7: int) -> void:
	for event in Movement.advance(s.movement,geometry,tick_fixed):
		if event.owner==68 and event.value==15 and s.movable_states["68"]==0:
			apply(s,src,geometry,[{"group":12538,"commands":src.groups["12538"].commands}],local7)
		# Gate 71 kind-6 records value15 (raised) and value16 (lowered), no predicate.
		if event.owner==71 and event.value in [15,16]:
			var gate_group:=12556 if event.value==15 else 12562
			apply(s,src,geometry,[{"group":gate_group,"commands":src.groups[str(gate_group)].commands}],local7)
static func use_lever(s: Dictionary, src: Dictionary, geometry: Dictionary, id: int, local7: int) -> bool:
	if s.input_locked or id not in LEVERS:return false
	var base: int=LEVERS[id];var group:=base+(24 if s.movable_states[str(id)]==1 else 0)
	apply(s,src,geometry,[{"group":group,"commands":src.groups[str(group)].commands}],local7)
	return true

static func timer_step(s: Dictionary, src: Dictionary, geometry: Dictionary, ticks: int, local7: int) -> void:
	if Delayed.step(s.delayed,ticks):apply(s,src,geometry,[{"group":5050,"commands":src.groups["5050"].commands}],local7)

static func initial_packet(src: Dictionary, geometry: Dictionary) -> Dictionary:
	return {"version":1,"encounter":initial(src,geometry),"applied_pending":0,"tick_fraction":0.0}
## Saves from before lever 67 / gate 71 hold exactly the other eight movables: add the two at their source rest state
## (owner state 0, Movement.initial's object). Any other shape is left for validate to refuse.
static func upgrade_packet(packet: Variant, geometry: Dictionary) -> void:
	if not packet is Dictionary or not packet.get("encounter") is Dictionary:return
	var e: Dictionary=packet.encounter
	if not e.get("movable_states") is Dictionary or not e.get("movement") is Dictionary or not e.movement.get("objects") is Dictionary:return
	var objects: Dictionary=e.movement.objects
	if e.movable_states.size()!=geometry.movables.size()-ADDED_MOVABLES.size() or objects.size()!=e.movable_states.size():return
	for id in ADDED_MOVABLES:
		if e.movable_states.has(str(id)) or objects.has(str(id)):return
	for id in ADDED_MOVABLES:
		# Same rest values as Movement.initial (both have initial_travel 0, so current == target).
		e.movable_states[str(id)]=0;objects[str(id)]={"current":int(Movement.record(geometry,id).initial_travel)*65536,"target":0,"status":0}
static func validate_packet(packet: Variant, src: Dictionary, geometry: Dictionary) -> String:
	upgrade_packet(packet,geometry)
	if not packet is Dictionary or packet.get("version")!=1:return "Invalid live guard encounter version."
	var error:=validate(packet.get("encounter"),src,geometry)
	if not error.is_empty():return error
	if not Values.integer(packet.get("applied_pending"),128) or packet.applied_pending!=packet.encounter.pending.size():return "Guard host effects not committed."
	var fraction=packet.get("tick_fraction")
	if not (fraction is int or fraction is float) or not is_finite(float(fraction)) or fraction<0 or fraction>=1:return "Invalid guard tick fraction."
	return ""

## Original group4076 item4 property27: definition28 getter becomes false.
## This changes the shared definition flag, never grants or removes an inventory item.
static func release_crossbow_definition(s: Dictionary) -> void:
	s.definition_flags["28"]=0
	s.definition_release_at=s.groups.size()
