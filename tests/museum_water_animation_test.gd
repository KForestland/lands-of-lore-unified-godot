extends SceneTree
func _initialize():
 run.call_deferred()
func run():
 var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
 scene.introduction_state = "complete"
 root.add_child(scene)
 var animation = scene.surface_animation
 animation.set_process(false)
 assert(animation.sequences.size() == 1)
 var sequence: Dictionary = animation.sequences[0]
 assert(sequence.frames.size() == 10)
 var first = scene.materials["111"].albedo_texture
 animation.advance(0.125)
 assert(scene.materials["111"].albedo_texture != first)
 animation.advance(1.125)
 assert(scene.materials["111"].albedo_texture == first)
 animation.set_process(true)
 assert(scene.open_inventory())
 var elapsed: float = sequence.elapsed
 for i in range(8): await process_frame
 assert(sequence.elapsed == elapsed)
 scene.inventory.close()
 await process_frame
 await process_frame
 assert(not paused)
 print("Museum water animation passed: ten source frames, authored 8fps cycle, wraparound and inventory pause")
 quit()
