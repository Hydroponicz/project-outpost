class_name CameraRig
extends Node3D
## Third-person orbit camera, Valheim style.
##
## Node layout:
##   CameraRig (this node: follows the player, turns left/right = "yaw")
##     PitchPivot (tilts up/down = "pitch")
##       SpringArm3D (pulls the camera in when a wall is in the way)
##         Camera3D
##
## This node is "top level", so it doesn't automatically spin with the
## player. Instead it copies the player's position every frame.

@export var target: Node3D

@export_group("Look")
## Mouse look speed, in degrees per pixel moved.
@export var mouse_sensitivity: float = 0.2
## Right stick look speed, in degrees per second at full tilt.
@export var gamepad_sensitivity: float = 180.0
@export var invert_y: bool = false
## How far down the camera can tilt (negative = looking down from above).
@export_range(-89.0, 0.0) var min_pitch_degrees: float = -70.0
## How far up the camera can tilt (positive = looking up from below).
@export_range(0.0, 89.0) var max_pitch_degrees: float = 40.0

@export_group("Zoom")
@export var min_distance: float = 1.5
@export var max_distance: float = 8.0
@export var start_distance: float = 4.5
## Distance change per scroll-wheel click or d-pad press.
@export var zoom_step: float = 0.5
## How smoothly zoom eases to its new distance. Higher = faster.
@export var zoom_smoothing: float = 10.0

@export_group("Follow")
## Height above the player's feet that the camera orbits around.
@export var pivot_height: float = 1.5

## Current left/right angle in radians. The player reads this to know
## which way "forward" is.
var yaw: float = 0.0
var pitch: float = deg_to_rad(-15.0)

var _target_distance: float

@onready var _pitch_pivot: Node3D = $PitchPivot
@onready var _spring_arm: SpringArm3D = $PitchPivot/SpringArm3D


func _ready() -> void:
	_target_distance = start_distance
	_spring_arm.spring_length = start_distance

	# Start facing the same way as the player.
	if target:
		yaw = target.global_rotation.y

	# Don't let the camera collide with the player's own body.
	if target is CollisionObject3D:
		_spring_arm.add_excluded_object(target.get_rid())

	_set_mouse_captured(true)


func _unhandled_input(event: InputEvent) -> void:
	# Esc / Start frees the mouse. Clicking the game window grabs it again.
	if event.is_action_pressed("toggle_mouse_capture"):
		_set_mouse_captured(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
		return

	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_set_mouse_captured(true)
		return

	# Mouse look (only while the mouse is captured).
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var y_sign := -1.0 if invert_y else 1.0
		yaw -= deg_to_rad(event.relative.x * mouse_sensitivity)
		pitch -= deg_to_rad(event.relative.y * mouse_sensitivity) * y_sign

	# Zoom.
	if event.is_action_pressed("zoom_in"):
		_target_distance -= zoom_step
	elif event.is_action_pressed("zoom_out"):
		_target_distance += zoom_step
	_target_distance = clampf(_target_distance, min_distance, max_distance)


func _process(delta: float) -> void:
	# Right stick look.
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if look != Vector2.ZERO:
		var y_sign := -1.0 if invert_y else 1.0
		yaw -= deg_to_rad(look.x * gamepad_sensitivity * delta)
		pitch -= deg_to_rad(look.y * gamepad_sensitivity * delta) * y_sign

	pitch = clampf(pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))

	# Apply rotation.
	rotation = Vector3(0.0, yaw, 0.0)
	_pitch_pivot.rotation = Vector3(pitch, 0.0, 0.0)

	# Ease toward the zoom distance.
	var weight := 1.0 - exp(-zoom_smoothing * delta)
	_spring_arm.spring_length = lerpf(_spring_arm.spring_length, _target_distance, weight)

	# Follow the player. The "interpolated" transform is the smoothed position
	# drawn on screen, which avoids jitter on high refresh rate monitors.
	if target:
		global_position = target.get_global_transform_interpolated().origin \
				+ Vector3.UP * pivot_height


func _set_mouse_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
