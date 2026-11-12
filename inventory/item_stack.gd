class_name ItemStack
extends RefCounted
## One inventory slot's contents: an item and how many of it.

var item: ItemData
var amount: int


func _init(p_item: ItemData, p_amount: int) -> void:
	item = p_item
	amount = p_amount


## How many more fit in this stack.
func space_left() -> int:
	return item.max_stack - amount


func get_weight() -> float:
	return item.weight * amount
