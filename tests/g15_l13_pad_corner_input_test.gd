extends "res://tests/helpers/g15_world_spell_input.gd"
func _initialize():main.call_deferred()
func pad_runs()->int:
 var count:=0
 for row:Dictionary in scene.progression.route_log:
  if row.get("object","")!="control:53" or int(row.get("event",-1))!=5:continue
  for result:Dictionary in row.get("results",[]):
   if int(result.group)==8134 and result.status=="ran":count+=1
 return count
func main():
 if not await boot_map("L13_RC"):return
 for row in [["robot_corner",Vector3(-4953,-867,1711)],["northwest",Vector3(-4976,-868,1693)],["northeast",Vector3(-4912,-868,1693)],["southeast",Vector3(-4912,-868,1725)],["southwest",Vector3(-4976,-868,1725)]]:
  var actions:Node=scene.get_node("GenericObjects")
  actions.set_physics_process(false) # Supplied-stand bootstrap only; discarded by actual F9.
  if not await stand_at(row[1]):return
  actions.restore();actions.set_physics_process(true)
  await ticks(30)
  if not require(Vector2(pos().x-row[1].x,pos().z-row[1].z).length()<0.5,"Stationary bootstrap does not fire pad"):return
  if not await disk_cycle("g15_pad_"+str(row[0])+" at="+str(pos())+" on_floor="+str(scene.player.is_on_floor())):return
  var saved:Vector3=pos()
  var before:int=pad_runs()
  print("PAD loaded ",row[0]," pos=",saved," on_floor=",scene.player.is_on_floor()," original polygon=",scene.get_node("GenericObjects").on_pad(scene.get_node("GenericObjects").entries.filter(func(e):return int(e.event)==5)[0]))
  await ticks(90)
  if not require(Vector2(pos().x-saved.x,pos().z-saved.z).length()<0.1 and absf(pos().y+868)<2,"Real F9 on pad remains stationary, alive and not teleported"):return
  if not await look(Vector3(-4944,pos().y+24,1709)):quit(1);return
  if not require(Vector2(pos().x-saved.x,pos().z-saved.z).length()<0.1,"Looking on pad does not count as walking"):return
  if not require(pad_runs()==before,"Stationary reload and looking do not invoke native8134"):return
  await picture("g15_pad_"+str(row[0])+"_before")
  key_event(KEY_W,true);await ticks(4);key_event(KEY_W,false)
  await ticks(45)
  if not require(Vector2(pos().x+3258,pos().z-5589).length()<12 and absf(pos().y-32)<2 and scene.player.is_on_floor() and hp()>0 and scene.resets==0,"Real W anywhere on pad fires native8134 and lands living at1166: "+str(row[0])+" at="+str(pos())+" on_floor="+str(scene.player.is_on_floor())):return
  if not require(pad_runs()==before+1,"Real W invokes native8134 exactly once: "+str(row[0])):return
  print("PAD native8134 once ",row[0]," landing=",pos()," resets=",scene.resets)
  await picture("g15_pad_"+str(row[0])+"_landing")
 print("PASS L13 control53 real F5/F9 stationary/looking negatives then W on robot corner and all four physical pad corners; native landing/resets0, supplied stand/controller-bootstrap aids disclosed")
 quit()
