extends RefCounted
## Plank210 support-entry consumer; source contract prepare_jungle_bridge_break.py.
## Source owner state1/local50/linked debris/region3032 bit1 all follow the one-time break.
## Collision of plank210 remains the native whole box; selector1 changes visible children only.
const SOURCE := "res://scripts/lol2/jungle_bridge_break_source.json"
const Contact = preload("res://scripts/lol2/source_control_contact.gd")
const Values = preload("res://scripts/lol2/save_value_rules.gd")

static func source() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SOURCE))

static func initial() -> Dictionary:
	return {"version": 1, "broken": false, "contact": Contact.initial()}

static func plates(src: Dictionary) -> Dictionary:
	var rows: Array = []
	for key in src.planks:
		var p: Dictionary = src.planks[key]
		var x: float = p.position[0]
		var z: float = p.position[2]
		var w: float = float(p.box.width) / 2.0
		var d: float = float(p.box.depth) / 2.0
		var records: Array = []
		if int(key) == int(src.breaks.plank):
			for g in src.breaks.groups:
				records.append({"value": int(src.breaks.value), "group": int(g.group)})
		else:
			var c: Dictionary = src.creaks[key]
			records.append({"value": int(c.value), "group": int(c.group)})
		rows.append({"id": int(key), "height": float(p.position[1]) + float(p.box.height),
			"polygon": [[x-w,z-d],[x+w,z-d],[x+w,z+d],[x-w,z+d]], "records": records})
	return {"plates": rows}

static func validate(s: Variant, src: Dictionary) -> String:
	if not s is Dictionary or s.size() != 3 or not Values.integer(s.get("version"), 1) or int(s.version) != 1:
		return "Invalid plank bridge state."
	if not s.get("broken") is bool: return "Invalid plank bridge break."
	return Contact.validate(s.get("contact"), plates(src))

static func canonical(s: Dictionary) -> Dictionary:
	return {"version": 1, "broken": bool(s.broken), "contact": Contact.canonical(s.contact)}

## Foot position is source-world space. Grounded tolerance4 is the existing documented support adapter.
## Gather all admitted records before executing commands: both predicate206 records see the pre-break state.
static func advance(s: Dictionary, src: Dictionary, foot: Vector3, grounded: bool, form: int) -> Array:
	var states := {str(int(src.breaks.plank)): 1 if s.broken else 0}
	var admitted := Contact.update(s.contact, plates(src), Vector2(foot.x,foot.z), foot.y, grounded, form, states)
	var effects: Array = []
	for event in admitted:
		for group in event.groups:
			effects.append({"type": "group", "group": int(group), "owner": int(event.owner)})
			var commands: Array = []
			if int(event.owner) == int(src.breaks.plank):
				for row in src.breaks.groups:
					if int(row.group) == int(group): commands = row.commands
			else:
				commands = src.creaks[str(int(event.owner))].commands
			for raw in commands:
				var b: PackedByteArray = str(raw).hex_decode()
				var target: int = b.decode_u16(2)
				match int(b[0]):
					198: effects.append({"type":"local", "index":int(b[4]), "value":int(b[5])})
					197: effects.append({"type":"region_flag", "region":target, "operation":int(b[4])})
					5: effects.append({"type":"mode", "assembly":target, "mode":int(b[4])})
					9: effects.append({"type":"presence", "kind":int(b[1]), "target":target, "present":int(b[4])==3})
					16: s.broken = true
					20: effects.append({"type":"sound", "owner":target, "request":b.decode_u16(4)})
	return effects
