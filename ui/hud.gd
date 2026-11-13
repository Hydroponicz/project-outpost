class_name HUD
extends CanvasLayer
## On-screen display: crosshair dot, floating prompt, hotbar, short messages
## ("Inventory full", "Needs an Axe") and status ("Encumbered").
##
## The crosshair and prompt are hidden unless the Interactor has a target.
## The prompt is drawn in 2D, but every frame it's moved to sit on top of
## the target's Interactable/Hittable node in the 3D world.

const HOTBAR_SLOT_SIZE := Vector2(72, 72)

@export var interactor: Interactor
@export var collector: ItemCollector
@export var inventory: Inventory
@export var hotbar: Hotbar
## How long messages like "Inventory full" stay on screen, in seconds.
@export var message_duration: float = 2.0

var _target: Node3D = null
var _anchor: Node3D = null  # Where the prompt floats.
var _message_time_left: float = 0.0
var _hotbar_slots: Array[InventorySlot] = []

@onready var _crosshair: Control = $Crosshair
@onready var _prompt: Label = $Prompt
@onready var _message: Label = $Message
@onready var _status: Label = $Status
@onready var _hotbar_row: HBoxContainer = $Hotbar


func _ready() -> void:
	# The hotbar row reuses the inventory's slot widget, just display-only.
	for i in Hotbar.SIZE:
		var slot := InventorySlot.new()
		slot.index = i
		slot.inventory = inventory
		slot.hotkey = i + 1
		slot.custom_minimum_size = HOTBAR_SLOT_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hotbar_row.add_child(slot)
		_hotbar_slots.append(slot)

	interactor.target_changed.connect(_on_target_changed)
	interactor.hit_blocked.connect(show_message)
	collector.pickup_blocked.connect(_on_pickup_blocked)
	inventory.changed.connect(_on_inventory_changed)
	hotbar.selection_changed.connect(_on_hotbar_selection_changed)
	InputPrompts.device_changed.connect(_on_device_changed)
	_on_target_changed(null)
	_on_inventory_changed()


func _process(delta: float) -> void:
	if _message_time_left > 0.0:
		_message_time_left -= delta
		_message.visible = _message_time_left > 0.0

	if _anchor == null or not is_instance_valid(_anchor):
		_prompt.visible = false
		return

	var camera := get_viewport().get_camera_3d()
	var anchor_pos := _anchor.global_position
	if camera == null or camera.is_position_behind(anchor_pos):
		_prompt.visible = false
		return

	# Convert the 3D point to a screen position, and center the label above it.
	var screen_pos := camera.unproject_position(anchor_pos)
	_prompt.visible = true
	_prompt.position = screen_pos - Vector2(_prompt.size.x * 0.5, _prompt.size.y)


func show_message(text: String) -> void:
	_message.text = text
	_message.visible = true
	_message_time_left = message_duration


func _on_target_changed(target: Node3D) -> void:
	_target = target
	_anchor = null
	if target != null:
		_anchor = Interactable.find_on(target)
		if _anchor == null:
			_anchor = Hittable.find_on(target)
	_crosshair.visible = target != null
	_prompt.visible = target != null
	_refresh_prompt_text()


func _on_device_changed(_using_gamepad: bool) -> void:
	_refresh_prompt_text()


func _on_inventory_changed() -> void:
	_status.visible = inventory.is_overweight()
	_refresh_hotbar()
	_refresh_prompt_text()  # A tool may have broken or been moved.


func _on_hotbar_selection_changed(_index: int) -> void:
	_refresh_hotbar()
	_refresh_prompt_text()


func _on_pickup_blocked() -> void:
	show_message("Inventory full")


func _refresh_hotbar() -> void:
	for i in _hotbar_slots.size():
		_hotbar_slots[i].show_stack(inventory.get_slot(i), false)
		_hotbar_slots[i].set_highlighted(i == hotbar.selected)


func _refresh_prompt_text() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var lines: PackedStringArray = []
	var hittable := Hittable.find_on(_target)
	if hittable != null:
		lines.append("[%s] %s" % [InputPrompts.get_label(&"hit"), hittable.get_prompt_text()])
		var problem := hotbar.get_tool_problem(hittable.required_tool)
		if problem != "":
			lines.append("(%s)" % problem)
	var interactable := Interactable.find_on(_target)
	if interactable != null:
		lines.append("[%s] %s" % [InputPrompts.get_label(&"interact"), interactable.get_prompt_text()])
	_prompt.text = "\n".join(lines)
	_prompt.reset_size()  # Shrink/grow the label to fit the new text.
