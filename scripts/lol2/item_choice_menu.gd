extends RefCounted
## Shared give/choose presentation. Metadata is an original owned identity;
## grouping only changes rows, never the pack or an actor's acceptance rules.
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
static var textures:Dictionary={}
static func label(id:String)->String:
 var names:={75:"Spark Scroll",148:"Healing Scroll",149:"Summon Scroll",150:"Mists of Doom Scroll",151:"Prism Scroll"}
 var text:String=names.get(Catalog.definition(id),Catalog.label(id))
 return text if not text.is_empty() else "Unidentified item"
static func key(id:String,host:Node)->String:
 var definition:int=Catalog.definition(id)
 var group:String=str(definition) if definition>=0 else id
 # Distinct modern quest variants share a native definition, but their owner
 # accepts a particular identity. Keep those choices separate.
 if id in [Catalog.Monastery.FLUTE,"act2:L12_CM:blue_bow"]:group+=":"+id
 var effects:Variant=host.get("item_effects") if is_instance_valid(host) else null
 if Catalog.use_kind(id)=="fire_crystal" and is_instance_valid(effects):group+=":"+str(effects.crystal_charges(id))
 return group
static func bound(menu:OptionButton):
 if not menu.is_inside_tree():return
 menu.get_tree().root.gui_embed_subwindows=true
 var popup:PopupMenu=menu.get_popup()
 var view:Vector2=menu.get_viewport_rect().size
 popup.max_size=Vector2i(view-Vector2(24,24)).max(Vector2i.ONE)
 if popup.visible:finish_popup(menu)
static func finish_popup(menu:OptionButton):
 var popup:PopupMenu=menu.get_popup()
 if not popup.visible:
  popup.wrap_controls=true
  return
 # OptionButton supplies a zero-height popup rectangle after about_to_popup.
 # Constrain the visible window after that native initialization, preserving
 # its real ScrollContainer, keyboard navigation and original item metadata.
 var wanted:Vector2=popup.get_contents_minimum_size()*popup.content_scale_factor
 wanted.x=maxf(wanted.x,menu.get_global_rect().size.x)
 popup.wrap_controls=false
 popup.min_size=Vector2i.ZERO
 popup.size=Vector2i(wanted.ceil()).min(popup.max_size)
 var view:Vector2i=Vector2i(menu.get_viewport_rect().size)
 popup.position=popup.position.clamp(Vector2i(12,12),(view-popup.size-Vector2i(12,12)).max(Vector2i(12,12)))
static func populate(menu:OptionButton,ids:Array,host:Node,empty_text:String="Empty hand"):
 var previous:String=str(menu.get_item_metadata(menu.selected)) if menu.selected>=0 and menu.selected<menu.item_count else ""
 var groups:Dictionary={};var order:Array=[]
 for id:String in ids:
  var group:String=key(id,host)
  if not groups.has(group):groups[group]={"id":id,"count":0,"members":[]};order.append(group)
  groups[group].count+=1;groups[group].members.append(id)
 menu.clear()
 if not empty_text.is_empty():menu.add_item(empty_text);menu.set_item_metadata(0,"")
 for group:String in order:
  var row:Dictionary=groups[group]
  var name:String=label(row.id)+( " x%d"%int(row.count) if row.count>1 else "")
  var path:String=Catalog.inventory_icon(row.id)
  if not textures.has(path) and FileAccess.file_exists(path):textures[path]=ImageTexture.create_from_image(Image.load_from_file(path))
  menu.add_icon_item(textures.get(path),name)
  var index:int=menu.item_count-1
  menu.set_item_metadata(index,row.id)
  if previous in row.members:menu.select(index)
 if not menu.has_meta("item_choice_bounded"):
  menu.set_meta("item_choice_bounded",true)
  var menu_ref:WeakRef=weakref(menu)
  var window_ref:WeakRef=weakref(menu.get_window())
  var resized:Callable=func():
   var live:OptionButton=menu_ref.get_ref()
   if live!=null:bound(live)
  menu.get_popup().about_to_popup.connect(resized)
  menu.get_popup().visibility_changed.connect(func():
   var live:OptionButton=menu_ref.get_ref()
   if live!=null:finish_popup(live))
  menu.get_window().size_changed.connect(resized)
  menu.tree_exiting.connect(func():
   var window:Window=window_ref.get_ref()
   if window!=null and window.size_changed.is_connected(resized):window.size_changed.disconnect(resized))
 bound(menu)
