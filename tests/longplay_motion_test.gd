extends SceneTree
func _initialize() -> void:
	var output: Array = []
	var probe: Array = []
	var python := "python3"
	var args := PackedStringArray([ProjectSettings.globalize_path("res://tools/verify_longplay_motion.py")])
	if OS.execute("python3",["-c","import numpy, PIL"],probe,true)!=0:
		# Flatpak Godot has Python but not the analysis libraries; use the host analysis environment.
		python="flatpak-spawn"
		args=PackedStringArray(["--host","python3",ProjectSettings.globalize_path("res://tools/verify_longplay_motion.py")])
	var code := OS.execute(python,args,output,true)
	for line in output: print(line)
	if code!=0: print("FAIL longplay motion verification: Python with NumPy/Pillow required (exit ",code,")")
	quit(0 if code==0 else 1)
