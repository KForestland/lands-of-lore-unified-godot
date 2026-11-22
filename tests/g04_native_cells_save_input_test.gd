extends "res://tests/g04_floor_input_test.gd"
## VM storage fixture, not a player-earned script mutation: synthetic proven
## opcode199/204 arms seed otherwise unhosted records, actual F5/F9 stores them.
func run():
 scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene;await settled()
 var commands:Array=[]
 for raw:String in ["c700000034010000","cc000700feff0900","cc00000003003412"]:
  var bytes:=raw.hex_decode()
  commands.append({"opcode":int(bytes[0]),"kind":int(bytes[1]),"target":bytes.decode_u16(2),"file_offset":650006+commands.size()*8,"bytes":bytes,"raw_hex":raw,"group":65000,"stream":1})
 scene.progression.native.groups["s1:65000"]=commands
 scene.progression.native.group_files["s1:65000"]=650000
 var result:Dictionary=scene.progression.native.execute_group(1,65000)
 if not check(result.status=="ran","Synthetic VM vector really executes the proven199/204 arms"):return
 await key(KEY_F5);await ticks(2)
 var saved:=Saves.read_document(Saves.slot_path(1))
 if not check(saved.error.is_empty(),"Actual F5 writes script-cell fixture"):return
 if not check(saved.state.native_globals.locals_e58.get("52",-1)==1 and saved.state.native_bank.L14_HT.locals_e58.is_empty(),"Global199 byte has exactly one save owner"):return
 if not await reload():return
 var vm:RefCounted=scene.progression.native
 if not check(vm.locals_e58.get(52,-1)==1 and vm.field("0x22d0c:7","byte_0x22",-1)==9 and vm.field("0x22d08:3","word_0x00",-1)==0x1234 and vm.field("0x22d08:3","bit_0x05_0x40",-1)==1,"F9 retains global199 and both204 record layouts"):return
 if not check(not vm.groups.has("s1:65000"),"The synthetic event does not exist after reload; restoration cannot re-fire it"):return
 print("PASS G04 actualF5/F9 stores global199 and both204 layouts, no event exists to replay; VM seeding explicitly synthetic, not player-earned mutation")
 quit()
