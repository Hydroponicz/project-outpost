class_name InventoryDropZone
extends ColorRect
## The dimmed background behind the inventory panel. Dragging a stack here
## (outside the panel) and releasing drops it on the ground.

signal stack_dropped(from_inventory: Inventory, from_index: int)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("inventory") and data.has("index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	stack_dropped.emit(data["inventory"], data["index"])
