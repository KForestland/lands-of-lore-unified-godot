extends "res://tests/l8_temple_earned_test.gd"
const Herb=preload("res://scripts/lol2/l8_herbalist.gd")
func continue_village(scene: Node)->void:
 var journey=scene.get_node("L8Journey")
 check(not journey.interact("herb:sap").ok,"herbalist unavailable before admission")
 if not check(journey.interact("show_guard",State.BLADE).ok,"earned admission"):return
 var path:="res://tmp/l8_herbalist_earned_save.json"
 for kind in Herb.KINDS:
  for n in 2:
   if not check(journey.interact("herb:"+kind).ok,"take "+kind+str(n)):return
   var error:String=scene._quicksave_unrecorded(path)
   if not check(error.is_empty(),"save pickup: "+error):return
   error=scene._quickload_unrecorded(path)
   if not check(error.is_empty(),"reload pickup: "+error):return
  check(not journey.interact("herb:"+kind).ok,"third fresh-visit pickup refused")
 check(scene.quest_state.l8_herbalist.collected.size()==6,"six distinct first-visit grants persisted")
 for id in Herb.ids():check(scene.carried_collected.count(id)==1,"one instance "+id)
 var full:Array=[]
 for i in 64:full.append("capacity:%d"%i)
 var fresh:=Herb.initial()
 check(not Herb.pick(fresh,full,"sap",true).ok and fresh==Herb.initial(),"full inventory cannot consume pickup entitlement")
 var news=journey.backroom
 check(news.available(),"all thirteen original voice assets staged")
 var before:Array=scene.carried_collected.duplicate()
 for sequence in news.SEQUENCES:
  if not check(journey.interact("backroom").ok,"start doorway sequence"):return
  for line in sequence:
   check(news.loaded_line==line,"original clip order "+str(line))
   var error:String=scene._quicksave_unrecorded(path)
   if not check(error.is_empty(),"save active doorway: "+error):return
   error=scene._quickload_unrecorded(path)
   if not check(error.is_empty(),"reload active doorway: "+error):return
   check(news.state().active,"active conversation persisted")
   if line==225:news._process(float(news.manifest[line].duration)+0.01)
   else:check(news.skip_line(),"skip original voice line")
  check(not news.state().active,"sequence completes")
  check(scene._quicksave_unrecorded(path).is_empty(),"save finished sequence")
  check(scene._quickload_unrecorded(path).is_empty(),"reload finished sequence")
 check(news.state().completed==3,"all three source doorway visits persisted")
 check(not journey.interact("backroom").ok,"fourth visit cannot replay news")
 check(scene.carried_collected==before,"news leaves inventory unchanged")
 DirAccess.remove_absolute(path)
 if failures==0:print("PASS earned L8 herbalist: actual guard admission, six pickups, save/reload each, duplicate/full refusal. Original doorway voices225..237, active/completed save-reload, no item reward; later flag206 bonus and original video deferred.")
