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
## "durability" is for tools picked back up (-1 = brand new).
## Returns how many did NOT fit (0 = all added).
func add_item(item: ItemData, amount: int, durability: int = -1) -> int:
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
			_slots[i] = ItemStack.new(item, moved, durability)
			remaining -= moved

	if remaining != amount:
		changed.emit()
	return remaining


## Moves the stack in "from" onto slot "to":
##   empty slot -> move, same item with room -> merge (extra stays behind),
##   anything else -> swap.
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
	elif other.item == moving.item and other.space_left() > 0:
		var moved := mini(moving.amount, other.space_left())
		other.amount += moved
		moving.amount -= moved
		if moving.amount <= 0:
			_slots[from] = null
	else:
		_slots[to] = moving
		_slots[from] = other
	changed.emit()


## Total amount of an item across all slots.
func count_item(item: ItemData) -> int:
	_ensure_slots()
	var total := 0
	for stack in _slots:
		if stack != null and stack.item == item:
			total += stack.amount
	return total


## Removes up to "amount" of an item, taking from the last slots first.
## Returns how many were actually removed.
func remove_item(item: ItemData, amount: int) -> int:
	_ensure_slots()
	var remaining := amount
	for i in range(_slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var stack := _slots[i]
		if stack == null or stack.item != item:
			continue
		var taken := mini(remaining, stack.amount)
		stack.amount -= taken
		remaining -= taken
		if stack.amount <= 0:
			_slots[i] = null
	if remaining != amount:
		changed.emit()
	return amount - remaining


## Puts a stack (or null) straight into a slot, replacing what was there.
func set_slot(index: int, stack: ItemStack) -> void:
	_ensure_slots()
	_slots[index] = stack
	changed.emit()


func is_empty() -> bool:
	_ensure_slots()
	for stack in _slots:
		if stack != null:
			return false
	return true


## Like move_stack, but between two inventories (e.g. player <-> chest):
## empty slot -> move, same item with room -> merge, anything else -> swap.
static func transfer(from_inv: Inventory, from_index: int, to_inv: Inventory, to_index: int) -> void:
	if from_inv == to_inv:
		from_inv.move_stack(from_index, to_index)
		return
	var moving := from_inv.get_slot(from_index)
	if moving == null:
		return
	var other := to_inv.get_slot(to_index)
	if other == null:
		to_inv.set_slot(to_index, moving)
		from_inv.set_slot(from_index, null)
	elif other.item == moving.item and other.space_left() > 0:
		var moved := mini(moving.amount, other.space_left())
		other.amount += moved
		moving.amount -= moved
		to_inv.changed.emit()
		from_inv.set_slot(from_index, moving if moving.amount > 0 else null)
	else:
		to_inv.set_slot(to_index, moving)
		from_inv.set_slot(from_index, other)


## Removes and returns the whole stack in a slot (null if it was empty).
func take_slot(index: int) -> ItemStack:
	_ensure_slots()
	var stack := _slots[index]
	if stack != null:
		_slots[index] = null
		changed.emit()
	return stack


## Wears down the tool in a slot. Returns false if there's nothing to wear.
func use_durability(index: int, amount: int = 1) -> bool:
	_ensure_slots()
	var stack := _slots[index]
	if stack == null or not stack.has_durability():
		return false
	stack.durability = maxi(stack.durability - amount, 0)
	changed.emit()
	return true


func has_damaged_items() -> bool:
	_ensure_slots()
	for stack in _slots:
		if stack != null and stack.is_damaged():
			return true
	return false


## Restores every tool to full durability. Returns how many were repaired.
func repair_all() -> int:
	_ensure_slots()
	var repaired := 0
	for stack in _slots:
		if stack != null and stack.is_damaged():
			stack.durability = stack.item.max_durability
			repaired += 1
	if repaired > 0:
		changed.emit()
	return repaired


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
