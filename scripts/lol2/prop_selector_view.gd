extends Node3D
## Original selector artwork for the pilot's seven props. The existing owners
## retain transactions, receivers and saves; this node owns only presentation.
const ROOT:="res://assets/lol2/generated/generic_props/"
static var packs:Dictionary={}
var host:Node3D
var pack:Dictionary
var folder:String
var template:int
var selector:=-1
var elapsed:=0.0
var mesh:MeshInstance3D
var material:StandardMaterial3D
var frames:Array[Texture2D]=[]
var textures:Dictionary={}
static func attach(map:Node3D,area:String,record:int)->Node3D:
 var path:String=ROOT+area+"/selectors.json"
 if not FileAccess.file_exists(path) or not map.prop_placements.has(record):return null
 if not packs.has(area):packs[area]=JSON.parse_string(FileAccess.get_file_as_string(path))
 var data:Dictionary=packs[area]
 if not data.get("objects",{}).has(str(record)):return null
 var node:Node3D=load("res://scripts/lol2/prop_selector_view.gd").new()
 node.host=map;node.folder=path.get_base_dir();node.pack=data
 node.template=int(data.objects[str(record)]);node.name="PropSelector%d"%record
 map.add_child(node)
 node.setup(record)
 return node
func setup(record:int):
 var placement:Array=host.prop_placements[record]
 var multi:MultiMesh=placement[0]
 position=placement[2]
 # Standard fixed-Y billboards ignore instance scale unless keep_scale is set.
 # Clone only this batch's primitive/material so its zero-sized old instance
 # really disappears, as it already does in the sector-light shader.
 if multi.mesh is PrimitiveMesh and multi.mesh.material is StandardMaterial3D:
  var base:PrimitiveMesh=multi.mesh.duplicate()
  base.material=base.material.duplicate()
  base.material.billboard_keep_scale=true
  multi.mesh=base
 # Hide only this original batch instance; other objects sharing the material
 # and its native position/bounds remain unchanged.
 multi.set_instance_transform(int(placement[1]),Transform3D(Basis().scaled(Vector3.ZERO),position))
 mesh=MeshInstance3D.new();add_child(mesh)
 material=StandardMaterial3D.new()
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
 material.cull_mode=BaseMaterial3D.CULL_DISABLED
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
 material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 mesh.material_override=material
 var lighting:Node=host.get("sector_lighting")
 if lighting!=null:
  mesh.material_override=lighting.convert_material(material,lighting.Night.SOURCE_UNIFORM,lighting.at_point(position))
 # Preserve the original batch's visibility sector when the area uses islands.
 if host.get("cluster_meshes") is Dictionary:
  for nodes in host.cluster_meshes.values():
   var owns_sector:=false
   for node in nodes:
    if node is MultiMeshInstance3D and node.multimesh==multi:owns_sector=true;break
   if owns_sector:nodes.append(mesh)
 show_selector(0)
func texture(path:String)->Texture2D:
 if not textures.has(path):textures[path]=ImageTexture.create_from_image(Image.load_from_file(folder+"/"+path))
 return textures[path]
func show_selector(value:int):
 if selector==value:return
 var key:String="%d:%d"%[template,value]
 assert(pack.selectors.has(key),"Pilot selector must have produced artwork")
 selector=value;elapsed=0.0;frames.clear()
 var row:Dictionary=pack.selectors[key]
 var quad:=QuadMesh.new()
 quad.size=Vector2(float(row.right)-float(row.left),float(row.state_height)-float(row.top_trim)-float(row.bottom))
 quad.center_offset=Vector3((float(row.left)+float(row.right))/2,(float(row.bottom)+float(row.state_height)-float(row.top_trim))/2,0)
 mesh.mesh=quad
 var flip:int=int(row.frame_flags)&0xC0
 material.uv1_scale=Vector3(-1 if flip&0x40 else 1,-1 if flip&0x80 else 1,1)
 material.uv1_offset=Vector3(1 if flip&0x40 else 0,1 if flip&0x80 else 0,0)
 var animation:Dictionary=pack.animations.get(row.material,{})
 for path in animation.get("frames",[pack.materials[row.material]]):frames.append(texture(path))
 material.albedo_texture=frames[0]
func _process(delta:float):
 if frames.size()<2 or host.starting_magic==null or not host.starting_magic.world_active():return
 # Existing producer's provisional10fps, explicitly a modern visual cadence.
 elapsed+=delta;material.albedo_texture=frames[int(elapsed*10)%frames.size()]
