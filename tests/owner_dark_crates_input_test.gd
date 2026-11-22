extends "res://tests/helpers/act1_owner_object_input.gd"
## Original primed/moved448 owner save, actual E/S/1/Q/Control-Q/F5/F9.
## Enemy/world-route clocks held; no pose, health, pack or spell fixture.
## The owner has2HP: two actual Healing casts before the blast keep him alive.
func highest_visible(node:Node)->float:
 var top:=-INF
 if node is MeshInstance3D and node.name!="Crystal" and node.is_visible_in_tree():
  for surface in node.mesh.get_surface_count():
   for point:Vector3 in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:top=maxf(top,point.y)
 for child in node.get_children():top=maxf(top,highest_visible(child))
 return top
func run():
 if not await owner("L7_DH","dh_box"):return
 var crates:Node=scene.crates
 if not check(crates.state_of(448)==1 and crates.crystal_on(448),"Original owner input already primed448"):return
 await look(crates.center_of(448));await key(KEY_E);await frame("dh_primed_box")
 if not check(highest_visible(crates.visuals[448])<770,"Primed source crate has its closed cap removed so the crystal can be seen"):return
 if not check("Spark" in scene.interface_hud.hint.text,"E on the primed box names the next action"):return
 await key(KEY_1);await key(KEY_Q);await ticks(3)
 if not check(crates.state_of(448)==1 and "stronger" in scene.interface_hud.hint.text,"Weak Spark retains the box and says a stronger Spark is needed"):return
 scene.set_physics_process(true);await hold_key(KEY_S,150);scene.set_physics_process(false);await ticks(35)
 await key(KEY_2);await key(KEY_Q);await ticks(40);await key(KEY_Q);await ticks(40);await key(KEY_1)
 await look(crates.center_of(448))
 var ray:=PhysicsRayQueryParameters3D.create(scene.camera.global_position,crates.center_of(448),3,[scene.player.get_rid()])
 var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
 print("BOX before blast player=",scene.player.position," crate=",crates.center_of(448)," hp=",scene.starting_magic.health()," hit=",hit.get("collider")," mana=",scene.starting_magic.magic_state().player.mana)
 await modified_q();await ticks(3)
 print("BOX after blast state=",crates.state_of(448)," door=",crates.door_blocking()," hp=",scene.starting_magic.health()," notice=",scene.starting_magic.notice)
 if not check(crates.state_of(448)==2 and not crates.door_blocking() and scene.starting_magic.health()>0,"Real level3 Spark explodes the exposed box and removes the steel door"):return
 await key(KEY_F5);await ticks(3)
 var saved:Dictionary=Saves.read_document(Saves.slot_path(10))
 if not check(saved.error.is_empty(),"Player can save after the explosion"):return
 if not await reload():return
 if not check(scene.crates.state_of(448)==2 and not scene.crates.door_blocking(),"F9 keeps exploded box and open steel door"):return
 print("PASS owner box448 exposed source cap/crystal, E explanation, weak Spark refusal, actual retreat/Healing and Control-Q explosion, F5/F9; untouched owner save, held actors, no pose edits")
 quit()
