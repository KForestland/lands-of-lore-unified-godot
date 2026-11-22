extends SceneTree
const Crates=preload("res://scripts/lol2/dark_halls_crates.gd")
func _initialize():
 var prefix:="The blast reaches you here. Dragon's Blood through the slot gives you time to get clear; "
 for row in [[26,30,"Spark from here costs about 26 health."],[26,26,"Spark from here would kill you."],[26,1,"Spark from here would kill you."],[9,30,"Spark from here costs about 9 health."]]:
  if Crates.slot_blast_advice(row[0],row[1])!=prefix+row[2]:push_error("Truthful measured973 cost/lethal sentence");quit(1);return
 print("PASS measured damage and current health drive973 cost/lethal line, no invented shelter")
 quit()
