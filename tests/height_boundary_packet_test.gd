extends SceneTree
const Boundary=preload("res://scripts/lol2/height_boundary_collision.gd")
const HASH:="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
func _initialize():run.call_deferred()
func run():
 var face:Dictionary={"kind":"source_wall","points":[[0,0,0],[10,0,0],[10,100,0],[0,100,0]]}
 var key:String=Boundary.Rule.face_key(face)
 var packet:Dictionary={"area":"L10_DC","inputs":{"map":{"sha256":HASH}},"block_face_keys":[key]}
 assert(Boundary.packet_error(packet,"L10_DC",HASH).is_empty())
 assert(not Boundary.packet_error(packet,"L12_CM",HASH).is_empty(),"Wrong area refused")
 assert(not Boundary.packet_error(packet,"L10_DC","stale").is_empty(),"Wrong map pin refused")
 var missing:Dictionary=packet.duplicate(true);missing.inputs.map.erase("sha256")
 assert(not Boundary.packet_error(missing,"L10_DC",HASH).is_empty(),"Missing pin refused")
 var selected:Dictionary=Boundary.selected_faces({"faces":[face]},Boundary.keys(packet),[])
 assert(selected.error.is_empty() and selected.faces.size()==6,"Exact source quad triangles")
 var wanted:Dictionary={key:true,"missing wall":true}
 var duplicate:Dictionary=Boundary.selected_faces({"faces":[face,face]},wanted,[])
 assert(not duplicate.error.is_empty(),"Duplicate matched faces cannot conceal a missing key")
 var map_path:="res://assets/lol2/generated/maps/L10_DC/area.json"
 var live:Dictionary=Boundary.load_packet("L10_DC",map_path)
 assert(not live.is_empty() and live.block_face_keys.size()==3532,"One complete L10 packet includes all legacy walls")
 assert(live.counts.approved_additional_keys==362 and live.counts.legacy_and_OF6_faces==3168 and live.counts.owner_named_keys==2)
 print("PASS shared boundary packet: identity/hash/matched-key refusals, exact triangles, complete3532 L10 selection")
 quit()
