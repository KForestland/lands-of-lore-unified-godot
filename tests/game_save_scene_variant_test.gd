extends SceneTree
const Save=preload("res://scripts/lol2/game_save.gd")
const Session=preload("res://scripts/lol2/game_session.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE")=="1")
	var path:="res://scenes/lol2/act2_jungle_return.tscn"
	var scene=load(path).instantiate();scene.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		if scene.get("starting_magic")!=null:break
	var doc:=Save.make_document(scene,2)
	assert(doc.area=="L4_HJ" and doc.scene==path and Save.validate(doc).is_empty())
	assert(Save.write_document(Save.slot_path(2),doc).is_empty())
	assert(Save.load(self,2).is_empty());await scene_changed
	current_scene.process_mode=Node.PROCESS_MODE_DISABLED
	for i in 1500:
		await process_frame
		if Session.for_tree(self).pending_resume.is_empty() and current_scene.get("starting_magic")!=null:break
	assert(current_scene.scene_file_path==path and Session.for_tree(self).pending_resume.is_empty(),"actual L4 return scene survives slots")
	current_scene.free();current_scene=null
	print("PASS L4 normal/Act2-return scene whitelist retains the actual saved variant")
	quit()
