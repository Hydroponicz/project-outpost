class_name Chest
extends StaticBody3D
## A buildable storage box. Press Interact (E) to open it next to your
## inventory. A chest with items in it can't be removed with the hammer, so
## nothing gets lost. Workers will deposit into chests later.

@onready var _inventory: Inventory = $Inventory
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)


func get_inventory() -> Inventory:
	return _inventory


## Asked by the hammer before removing this piece.
func can_be_removed() -> bool:
	return _inventory.is_empty()


func _on_interacted(by: Node) -> void:
	var player := by as Player
	if player != null:
		player.open_container(_inventory, "Chest")
