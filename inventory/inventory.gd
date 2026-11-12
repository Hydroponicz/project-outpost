class_name Inventory
extends Node
## A set of item slots. Only holds data: the screen that shows it is separate
## (ui/inventory_screen.gd), so chests and workers can reuse this later.
##
## Each slot is either empty (null) or an ItemStack.

## Emitted whenever anything in the inventory changes.
signal changed

## Number of slots. Tip: set this to 2 in the Inspector to test "Inventory full".
@export var slot_count: int = 32
## Carrying more weight than this makes the owner encumbered (slow, no sprint).
## 0 = no limit. Tip: set this low (e.g. 10) in the Inspector to test it.
@export var max_weight: float = 300.0

var _slots: Array[ItemStack] = []


func get_slot_count() -> int:
	_ensure_slots()
	return _slots.size()


## The stack in a slot, or null if the slot is empty.
func get_slot(index: int) -> ItemStack:
	_ensure_slots()
	return _slots[index]


## How many of this item could still fit.
func get_space_for(item: ItemData) -> int:
	_ensure_slots()
	var space := 0
	for stack in _slots:
		if stack == null:
			space += item.max_stack
		elif stack.item == item:
			space += stack.space_left()
	return space


func can_add(item: ItemData, amount: int) -> bool:
	return get_space_for(item) >= amount


## Adds items, filling existing stacks first, then empty slots.
## Returns how many did NOT fit (0 = all added).
func add_item(item: ItemData, amount: int) -> int:
	_ensure_slots()
	var remaining := amount

	for stack in _slots:
		if remaining <= 0:
			break
		if stack != null and stack.item == item and stack.space_left() > 0:
			var moved := mini(remaining, stack.space_left())
			stack.amount += moved
			remaining -= moved

	for i in _slots.size():
		if remaining <= 0:
			break
		if _slots[i] == null:
			var moved := mini(remaining, item.max_stack)
			_slots[i] = ItemStack.new(item, moved)
			remaining -= moved

	if remaining != amount:
		changed.emit()
	return remaining


## Moves the stack in "from" onto slot "to":
##   empty slot -> move, same item -> merge (extra stays behind), other item -> swap.
func move_stack(from: int, to: int) -> void:
	_ensure_slots()
	if from == to:
		return
	var moving := _slots[from]
	if moving == null:
		return
	var other := _slots[to]

	if other == null:
		_slots[to] = moving
		_slots[from] = null
	elif other.item == moving.item:
		var moved := mini(moving.amount, other.space_left())
		other.amount += moved
		moving.amount -= moved
		if moving.amount <= 0:
			_slots[from] = null
	else:
		_slots[to] = moving
		_slots[from] = other
	changed.emit()


func get_total_weight() -> float:
	_ensure_slots()
	var total := 0.0
	for stack in _slots:
		if stack != null:
			total += stack.get_weight()
	return total


func is_overweight() -> bool:
	return max_weight > 0.0 and get_total_weight() > max_weight


## Makes sure the slot list matches slot_count (safe to call any time).
func _ensure_slots() -> void:
	if _slots.size() != slot_count:
		_slots.resize(slot_count)
