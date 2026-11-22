extends SceneTree
const Fit = preload("res://scripts/lol2/act2_body_fit.gd")
const Body = preload("res://scripts/lol2/player_form_body.gd")
class Nav extends RefCounted:
	var floor_decks := {}
	var mover_bodies := {}
	var regions := []
	func region_at(point:Vector3)->int:return 0 if point.z<80 else 1 if point.z<160 else 2
class Host extends Node3D:
	var player:CharacterBody3D
	var camera:Camera3D
	var nav_regions:=[]
	var collision_links:Dictionary
	var region_collision_enabled:=false
	var progression:=Nav.new()
var failed:=false
func _initialize():run.call_deferred()
func check(ok:bool,text:String)->bool:
	if not ok:failed=true;push_error(text);quit(1)
	return ok
func box_faces(at:Vector3,size:Vector3)->PackedVector3Array:
	var p:=[]
	for x in [-0.5,0.5]:
		for y in [-0.5,0.5]:
			for z in [-0.5,0.5]:p.append(at+Vector3(x*size.x,y*size.y,z*size.z))
	var faces:=PackedVector3Array()
	for quad in [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]:
		for i in [0,1,2,0,2,3]:faces.append(p[quad[i]])
	return faces
func fixture(width:float,height:float,linked:bool,contact:int,form:int)->Host:
	var host:=Host.new();root.add_child(host)
	for rect in [Rect2(-100,-50,200,130),Rect2(-width/2,80,width,80),Rect2(-100,160,200,100)]:
		host.nav_regions.append([[[rect.position.x,rect.position.y],[rect.end.x,rect.position.y],[rect.end.x,rect.end.y],[rect.position.x,rect.end.y]],0,0,[]])
	host.collision_links={0:{1:true},1:{0:true,2:true},2:{1:true}} if linked else {0:{},1:{},2:{}}
	var terrain:=StaticBody3D.new();terrain.name="RegionCollision"
	var faces:=box_faces(Vector3(0,-2,100),Vector3(220,4,320))
	if width<100:
		faces.append_array(box_faces(Vector3(-width/2-4,50,120),Vector3(8,100,80)))
		faces.append_array(box_faces(Vector3(width/2+4,50,120),Vector3(8,100,80)))
	# A tall roof prevents the mover from legitimately stepping onto the test obstacle.
	faces.append_array(box_faces(Vector3(0,height+50,120),Vector3(width+16,100,80)))
	var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces)
	var collider:=CollisionShape3D.new();collider.shape=shape;terrain.add_child(collider);host.add_child(terrain)
	host.player=CharacterBody3D.new();host.player.safe_margin=0.05;host.player.collision_mask=1|2|256
	var body_shape:=CollisionShape3D.new();host.player.add_child(body_shape);host.add_child(host.player)
	host.camera=Camera3D.new();host.player.add_child(host.camera);host.player.position=Vector3(0,32.05,0)
	Body.apply(host.player,host.camera,form,false)
	if contact>0:
		var target:PhysicsBody3D
		if contact==2:
			target=CharacterBody3D.new();target.name="Creature"
			target.collision_mask=1;target.add_collision_exception_with(terrain)
			var cap:=CapsuleShape3D.new();cap.radius=6;cap.height=16
			var cap_shape:=CollisionShape3D.new();cap_shape.shape=cap;cap_shape.position.y=8;target.add_child(cap_shape)
		else:
			target=StaticBody3D.new();target.name="Prop"
			var cube:=BoxShape3D.new();cube.size=Vector3(10,80,10)
			var cube_shape:=CollisionShape3D.new();cube_shape.shape=cube;cube_shape.position.y=40;target.add_child(cube_shape)
		target.collision_layer=contact;target.position=Vector3(0,0,130);host.add_child(target)
		if contact==1:host.progression.mover_bodies[0]=target
	return host
