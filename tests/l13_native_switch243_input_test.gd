extends "res://tests/l13_native_switch193_input_test.gd"
func main()->void:
 if not await load_owner():return
 if not await walk([[-3219.16, -1312.1775], [-3399.64, -1456.7625], [-3580.75, -1439.25], [-3752.75, -1366.5], [-3853.0, -1235.25], [-3840.865, -1073.7975000000001]],"Native lower-cavern ground to switch243",{"no_fight":true}):quit(1);return
 var binding:Node=scene.progression
 var closed:Transform3D=binding.hinges[79].transform
 await look(Vector3(-3944,-995.5,-1008));await frames(3)
 var prompt:String=scene.get_node("GenericObjects").hint.text
 await picture("l13_switch243_before")
 await tap(KEY_E);await ticks(100)
 if not require(binding.native.field("prop:243",binding.NativeHost.FIELD_BYTE25,0)==1,"Actual E at native243 runs its own group2980"):return
 if not require(not binding.hinges[79].transform.is_equal_approx(closed),"Actual source vault79 geometry moves, not just a switch flag"):return
 if not require(prompt.contains("switch"),"Source vault switch has an aimed prompt"):return
 await picture("l13_switch243_open")
 if not await disk_cycle("native243_vault79"):return
 binding=scene.progression
 if not require(binding.native.field("prop:243",binding.NativeHost.FIELD_BYTE25,0)==1 and not binding.hinges[79].transform.is_equal_approx(closed),"Actual F5/F9 retains source243 and physical vault79 pose"):return
 print("PASS native243 realW from unedited owner193 stand, realE/group2980/vault79 geometry, F5/F9 alive0resets")
 quit()
