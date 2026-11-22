extends RefCounted
## Existing traversal checkpoints predate the spell book and some never earned
## a Control Token. Explicit teaching fixture isolates those old route tests;
## it is not new-campaign acquisition evidence. Production grants have a gate.
static func teach_legacy_fixture(scene:Node)->bool:
 return scene.starting_magic.learn_spell_group("control")
static func cast(tree:SceneTree,scene:Node,target:int)->bool:
 for tick in 180:
  if tree.paused or float(scene.starting_magic.magic_state().get("cooldown",0))<=0:break
  await tree.process_frame
 for code in [KEY_3,KEY_Q]:
  for down in [true,false]:
   var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;event.ctrl_pressed=code==KEY_Q
   Input.parse_input_event(event);Input.flush_buffered_events();await tree.process_frame
 return scene.player_form==target and scene.curse.state.phase==0 and scene.curse.state.duration==0
