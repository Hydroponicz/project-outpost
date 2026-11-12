extends CanvasLayer
## The inventory screen: a grid of InventorySlots showing an Inventory.
##
## Open/close: Tab, or View/Select on gamepad. Esc / B / Start also closes.
## While open, the game keeps running but the player's controls are off.
##
## Moving stacks:
##   Mouse:   press on a stack, drag, release on another slot.
##   Gamepad: highlight a stack, press A to grab it (it rides along with the
##            highlight), move, press A to drop. B cancels.

@export var player: Player
@export var inventory: Inventory

var is_open: bool = false

var _slots: Array[InventorySlot] = []
## Slot index of the stack grabbed with A/Enter, or -1 when not holding one.
var _held_from: int = -1

@onready var _grid: GridContainer = $Center/Panel/Margin/VBox/Grid
@onready var _weight_label: Label = $Center/Panel/Margin/VBox/Weight
@onready var _held_label: Label = $HeldLabel


func _ready() -> void:
	visible = false
	for i in inventory.get_slot_count():
		var slot := InventorySlot.new()
		slot.index = i
		slot.inventory = inventory
		slot.accepted.connect(_on_slot_accepted)
		slot.dropped.connect(_on_slot_dropped)
		_grid.add_child(slot)
		_slots.append(slot)
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

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_mouse_capture"):
		if _held_from != -1:
			_held_from = -1  # First press just puts the held stack back.
			_refresh()
		else:
			close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not is_open or _held_from == -1:
		return
	# The held stack floats just above whichever slot is highlighted.
	var focused := get_viewport().gui_get_focus_owner() as Control
	if focused != null:
		_held_label.position = focused.global_position + Vector2(0, -_held_label.size.y)


func open() -> void:
	is_open = true
	visible = true
	_held_from = -1
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	_slots[0].grab_focus.call_deferred()  # Gamepad users start on the first slot.


func close() -> void:
	is_open = false
	visible = false
	_held_from = -1
	get_viewport().gui_release_focus()
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_slot_accepted(index: int) -> void:
	if _held_from == -1:
		if inventory.get_slot(index) != null:
			_held_from = index  # Grab.
			_refresh()
	else:
		var from := _held_from
		_held_from = -1  # Drop.
		inventory.move_stack(from, index)
		_refresh()


func _on_slot_dropped(from_index: int, to_index: int) -> void:
	_held_from = -1
	inventory.move_stack(from_index, to_index)
	_refresh()


func _refresh() -> void:
	# A held stack can't vanish today, but be safe if it ever does.
	if _held_from != -1 and inventory.get_slot(_held_from) == null:
		_held_from = -1

	for i in _slots.size():
		_slots[i].show_stack(inventory.get_slot(i), i == _held_from)

	var weight := inventory.get_total_weight()
	_weight_label.text = "Weight  %d / %d" % [roundi(weight), roundi(inventory.max_weight)]
	_weight_label.modulate = Color(1.0, 0.4, 0.4) if inventory.is_overweight() else Color.WHITE

	_held_label.visible = _held_from != -1
	if _held_from != -1:
		_held_label.text = InventorySlot.get_stack_text(inventory.get_slot(_held_from)).replace("\n", " ×")
		_held_label.reset_size()
