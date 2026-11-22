extends SceneTree
## Complete production live-pack scan + isolated mutation probes, no game setup.
func _initialize():run.call_deferred()
func run():
 var python:=OS.get_environment("LOL2_TEST_PYTHON")
 if python.is_empty():python="python3"
 var project:=ProjectSettings.globalize_path("res://")
 for script:String in ["check_item_grant_ownership.py","test_item_grant_ownership.py"]:
  var output:Array=[]
  var code:=OS.execute(python,PackedStringArray([project+"tools/"+script]),output,true)
  for line in output:print(str(line))
  if code!=0:printerr("FAIL live-pack ownership: "+script);quit(1);return
 print("PASS item grant live-pack ownership and throwaway probes; optional removal sites disclosed")
 quit()
