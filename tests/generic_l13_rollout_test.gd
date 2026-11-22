extends "res://tests/generic_l8_rollout_test.gd"
## Rendered Citadel components on earned C15; supplied clear grounded stands,
## held root/NPC clocks, actual mouse/E/left/F5/F9. No earned-route claim.
func item_owner(_id:int)->Node:return scene.act2_items
func identity(id:int)->String:return "act2:L13_RC:item%d"%id
func item_point(id:int)->Vector3:return scene.act2_items.aim_point(identity(id))
func target_matches(id:int)->bool:return scene.act2_items.target()==identity(id)
func native_graph_intact(actions:Node)->bool:
 var expected:Array=[]
 for row:Dictionary in preload("res://scripts/lol2/generic_object_actions.gd").ROWS.L13_RC:expected.append(row.ref)
 var actual:Array=[]
 for row:Dictionary in actions.entries:
  if row.ref in actual:return false
  actual.append(row.ref)
 expected.sort();actual.sort()
 return actual==expected and actual.count("prop:250")==1 and actual.count("control:53")==1 and actions.find_children("GenericWorld","",false,false).size()==1
func run():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary Citadel component clock1/60"):return
 folder="user://tests/generic_l13_rollout";DirAccess.make_dir_recursive_absolute(folder)
 if not await boot("res://scenes/lol2/maps/L13_RC.tscn","res://assets/lol2/generated/playtest_starts/c15_l13_rc.json","21db5d3f9596650ad96df594e103eca6eb79dea299d91e585e610b146622b948","lol2-restoration-map-L13_RC"):return
 var actions:Node=scene.get_node("GenericObjects")
 # Main-chain vault input remains on the original native owner. Its public
 # entries/pad API survives the shared bridge's child registration.
 if not await pose(Vector3(-4593,-1008,1741),Vector3(-4534,-995.5,1767)):return
 await aim(Vector3(-4534,-995.5,1767))
 if not check(actions.aimed().get("row",{}).get("ref")=="prop:250","Actual existing native vault target"):return
 var before:Transform3D=scene.progression.hinges[84].transform
 await click()
 for tick in 150:await physics_frame
 if not check(scene.progression.native.field("prop:250",scene.progression.NativeHost.FIELD_BYTE25,0)==1 and not scene.progression.hinges[84].transform.is_equal_approx(before),"Actual left uses native250 and moves84 without a new action shortcut"):return
 if not check(native_graph_intact(actions),"One existing native root/pad owner and one shared bridge child"):return
 receipts.append({"ref":"prop:250","input":"left","stand":str(scene.player.position)})
 await shot("vault_open")
 for id in [0,3]:
  if not await item_stand(id):return
  if not check(actions.would_use(),"Root use priority delegates to the eligible pickup child"):return
  if id==0:await click()
  else:await key(KEY_E)
  if not check(scene.carried_collected.count(identity(id))==1,"Actual left/E takes original Citadel item%d"%id):return
  if id==0 and not check(not scene.interface_hud.attack_swing.icon.visible,"Usable pickup left wins over attack"):return
  receipts.append({"ref":"item:%d"%id,"input":"left" if id==0 else "E","stand":str(scene.player.position)})
  await shot("taken%d"%id)
 await key(KEY_F5)
 if not await load_slot():return
 if not check(native_graph_intact(scene.get_node("GenericObjects")),"F9 keeps native root plus shared child"):return
 for id in [0,3]:
  if not check(scene.carried_collected.count(identity(id))==1 and not scene.act2_items.sprites[identity(id)].visible,"F9 preserves original pickup%d"%id):return
 if not check(scene.progression.native.field("prop:250",scene.progression.NativeHost.FIELD_BYTE25,0)==1 and scene.progression.native.field("movable:84",scene.progression.NativeHost.FIELD_TRAVEL,0)==95 and scene.resets==0,"G04 keeps native vault state and no recovery"):return
 var file:=FileAccess.open(folder+"/receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify(receipts,"  "));file.close()
 print("PASS G03 L13 three rendered native vault/pickup inputs, root/pad API intact, usable left priority and G04 F5/F9; supplied grounded stands")
 quit()
