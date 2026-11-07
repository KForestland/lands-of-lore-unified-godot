extends SceneTree
const Movie=preload("res://scripts/lol2/cave_guard_movie.gd")
const State=preload("res://scripts/lol2/cave_guard_sequence_state.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0.16,0.17,0.19);world.add_child(environment)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(158,-240,-16400);camera.look_at(Vector3(158,-240,-16640));camera.current=true;camera.cull_mask=2
	var movie:=Movie.new();world.add_child(movie);var src:=State.source();assert(movie.setup(src,camera,Vector3.ZERO).is_empty())
	var s:=State.initial();movie.show_state(s,true,true);assert(not movie.visible and not movie.voice.playing)
	State.enter(s,src,Vector2(-9,-16615),-285,true,0);movie.show_state(s,true,true);assert(movie.visible and not movie.voice.playing)
	assert(absf(movie.picture.mesh.size.x-50.75)<0.0001 and absf(movie.picture.mesh.size.y-81.9)<0.0001)
	State.rendered(s,src)
	for i in range(6):
		movie.show_state(s,true,true)
		await physics_frame;await physics_frame
		assert(movie.current_selector==i and movie.voice.playing)
		if i==0 and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("user://tests")
			assert(root.get_texture().get_image().save_png("user://tests/cave_guard_movie.png")==OK)
		movie.show_state(s,true,false);assert(movie.voice.stream_paused)
		movie.show_state(s,true,true,true);assert(not movie.voice.stream_paused)
		var clip: Dictionary=src.clips[i];var video_end: float=float(clip.count)/clip.fps
		State.advance(s,src,video_end);assert(s.phase=="playing" and s.selector==i)
		movie.show_state(s,true,true,true);assert(movie.current_frame==int(clip.count)-1 and movie.voice.playing)
		State.advance(s,src,State.duration(src,i)-s.elapsed)
	movie.show_state(s,true,true);assert(s.phase=="complete" and movie.visible and not movie.voice.playing)
	movie.show_state(s,false,true);assert(not movie.visible)
	print("PASS movie component:430 frame/six WAV hashes, original canvas crop, pause/resume, final-frame audio tail, completion stop and removal. Visual screen/collision admission not tested headless.")
	quit()
