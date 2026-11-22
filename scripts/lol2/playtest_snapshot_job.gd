extends RefCounted
## Worker receives detached plain values, exactly like the autosave writer.
## Never access a scene, Node, input device or session from this function.
static func encode(writer:Script,document:Dictionary)->Dictionary:
 var started:=Time.get_ticks_usec()
 var error:String=writer.validate(document)
 if not error.is_empty():return {"error":error,"worker_us":Time.get_ticks_usec()-started}
 var encoded:=JSON.stringify(document,"",true,true)
 return {"error":"","json":encoded,"worker_us":Time.get_ticks_usec()-started,
  "bytes":encoded.to_utf8_buffer().size(),"captured_json_sha256":encoded.sha256_text()}
