extends Node
## Global save manager (an "autoload", always running, reachable as SaveSystem).
##
## - Title screen: Continue loads the save, New Game starts fresh.
## - In the world: autosaves every few minutes, and saves when you quit
##   (Quit in the pause menu, Quit to Title, or closing the game window).
##   NOTE: stopping the game with the editor's Stop button does NOT save.
##
## The save file is JSON text in Godot's user folder, with a version number
## so old saves can be upgraded when the game changes.
##
## Each system saves its own part (get_save_data / apply_save_data):
## the player, chests, trees/rocks (by their place in the level), forage,
## built pieces and items on the ground.

const SAVE_PATH := "user://savegame.json"
const TEMP_PATH := "user://savegame.tmp"
const SAVE_VERSION := 1
const WORLD_SCENE := "res://world/test_level.tscn"
const TITLE_SCENE := "res://ui/title_screen.tscn"
const PICKUP_SCENE := preload("res://items/item_pickup.tscn")
const GRAVE_SCENE := preload("res://world/grave.tscn")

## Seconds between autosaves.
var autosave_interval: float = 300.0

var _world: World = null
var _load_on_enter: bool = false
var _autosave_left: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep working while paused.
	get_tree().auto_accept_quit = false  # Let us save before the window closes.


func _process(delta: float) -> void:
	if not _in_world() or get_tree().paused:
		return
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = autosave_interval
		if save_game():
			_world.get_player().show_message("Game saved")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


# --- Title screen / pause menu actions ---

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func continue_game() -> void:
	_load_on_enter = true
	_change_scene(WORLD_SCENE)


func new_game() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_load_on_enter = false
	_change_scene(WORLD_SCENE)


func quit_to_title() -> void:
	save_game()
	_world = null
	_change_scene(TITLE_SCENE)


func quit_game() -> void:
	save_game()
	get_tree().quit()


## Called by the world when it has finished loading.
func world_ready(world: World) -> void:
	_world = world
	_autosave_left = autosave_interval
	if _load_on_enter:
		_load_on_enter = false
		_load_into(world)


# --- Saving ---

## Saves the current world. Returns false if not in a world or writing failed.
func save_game() -> bool:
	if not _in_world():
		return false
	var json := JSON.stringify(_collect(_world), "\t")
	# Write to a temporary file first, then swap it in, so a crash halfway
	# through saving can't leave a broken save file behind.
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(json)
	file.close()
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH),
			ProjectSettings.globalize_path(SAVE_PATH))
	if error != OK:
		push_error("Could not replace save: %s" % error_string(error))
		return false
	return true


func _collect(world: World) -> Dictionary:
	var data := {"version": SAVE_VERSION, "player": world.get_player().get_save_data()}

	# Trees/rocks still standing, with their health. Missing = chopped down.
	var resources := {}
	for node in get_tree().get_nodes_in_group(ResourceNode.GROUP):
		if not node.is_queued_for_deletion():
			resources[str(world.get_path_to(node))] = (node as ResourceNode).get_health()
	data["resource_nodes"] = resources

	# Forage that's been picked, with seconds until it comes back.
	var forage := {}
	for node in get_tree().get_nodes_in_group(ForagePickup.GROUP):
		var pickup := node as ForagePickup
		if not pickup.is_present():
			forage[str(world.get_path_to(pickup))] = pickup.respawn_left
	data["forage"] = forage

	# Everything the player built.
	var pieces: Array = []
	for node in get_tree().get_nodes_in_group(BuildPiece.GROUP):
		var piece := node as BuildPiece
		var body := piece.get_parent() as Node3D
		if body == null or body.is_queued_for_deletion():
			continue
		var entry := {"id": String(piece.piece_id), "transform": _transform_to_array(body.global_transform)}
		if body.has_method("get_save_data"):
			entry["data"] = body.call("get_save_data")
		pieces.append(entry)
	data["pieces"] = pieces

	# Items lying on the ground.
	var items: Array = []
	for node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var pickup := node as ItemPickup
		if pickup.is_queued_for_deletion() or pickup.item == null:
			continue
		var pos := pickup.global_position
		items.append({"item": String(pickup.item.id), "amount": pickup.amount,
				"durability": pickup.durability, "position": [pos.x, pos.y, pos.z]})
	data["items"] = items

	# Graves (where you died, with your stuff in them).
	var graves: Array = []
	for node in get_tree().get_nodes_in_group(Grave.GROUP):
		if not node.is_queued_for_deletion():
			graves.append((node as Grave).get_save_data())
	data["graves"] = graves

	return data


# --- Loading ---

func _load_into(world: World) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		push_error("Save file is damaged; starting fresh.")
		return
	if int(data.get("version", 0)) > SAVE_VERSION:
		push_warning("Save is from a newer version of the game.")

	world.get_player().apply_save_data(data.get("player", {}))

	var resources: Dictionary = data.get("resource_nodes", {})
	for node in get_tree().get_nodes_in_group(ResourceNode.GROUP):
		var key := str(world.get_path_to(node))
		if resources.has(key):
			(node as ResourceNode).set_health(int(resources[key]))
		else:
			node.queue_free()  # Was chopped down / mined out.

	var forage: Dictionary = data.get("forage", {})
	for node in get_tree().get_nodes_in_group(ForagePickup.GROUP):
		var key := str(world.get_path_to(node))
		if forage.has(key):
			(node as ForagePickup).set_gone(float(forage[key]))

	for entry: Dictionary in data.get("pieces", []):
		var piece_data := GameDatabase.get_piece(StringName(entry.get("id", "")))
		if piece_data == null:
			continue
		var body: Node3D = piece_data.scene.instantiate()
		world.add_child(body)
		body.global_transform = _array_to_transform(entry.get("transform", []))
		if entry.has("data") and body.has_method("apply_save_data"):
			body.call("apply_save_data", entry["data"])

	for entry: Dictionary in data.get("items", []):
		var item := GameDatabase.get_item(StringName(entry.get("item", "")))
		if item == null:
			continue
		var pickup: ItemPickup = PICKUP_SCENE.instantiate()
		pickup.item = item
		pickup.amount = int(entry.get("amount", 1))
		pickup.durability = int(entry.get("durability", -1))
		world.add_child(pickup)
		var pos: Array = entry.get("position", [0, 0, 0])
		pickup.global_position = Vector3(pos[0], pos[1], pos[2])

	for entry: Dictionary in data.get("graves", []):
		var grave: Grave = GRAVE_SCENE.instantiate()
		world.add_child(grave)
		grave.apply_save_data(entry)


# --- Helpers ---

func _in_world() -> bool:
	return _world != null and is_instance_valid(_world) and _world.is_inside_tree()


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


static func _transform_to_array(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
			t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]


static func _array_to_transform(a: Array) -> Transform3D:
	if a.size() < 12:
		return Transform3D.IDENTITY
	return Transform3D(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]),
			Vector3(a[6], a[7], a[8]), Vector3(a[9], a[10], a[11]))
