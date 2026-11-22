extends RefCounted
## The original56 stable note IDs, independently extracted from pre-lesson
## de0cbb6. Later approved lessons may append; losing an old note still fails.
static func preserved(current:Dictionary)->bool:
 const PATH="res://tests/fixtures/journal_original_56.json"
 assert(FileAccess.get_sha256(PATH)=="8e37001a0291af2f2fe22fe86371b2d67e89c0fd58a9b8c18352db7da7c27e8f")
 var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 assert(baseline.head=="de0cbb6e94beeeaa50d8161203be71a62d057536" and baseline.ids.size()==56)
 for id in baseline.ids:
  if not current.has(id) or not current[id] is String or str(current[id]).is_empty():return false
 return true
