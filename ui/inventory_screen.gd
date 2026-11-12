extends CanvasLayer
## The inventory screen: a grid of InventorySlots showing an Inventory.
##
## Open/close: Tab, or View/Select on gamepad. Esc / B / Start also closes.
## While open, the game keeps running but the player's controls are off.
##
## Moving stacks:
##   Mouse:   press on a stack, drag, release on another slot.
##   Gamepad: move the highlight (d-pad / left stick / arrow keys), press A
##            (or Enter) to grab a stack; it rides along with the highlight.
##            Press A again to drop it, B to put it back.
##
## Dropping on the ground (whole stack):
##   Mouse:   drag a stack outside the panel and release.
##   Button:  Q / Y drops the highlighted stack (or the one being held).
##
## The screen tracks the highlighted slot itself ("_cursor") and reads its
## own menu_* input actions, so it doesn't depend on Godot's built-in UI
## focus navigation.

@export var player: Player
@export var inventory: Inventory

var is_open: bool = false

var _slots: Array[InventorySlot] = []
## Index of the highlighted slot.
var _cursor: int = 0
## Slot index of the stack grabbed with A/Enter, or -1 when not holding one.
var _held_from: int = -1

@onready var _grid: GridContainer = $Center/Panel/Margin/VBox/Grid
@onready var _weight_label: Label = $Center/Panel/Margin/VBox/Weight
@onready var _held_label: Label = $HeldLabel
@onready var _drop_zone: InventoryDropZone = $Dim


func _ready() -> void:
	visible = false
	for i in inventory.get_slot_count():
		var slot := InventorySlot.new()
		slot.index = i
		slot.inventory = inventory
		slot.hovered.connect(_on_slot_hovered)
		slot.dropped.connect(_on_slot_dropped)
		_grid.add_child(slot)
		_slots.append(slot)
	_drop_zone.stack_dropped.connect(_drop_to_ground)
	inventory.changed.connect(_refresh)
	_refresh()


func _input(event: InputEvent) -> void:
	# _input runs before the GUI, so Tab isn't eaten by focus navigation.
	if event.is_action_pressed("inventory"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return

	if not is_open:
		return

	var handled := true
	if event.is_action_pressed("menu_cancel") or event.is_action_pressed("toggle_mouse_capture"):
		if _held_from != -1:
			_held_from = -1  # First press just puts the held stack back.
			_refresh()
		else:
			close()
	elif event.is_action_pressed("menu_accept"):
		_grab_or_drop(_cursor)
	elif event.is_action_pressed("drop_item"):
		_drop_to_ground(_held_from if _held_from != -1 else _cursor)
	elif event.is_action_pressed("menu_left"):
		_move_cursor(-1, 0)
	elif event.is_action_pressed("menu_right"):
		_move_cursor(1, 0)
	elif event.is_action_pressed("menu_up"):
		_move_cursor(0, -1)
	elif event.is_action_pressed("menu_down"):
		_move_cursor(0, 1)
	else:
		handled = false

	if handled:
		get_viewport().set_input_as_handled()


func open() -> void:
	is_open = true
	visible = true
	_held_from = -1
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	is_open = false
	visible = false
	_held_from = -1
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Moves the highlight by whole columns/rows, stopping at the grid edges.
func _move_cursor(dx: int, dy: int) -> void:
	var columns := _grid.columns
	var rows := ceili(float(_slots.size()) / columns)
	var col := clampi(_cursor % columns + dx, 0, columns - 1)
	var row := clampi(floori(float(_cursor) / columns) + dy, 0, rows - 1)
	_cursor = mini(row * columns + col, _slots.size() - 1)
	_refresh()


func _grab_or_drop(index: int) -> void:
	if _held_from == -1:
		if inventory.get_slot(index) != null:
			_held_from = index  # Grab.
			_refresh()
	else:
		var from := _held_from
		_held_from = -1  # Drop.
		inventory.move_stack(from, index)
		_refresh()


## Takes the whole stack out of a slot and drops it in front of the player.
func _drop_to_ground(index: int) -> void:
	_held_from = -1
	var stack := inventory.take_slot(index)
	if stack != null:
		player.drop_items(stack.item, stack.amount)
	_refresh()


func _on_slot_hovered(index: int) -> void:
	_cursor = index
	_refresh()


func _on_slot_dropped(from_index: int, to_index: int) -> void:
	_held_from = -1
	_cursor = to_index
	inventory.move_stack(from_index, to_index)
	_refresh()


func _refresh() -> void:
	# A held stack can't vanish today, but be safe if it ever does.
	if _held_from != -1 and inventory.get_slot(_held_from) == null:
		_held_from = -1

	for i in _slots.size():
		_slots[i].show_stack(inventory.get_slot(i), i == _held_from)
		_slots[i].set_highlighted(i == _cursor)

	var weight := inventory.get_total_weight()
	_weight_label.text = "Weight  %d / %d" % [roundi(weight), roundi(inventory.max_weight)]
	_weight_label.modulate = Color(1.0, 0.4, 0.4) if inventory.is_overweight() else Color.WHITE

	_held_label.visible = _held_from != -1
	if _held_from != -1:
		_held_label.text = InventorySlot.get_stack_text(inventory.get_slot(_held_from)).replace("\n", " ×")
		_held_label.reset_size()
		_update_held_label_position.call_deferred()


## Floats the held stack's name just above the highlighted slot.
## Deferred so the grid has finished laying out the first time it opens.
func _update_held_label_position() -> void:
	var slot := _slots[_cursor]
	_held_label.position = slot.global_position + Vector2(0, -_held_label.size.y)
