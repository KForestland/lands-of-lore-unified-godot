extends RefCounted
## Fast guard against conventional copies of the player rules/stores. Native
## enemy/spell numbers and UI animation constants are outside this policy.
const FORWARDERS={"jungle_walkthrough.gd":["apply_inventory_handoff"],"museum_walkthrough.gd":["_ready","apply_save"],"hive_warriors.gd":["restore"]}
# Fable's click-only/no-damage list deliberately leaves this owner-specific
# bar/region reach alone. Pin the exact declaration; no blanket file exemption.
const CLICK_ONLY_REACH={"l19_sewer_forms.gd":"const STRIKE_REACH := 96.0"}
static var _patterns:Dictionary={}
static func matches(pattern:String,line:String)->bool:
	if not _patterns.has(pattern):_patterns[pattern]=RegEx.create_from_string(pattern)
	return _patterns[pattern].search(line)!=null
static func problems(path:String,source:String)->Array[String]:
	var out:Array[String]=[];var file:=path.get_file();var method:=""
	var function=RegEx.create_from_string("^\\s*(?:static\\s+)?func\\s+(\\w+)\\s*\\(")
	var index:=0
	for line in source.split("\n"):
		index+=1
		if line.strip_edges().begins_with("#"):continue
		var found=function.search(line)
		if found!=null:method=found.get_string(1)
		var reason:=""
		if file!="player_combat.gd":
			# Forms owns the private table; item controller owns the existing bonus hook.
			if file not in ["player_form_rules.gd","player_item_controller.gd"] and (matches("\\bmelee_damage\\s*\\(",line) or matches("\\.call(?:_deferred)?\\(\\s*[\"']melee_damage[\"']",line)):reason="copied player damage/bonus call"
			if file!="player_form_rules.gd" and matches("return\\s+8\\s+if\\b.+\\belse\\s+4\\b",line):reason="copied private melee table"
			if matches("\\bconst\\s+(?:STRIKE_COOLDOWN|STRIKE_REACH|PLAYER_REACH|CONE_DOT|PLAYER_DAMAGE)\\s*:?=",line) and not "PlayerCombat." in line and line.strip_edges()!=CLICK_ONLY_REACH.get(file,""):reason="copied player combat constant"
			if matches("(?:strike|cooldown)",line.to_lower()) and matches("\\b0\\.45\\b",line):reason="copied player cooldown bound"
			if method in ["strike","strike_ref","_try_player_strike"] and (matches("\\b(?:var\\s+)?damage\\s*(?::\\s*int)?\\s*:?=\\s*[0-9]",line) or matches("receive_damage\\([^,]+,\\s*[0-9]",line)):reason="literal player strike damage"
		if file!="player_health.gd":
			if matches("^var\\s+(?:health|player_health)\\b.*(?:=|$)",line) and not line.strip_edges().ends_with(":"):reason="unowned health storage (forwarding property required)"
			if matches("\\.(?:player_health_owner|_health_owner)\\._current\\s*[-+*/]?=(?!=)",line):reason="write to canonical backing value outside owner"
			var raw=matches("(?:\\b(?:host|scene|guards|warriors)|get_parent\\(\\)|get_node\\([\"']Warriors[\"']\\))\\.health\\s*[-+*/]?=(?!=)",line) or matches("\\.model\\.player_health\\s*[-+*/]?=(?!=)",line)
			var bare=FORWARDERS.has(file) and matches("^\\s*health\\s*[-+*/]?=(?!=)",line)
			if (raw or bare) and method not in FORWARDERS.get(file,[]):reason="health writer outside owner API or named legacy loader"
			if matches("\\.set_deferred\\(\\s*[\"'](?:health|player_health|_current)[\"']",line):reason="deferred health write requires owner review"
			if "_standalone_player_health" in line and file!="cave_encounter_state.gd":reason="standalone model backing escaped its compatibility owner"
			if "_standalone_health" in line and file!="hive_warriors.gd":reason="standalone Hive backing escaped its compatibility owner"
		if not reason.is_empty():out.append("%s:%d: %s" % [path,index,reason])
	return out
