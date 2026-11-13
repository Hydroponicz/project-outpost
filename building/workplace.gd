class_name Workplace
extends StaticBody3D
## A place a worker is assigned to, e.g. a Woodcutter's Post.
##
## - Has its own small storage (like a chest). Workers bring what they
##   gather here; you (and later, hauler workers) take it away. When it's
##   full, the worker stops and waits.
## - Has a work radius: workers only work inside it.
## - Keeps a list of spots where trees were cut, so saplings can be planted
##   there. (Today the woodcutter plants them; a separate Forester job
##   could take that over later.)

## Every workplace is in this group, so workers and saving can find them.
const GROUP := &"workplaces"

## What kind of work happens here (workers check this), e.g. "woodcutter".
@export var job: StringName = &"woodcutter"
@export var display_name: String = "Woodcutter's Post"
## Workers only work within this distance (meters) of the post.
@export var work_radius: float = 20.0

## Stable ID so a saved worker can find its workplace again after loading.
var workplace_id: String = ""
## The worker assigned here, or null.
var worker: Node = null
## Where trees were cut and a sapling could go.
var plant_spots: Array[Vector3] = []

@onready var _inventory: Inventory = $Inventory
@onready var _interactable: Interactable = $Interactable
@onready var _label: Label3D = $Label3D


func _ready() -> void:
	add_to_group(GROUP)
	if workplace_id == "":
		workplace_id = "%d_%d" % [Time.get_unix_time_from_system(), randi()]
	_interactable.interacted.connect(_on_interacted)
	_update_label()


func _exit_tree() -> void:
	# Removed with the hammer: the worker goes back to idle.
	if worker != null and is_instance_valid(worker):
		worker.call("unassign")


func get_inventory() -> Inventory:
	return _inventory


func is_in_range(point: Vector3) -> bool:
	var flat := point - global_position
	flat.y = 0.0
	return flat.length() <= work_radius


func set_worker(new_worker: Node) -> void:
	worker = new_worker
	_update_label()


func add_plant_spot(spot: Vector3) -> void:
	plant_spots.append(spot)


## Asked by the hammer before removing this piece.
func can_be_removed() -> bool:
	return _inventory.is_empty()


func get_save_data() -> Dictionary:
	var spots: Array = []
	for spot in plant_spots:
		spots.append([spot.x, spot.y, spot.z])
	return {"id": workplace_id, "inventory": _inventory.get_save_data(), "plant_spots": spots}


func apply_save_data(data: Dictionary) -> void:
	workplace_id = str(data.get("id", workplace_id))
	_inventory.apply_save_data(data.get("inventory", []))
	plant_spots.clear()
	for spot: Array in data.get("plant_spots", []):
		plant_spots.append(Vector3(spot[0], spot[1], spot[2]))


func _on_interacted(by: Node) -> void:
	var player := by as Player
	if player != null:
		player.open_container(_inventory, display_name)


func _update_label() -> void:
	if _label != null:
		_label.text = "%s\n%s" % [display_name, "Worker assigned" if worker != null else "No worker"]
