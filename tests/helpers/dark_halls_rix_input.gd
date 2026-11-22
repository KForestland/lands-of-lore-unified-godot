extends "res://tests/helpers/owner_gaps_input.gd"
## Private unchanged owner packets; local source-object stands are explicit
## component aids. Creature AI/route held; Rix's actual death owner keeps ticking.
## AI hold also stops its combat clock. Advance only that transient cooldown
## through the production clock function at ordinary physics time: explicit
## component clock aid, never an instant reset or a faster clock.
func ticks(n:int):
 for i in n:
  if not paused and is_instance_valid(scene) and is_instance_valid(scene.get("creatures")) and not scene.creatures.is_physics_processing():
   scene.creatures.strike_remaining=preload("res://scripts/lol2/player_combat.gd").cooldown_tick(scene.creatures.strike_remaining,1.0/Engine.physics_ticks_per_second)
  await physics_frame
func settled():
 for i in 1800:
  await process_frame
  if scene.get("ready_for_review")==true and is_instance_valid(scene.get("starting_magic")):break
 scene.set_physics_process(false)
 for name in ["DarkHallsCreatures","DarkHallsRoute"]:
  var node:=scene.get_node_or_null(name)
  if is_instance_valid(node):
   node.set_physics_process(false)
   if name=="DarkHallsRoute":node.set_process(false)
 scene.interface_hud.set_cursor(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;await ticks(3)
func owner_rix(which:String)->bool:
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary clock"):return false
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dark_halls_rix_inputs_manifest.json"))
 var row:Dictionary=manifest.files[0 if which=="alive" else 1]
 var path:String="res://"+row.path
 if not check(FileAccess.get_sha256(path)==row.sha256,"Unchanged original owner "+which):return false
 scene=load("res://scenes/lol2/dark_halls.tscn").instantiate();root.add_child(scene);current_scene=scene;await settled()
 DirAccess.make_dir_recursive_absolute(Saves.ROOT)
 var file:=FileAccess.open(Saves.slot_path(10),FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes(path));file.close();Session.for_tree(self).last_slot=10
 return await reload()
func component_stand(point:Vector3):
 scene.player.position=point;scene.player.velocity=Vector3.ZERO # Initial local stand, not an earned route.
 await ticks(2)
func button(index:int,point:Vector2):
 for down in [true,false]:
  var e:=InputEventMouseButton.new();e.button_index=index;e.pressed=down;e.position=point;e.global_position=point
  Input.parse_input_event(e);Input.flush_buffered_events();await process_frame
func charge(code:Key,control:=false,shift:=false):
 for down in [true,false]:
  var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.ctrl_pressed=control;e.shift_pressed=shift;e.pressed=down
  Input.parse_input_event(e);Input.flush_buffered_events();await process_frame
func study(id:String)->bool:
 await key(KEY_I);await ticks(3)
 if not check(is_instance_valid(scene.inventory),"Actual inventory opens"):return false
 var list:ItemList=scene.inventory.item_list
 var index:=-1
 for i in list.item_count:
  if str(list.get_item_metadata(i))==id:index=i;break
 if not check(index>=0,"Actually picked scroll appears in inventory"):return false
 var at:Vector2
 for attempt in 40:
  at=list.get_global_transform_with_canvas()*(list.get_item_rect(index).get_center()-Vector2(0,list.get_v_scroll_bar().value))
  if list.get_global_rect().grow(-4).has_point(at):break
  await button(MOUSE_BUTTON_WHEEL_DOWN if at.y>list.get_global_rect().end.y else MOUSE_BUTTON_WHEEL_UP,list.get_global_rect().get_center())
 if not check(list.get_global_rect().grow(-4).has_point(at),"Actual wheel brings scroll into view"):return false
 await button(MOUSE_BUTTON_RIGHT,at);await ticks(2)
 if is_instance_valid(scene.inventory) and is_instance_valid(scene.inventory.item_menu):
  await button(MOUSE_BUTTON_LEFT,scene.inventory.item_menu.get_node("Choices/UseItem").get_global_rect().get_center())
 await ticks(5)
 print("RIX_STUDY inventory=",is_instance_valid(scene.inventory)," school=",scene.starting_magic.magic_state().get("spellbook")," hint=",scene.interface_hud.hint.text," menu=",scene.inventory.item_menu if is_instance_valid(scene.inventory) else null)
 return check(not is_instance_valid(scene.inventory),"Stored-scroll use closes inventory")
