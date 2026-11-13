class_name GameDatabase
extends RefCounted
## Looks up game data by ID: items (items/*.tres) and build pieces
## (building/pieces/*.tres). Used by saving/loading, which stores IDs
## instead of whole objects. Everything is loaded once, on first use.

const ITEM_FOLDER := "res://items/"
const PIECE_FOLDER := "res://building/pieces/"

static var _items: Dictionary = {}  # StringName -> ItemData
static var _pieces: Array[BuildPieceData] = []
static var _loaded: bool = false


static func get_item(id: StringName) -> ItemData:
	_ensure_loaded()
	return _items.get(id, null)


static func get_piece(id: StringName) -> BuildPieceData:
	_ensure_loaded()
	for piece in _pieces:
		if piece.id == id:
			return piece
	return null


## All build pieces, in build menu order.
static func get_pieces() -> Array[BuildPieceData]:
	_ensure_loaded()
	return _pieces


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for resource in _load_folder(ITEM_FOLDER):
		var item := resource as ItemData
		if item != null and item.id != &"":
			_items[item.id] = item
	for resource in _load_folder(PIECE_FOLDER):
		var piece := resource as BuildPieceData
		if piece != null and piece.scene != null:
			_pieces.append(piece)
	_pieces.sort_custom(func(a: BuildPieceData, b: BuildPieceData) -> bool: return a.sort_order < b.sort_order)


static func _load_folder(folder: String) -> Array[Resource]:
	var resources: Array[Resource] = []
	for file in DirAccess.get_files_at(folder):
		# Exported games rename files to "name.tres.remap"; load the original name.
		var file_name := file.trim_suffix(".remap")
		if file_name.ends_with(".tres"):
			var resource := load(folder + file_name)
			if resource != null:
				resources.append(resource)
	return resources
