extends SceneTree
## Source-only census and throwaway mutation probes; no gameplay state/setup.
func _initialize():run.call_deferred()
func run():
	var python:=OS.get_environment("LOL2_TEST_PYTHON")
	if python.is_empty():python="python3"
	var project:=ProjectSettings.globalize_path("res://")
	for args in [[project+"tools/check_item_grant_census.py","--root",project],
		[project+"tools/test_item_grant_census.py"]]:
		var output:Array=[]
		var result:=OS.execute(python,PackedStringArray(args),output,true)
		for part in output:print(str(part))
		if result!=0:printerr("FAIL item grant census: Python check/probes returned ",result);quit(1);return
	print("PASS item grant source census and mutation probes; production callers unchanged")
	quit()