func case_run(width:float,height:float,linked:bool,contact:int,should_cross:bool,form:int=0)->bool:
	var host:=fixture(width,height,linked,contact,form)
	for i in 3:await physics_frame
	var fit=Fit.new();fit.setup(host)
	var reference_limit:=0.0
	var saw_fit:=false;var smallest_h:float=Body.HEIGHTS[form];var smallest_r:float=Body.RADII[form]
	for tick in 170:
		var state:Dictionary=fit.begin(Vector3(0,0,1),2.0)
		var physics_offset:Vector3=PhysicsServer3D.body_get_shape_transform(host.player.get_rid(),0).origin
		if not check(physics_offset.is_equal_approx(host.player.get_child(0).position),"Physics server received fitted foot-anchored offset before movement"):return false
		saw_fit=saw_fit or fit.active
		smallest_h=minf(smallest_h,fit.profile.y);smallest_r=minf(smallest_r,fit.profile.x)
		host.player.velocity=Vector3(0,-1,80);host.player.move_and_slide();fit.finish(state)
		if not check(host.player.get_child(0).shape.radius==Body.RADII[form] and host.player.get_child(0).shape.height==Body.HEIGHTS[form],"Original form contact shape restored after every world move"):return false
		await physics_frame
	var crossed:bool=host.player.position.z>190
	if not check(crossed==should_cross,"Controlled corridor crossing width%f height%f linked%s contact%d at%s"%[width,height,linked,contact,host.player.position]):return false
	if not check(smallest_h>=8.0 and smallest_r>=8.0,"Minimum8 maintained"):return false
	if should_cross:
		if not check((saw_fit or form==2) and not fit.active and is_equal_approx(host.camera.position.y,Body.EYES[form]-Body.FOOT_OFFSET),"Body and eye restore after narrow corridor"):return false
	if contact>0:
		# Capsule ends can make the live body rise slightly on contact. Compare the engine's ordinary
		# form at the final physical height, using a short sweep to avoid long-sweep quantisation.
		var terrain:PhysicsBody3D=host.get_node("RegionCollision")
		host.player.add_collision_exception_with(terrain)
		var reference_origin:=host.player.global_transform;reference_origin.origin.z-=4.0
		var reference:=KinematicCollision3D.new()
		if not check(host.player.test_move(reference_origin,Vector3(0,0,8),reference,host.player.safe_margin),"Final-pose ordinary form reference still finds the contact"):return false
		reference_limit=reference_origin.origin.z+reference.get_travel().z
		host.player.remove_collision_exception_with(terrain)
		print("CONTACT actual ",host.player.position," reference ",reference_limit," clamps ",fit.contact_clamps," profile ",fit.profile)
		if not check(absf(host.player.position.z-reference_limit)<0.15 and fit.contact_clamps>0,"Original form contact matches independent full-body physics reference (including capsule end curvature)"):return false
		if contact==2:
			var creature:CharacterBody3D=host.get_node("Creature")
			var from:=creature.global_transform;from.origin.z=160
			var collision:=KinematicCollision3D.new()
			if not check(creature.test_move(from,Vector3(0,0,-80),collision) and collision.get_collider()==host.player,"Incoming creature sees original full player collision shape"):return false
	print("CONTRACT form",form," width",width," height",height," link",linked," contact",contact," reached",host.player.position," minima",smallest_r,",",smallest_h)
	host.queue_free();await process_frame;await process_frame
	return true
func run():
	for spec in [[22.0,20.0,true,0,true],[22.0,100.0,true,2,false],[22.0,100.0,true,256,false],[22.0,100.0,true,1,false],[22.0,20.0,false,0,false],[12.0,100.0,true,0,false],[100.0,6.0,true,0,false]]:
		if not await case_run(spec[0],spec[1],spec[2],spec[3],spec[4]):return
	for spec in [[22.0,20.0,true,0,true,1],[22.0,100.0,true,2,false,1],[22.0,100.0,true,256,false,1],[22.0,20.0,true,0,true,2]]:
		if not await case_run(spec[0],spec[1],spec[2],spec[3],spec[4],spec[5]):return
	print("PASS act2_body_fit_contract: linked narrow/low corridor, min8 bounds, unlinked refusal, full incoming/outgoing creature/prop/mover contacts and restoration")
	quit()
