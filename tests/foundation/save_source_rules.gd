extends RefCounted
## Conventional source guard. Runtime fixtures remain the semantic compatibility gate.
const HOSTS := ["cave_walkthrough.gd","museum_walkthrough.gd","jungle_walkthrough.gd","hive_review.gd","dark_halls.gd","darker_jungle.gd","dragon_level.gd","act2_map.gd","act2_jungle_return.gd"]
const AUDIT_WRITE := 'var file := FileAccess.open(directory + "/view.json", FileAccess.WRITE)'
static func problems(path:String,source:String)->Array[String]:
	var out:Array[String]=[];var method:="";var number:=0
	for line in source.split("\n"):
		number+=1
		if line.strip_edges().begins_with("#"):continue
		if "lol2_act2_native_bank" in line or "lol2_adapter_exit_seeds" in line:
			out.append("%s:%d: raw session meta; use GameSession"%[path,number])
		if line.begins_with("func "):method=line.trim_prefix("func ").get_slice("(",0)
		if path.get_file() not in HOSTS:continue
		if ("FileAccess.WRITE" in line or "FileAccess.WRITE_READ" in line) and not (path.get_file()=="cave_walkthrough.gd" and method=="_process" and line.strip_edges()==AUDIT_WRITE):
			out.append("%s:%d: host owns a new file writer"%[path,number])
		if ".write_save(" in line and method!="_quicksave_unrecorded":
			out.append("%s:%d: area write outside named legacy writer"%[path,number])
	return out
