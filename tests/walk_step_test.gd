extends SceneTree
const Step = preload("res://scripts/lol2/walk_step.gd")
func _initialize():
 run.call_deferred()
func box(parent: Node3D, position: Vector3, size: Vector3):
 var body := StaticBody3D.new()
 var collider := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 shape.size = size
 collider.shape = shape
 body.add_child(collider)
 parent.add_child(body)
 body.position = position
func run():
 Engine.time_scale = 1.0
 for kind in ["step","wall","ceiling"]:
  var world := Node3D.new()
  root.add_child(world)
  box(world,Vector3(0,-5,0),Vector3(200,10,200))
  var height := 50.0 if kind == "wall" else 30.0
  box(world,Vector3(0,height/2,-45),Vector3(60,height,60))
  if kind == "ceiling": box(world,Vector3(0,90,-45),Vector3(60,10,60))
  var player := CharacterBody3D.new()
  player.safe_margin = 0.05
  var shape := CapsuleShape3D.new()
  shape.radius = 8
  shape.height = 64
  var collider := CollisionShape3D.new()
  collider.shape = shape
  player.add_child(collider)
  world.add_child(player)
  player.position = Vector3(0,33,15)
  for i in range(150):
   await physics_frame
   var dt := player.get_physics_process_delta_time()
   player.velocity = Vector3(0,-80,-40 if i > 10 else 0)
   if Step.try_step(player,Vector3(0,0,player.velocity.z)*dt): player.velocity.z = 0
   player.move_and_slide()
   if player.position.z < -40: break
  print(kind, " ", player.position)
  if kind == "step": assert(player.position.z < -25 and player.position.y > 55)
  else: assert(player.position.z > -16 and player.position.y < 40)
  world.free()
  await physics_frame
 print("Step collision passed: 30-unit riser traversed; 50-unit wall and insufficient headroom block")
 quit()
