extends CanvasLayer
## On-screen display: crosshair dot, floating prompt, and (temporarily) a
## resource counter.
##
## The crosshair and prompt are hidden unless the Interactor has a target.
## The prompt is drawn in 2D, but every frame it's moved to sit on top of
## the target's Interactable/Hittable node in the 3D world.

@export var interactor: Interactor
@export var collector: ItemCollector

var _target: Node3D = null
var _anchor: Node3D = null  # Where the prompt floats.

@onready var _crosshair: Control = $Crosshair
@onready var _prompt: Label = $Prompt
@onready var _counter: Label = $Counter


func _ready() -> void:
	interactor.target_changed.connect(_on_target_changed)
	collector.item_collected.connect(_on_item_collected)
	InputPrompts.device_changed.connect(_on_device_changed)
	_on_target_changed(null)
	_refresh_counter()


func _process(_delta: float) -> void:
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


func _refresh_prompt_text() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var lines: PackedStringArray = []
	var hittable := Hittable.find_on(_target)
	if hittable != null:
		lines.append("[%s] %s" % [InputPrompts.get_label(&"hit"), hittable.get_prompt_text()])
	var interactable := Interactable.find_on(_target)
	if interactable != null:
		lines.append("[%s] %s" % [InputPrompts.get_label(&"interact"), interactable.get_prompt_text()])
	_prompt.text = "\n".join(lines)
	_prompt.reset_size()  # Shrink/grow the label to fit the new text.


func _on_item_collected(_item: ItemData, _amount: int) -> void:
	_refresh_counter()


## TEMPORARY until the inventory in step 4.
func _refresh_counter() -> void:
	var lines: PackedStringArray = []
	for item: ItemData in collector.counts:
		lines.append("%s: %d" % [item.display_name, collector.counts[item]])
	_counter.text = "\n".join(lines)
