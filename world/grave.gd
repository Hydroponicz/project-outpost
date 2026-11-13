class_name Grave
extends StaticBody3D
## Left where the player died, holding everything they carried.
## Interact (E) takes back as much as fits; it disappears once empty.

const GROUP := &"graves"

@onready var _inventory: Inventory = $Inventory
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(GROUP)
	_interactable.interacted.connect(_on_interacted)


## Moves every stack out of "source" into this grave.
func take_all_from(source: Inventory) -> void:
	for i in source.get_slot_count():
		var stack := source.take_slot(i)
		if stack != null:
			_inventory.set_slot(i, stack)


func _on_interacted(by: Node) -> void:
	var player := by as Player
	if player == null:
		return
	var target := player.get_inventory()
	for i in _inventory.get_slot_count():
		var stack := _inventory.get_slot(i)
		if stack == null:
			continue
		var leftover := target.add_item(stack.item, stack.amount, stack.durability)
		if leftover > 0:
			stack.amount = leftover
		else:
			_inventory.set_slot(i, null)
	if _inventory.is_empty():
		queue_free()
	else:
		player.show_message("Not enough room for everything")


func get_save_data() -> Dictionary:
	return {"position": [global_position.x, global_position.y, global_position.z],
			"inventory": _inventory.get_save_data()}


func apply_save_data(data: Dictionary) -> void:
	var pos: Array = data.get("position", [0, 0, 0])
	global_position = Vector3(pos[0], pos[1], pos[2])
	_inventory.apply_save_data(data.get("inventory", []))
