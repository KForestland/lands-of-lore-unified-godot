extends SceneTree
## K85: explicit invocation census includes dynamic call("set_health", ...),
## excludes definitions, has_method strings and the separate executioner_set_health.
const EXPECTED="res://tests/fixtures/player_health_callers_d5da60a.json"
func _initialize():run.call_deferred()
func run():
	var pinned:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
	var direct=RegEx.create_from_string("\\bset_health\\s*\\(")
	var indirect=RegEx.create_from_string("\\.call(?:_deferred)?\\s*\\(\\s*[\"']set_health[\"']\\s*,")
	var actual:Dictionary={};var dynamic_calls:=0
	for file in DirAccess.get_files_at("res://scripts/lol2"):
		if not file.ends_with(".gd"):continue
		var count:=0
		for line in FileAccess.get_file_as_string("res://scripts/lol2/"+file).split("\n"):
			if line.strip_edges().begins_with("#"):continue
			for hit in direct.search_all(line):
				if not line.substr(0,hit.get_start()).strip_edges().ends_with("func"):count+=1
			var calls=indirect.search_all(line).size();count+=calls;dynamic_calls+=calls
		if count>0:actual[file]=count
	assert(actual.size()==pinned.calls_per_file.size(),"facade caller file set changed")
	for file in actual:
		assert(pinned.calls_per_file.has(file) and int(actual[file])==int(pinned.calls_per_file[file]),"audited facade invocation paths changed: "+JSON.stringify(actual))
	var total:=0
	for count in actual.values():total+=int(count)
	assert(total==26 and actual.size()==21 and dynamic_calls==1 and actual["dark_halls_crates.gd"]==1)
	print("PASS health census: 26 facade invocation sites /21 files, including one dynamic crate call; unrelated executioner_set_health excluded")
	quit()
