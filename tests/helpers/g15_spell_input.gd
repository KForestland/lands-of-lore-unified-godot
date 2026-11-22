extends "res://tests/helpers/real_input_player.gd"
## Local spell qualification from untouched game-written checkpoints. A legacy
## loader is disclosed separately from real key/mouse actions after loading.
var failure:=false
func require(ok:bool,message:String)->bool:
 if not ok:
  failure=true;stop("G15",message);quit(1)
 return ok
func boot_legacy(path:String,pin:String,format:String,scene_file:String)->bool:
 if not require(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary clock1/60"):return false
 if not require(FileAccess.get_sha256(path)==pin,"Untouched legacy checkpoint SHA256"):return false
 var saved:=preload("res://scripts/lol2/act2_save.gd").read_save(path,format)
 if not require(saved.error.is_empty(),"Original checkpoint reader: "+str(saved.error)):return false
 scene=load(scene_file).instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene
 for tick in 2400:
  await process_frame
  if scene.ready_for_review:break
 if not require(scene.ready_for_review and scene.apply_save(saved.state).is_empty(),"Actual legacy loader applies untouched checkpoint"):return false
 use_guard=false
 await adopt()
 if not captured():await lclick();await frames(3)
 return require(hp()>0 and scene.resets==0 and not scene.flying and captured(),"Live scene after original checkpoint load")
func picture(tag:String):
 var dir:="user://tests/g15_casts/";DirAccess.make_dir_recursive_absolute(dir)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(dir+tag+".png")
func disk_cycle(tag:String)->bool:
 const Slots=preload("res://scripts/lol2/game_save.gd")
 var path:=Slots.slot_path(1)
 var prior:String=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
 await tap(KEY_F5)
 if not require(FileAccess.file_exists(path) and FileAccess.get_sha256(path)!=prior,"Actual F5 writes a new whole-game slot: "+tag):return false
 await tap(KEY_F9);await adopt()
 return require(hp()>0 and scene.resets==0,"Actual F9 restores alive: "+tag)
