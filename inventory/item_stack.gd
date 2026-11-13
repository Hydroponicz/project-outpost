class_name ItemStack
extends RefCounted
## One inventory slot's contents: an item, how many of it, and (for tools)
## how worn it is.

var item: ItemData
var amount: int
## Uses left before it breaks. -1 = this item doesn't wear out.
var durability: int = -1


## "p_durability" -1 means "brand new" (full durability, if the item has any).
func _init(p_item: ItemData, p_amount: int, p_durability: int = -1) -> void:
	item = p_item
	amount = p_amount
	if item.max_durability > 0:
		durability = item.max_durability if p_durability < 0 else p_durability


## How many more fit in this stack.
func space_left() -> int:
	return item.max_stack - amount


func get_weight() -> float:
	return item.weight * amount


func has_durability() -> bool:
	return durability >= 0


func is_broken() -> bool:
	return durability == 0


func is_damaged() -> bool:
	return has_durability() and durability < item.max_durability


## 0.0 (broken) to 1.0 (new). -1.0 if it doesn't wear out.
func get_durability_ratio() -> float:
	if not has_durability():
		return -1.0
	return float(durability) / item.max_durability
