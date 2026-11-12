extends CanvasLayer
## On-screen display. For now: the crosshair dot and the floating prompt.
##
## Both are hidden unless the Interactor has a target. The prompt is drawn
## in 2D, but every frame it's moved to sit on top of the target's
## Interactable node in the 3D world.

@export var interactor: Interactor

var _target: Interactable = null

@onready var _crosshair: Control = $Crosshair
@onready var _prompt: Label = $Prompt


func _ready() -> void:
	interactor.target_changed.connect(_on_target_changed)
	InputPrompts.device_changed.connect(_on_device_changed)
	_on_target_changed(null)


func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return

	var camera := get_viewport().get_camera_3d()
	var anchor := _target.global_position
	if camera == null or camera.is_position_behind(anchor):
		_prompt.visible = false
		return

	# Convert the 3D point to a screen position, and center the label above it.
	var screen_pos := camera.unproject_position(anchor)
	_prompt.visible = true
	_prompt.position = screen_pos - Vector2(_prompt.size.x * 0.5, _prompt.size.y)


func _on_target_changed(target: Interactable) -> void:
	_target = target
	_crosshair.visible = target != null
	_prompt.visible = target != null
	_refresh_prompt_text()


func _on_device_changed(_using_gamepad: bool) -> void:
	_refresh_prompt_text()


func _refresh_prompt_text() -> void:
	if _target == null:
		return
	_prompt.text = "[%s] %s" % [InputPrompts.get_label(&"interact"), _target.get_prompt_text()]
	_prompt.reset_size()  # Shrink/grow the label to fit the new text.
