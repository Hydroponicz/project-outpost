class_name Player
extends CharacterBody3D
## The player character: walking, sprinting, jumping and turning to face
## the direction of movement. The camera lives in camera_rig.gd.
##
## Every @export value below shows up in the Inspector when you select the
## Player node, so you can tune the feel without editing code.

@export_group("Movement")
## Normal movement speed, in meters per second.
@export var walk_speed: float = 4.0
## Speed while holding sprint.
@export var sprint_speed: float = 7.5
## Speed while carrying more than the weight limit (no sprinting).
@export var encumbered_speed: float = 2.0
## How quickly the player reaches full speed. Higher = snappier.
@export var acceleration: float = 30.0
## How quickly the player stops when you let go. Higher = less sliding.
@export var deceleration: float = 40.0
## How much control you keep while in the air (0 = none, 1 = full).
@export_range(0.0, 1.0) var air_control: float = 0.3
## How quickly the character turns to face its movement direction.
@export var turn_speed: float = 12.0

@export_group("Jumping")
## Peak jump height, in meters.
@export var jump_height: float = 1.2
## Multiplies the project's gravity. Higher = quicker, less floaty jumps.
@export var gravity_multiplier: float = 2.0
## Extra gravity while falling, so you come down faster than you go up.
## 1 = same as rising. Higher = snappier landings.
@export var fall_gravity_multiplier: float = 1.6

## False while a menu (like the inventory) is open: the character ignores
## movement input but still falls and slows to a stop.
var controls_enabled: bool = true

## Set when controls come back on (a menu closed). Jumping waits until the
## jump button is released, so the A press that closed the menu doesn't jump.
var _jump_blocked: bool = false

## Gamepad sprint is a toggle: click the left stick to start, and it stops
## when you let go of the stick (or click again).
var _sprint_toggled: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _visual: Node3D = $Visual
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _interactor: Interactor = $Interactor
@onready var _inventory: Inventory = $Inventory
@onready var _collector: ItemCollector = $ItemCollector
@onready var _hotbar: Hotbar = $Hotbar
@onready var _hud: HUD = $HUD
@onready var _builder: Builder = $Builder
@onready var _inventory_screen: InventoryScreen = $InventoryScreen


## Turns player control (movement, camera, hitting, interacting) on or off.
## Menus call this when they open and close.
func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	_camera_rig.input_enabled = enabled
	_interactor.enabled = enabled
	_hotbar.enabled = enabled
	_builder.enabled = enabled
	if not enabled:
		_sprint_toggled = false
	else:
		_jump_blocked = true


func get_inventory() -> Inventory:
	return _inventory


## Opens the inventory screen next to a chest (or other container).
func open_container(container: Inventory, title: String) -> void:
	_inventory_screen.open_container(container, title)


## Shows a short message on screen, e.g. "Inventory full".
func show_message(text: String) -> void:
	_hud.show_message(text)


## Drops items on the ground in front of the character, as one bundle.
## "durability" keeps a worn tool worn (-1 = not a tool / brand new).
func drop_items(item: ItemData, amount: int, durability: int = -1) -> void:
	var forward := -_visual.global_basis.z  # The way the character faces.
	var at := global_position + forward * 0.8 + Vector3.UP * 1.2
	var toss := forward * 2.5 + Vector3.UP * 2.0
	_collector.drop(item, amount, at, toss, durability)


func _physics_process(delta: float) -> void:
	var gravity := _gravity * gravity_multiplier

	# --- Gravity ---
	# Falling (moving downward) uses stronger gravity than rising.
	if not is_on_floor():
		var fall_boost := fall_gravity_multiplier if velocity.y < 0.0 else 1.0
		velocity.y -= gravity * fall_boost * delta

	# --- Jump ---
	# Physics formula: the launch speed needed to reach jump_height.
	if _jump_blocked and not Input.is_action_pressed("jump"):
		_jump_blocked = false
	if controls_enabled and not _jump_blocked and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = sqrt(2.0 * gravity * jump_height)

	# --- Read input ---
	# Input.get_vector returns a 2D direction from WASD or the left stick.
	# On a stick, a light push gives a value shorter than 1, so walking slowly works.
	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Rotate the input so "forward" means "the way the camera is facing".
	var camera_yaw := Basis(Vector3.UP, _camera_rig.yaw)
	var move_dir := camera_yaw * Vector3(input.x, 0.0, input.y)

	# --- Sprint ---
	# Keyboard: hold Shift. Gamepad: click the stick to toggle.
	if controls_enabled and Input.is_action_just_pressed("sprint_toggle"):
		_sprint_toggled = not _sprint_toggled
	if input.length() < 0.1:
		_sprint_toggled = false  # Stopped moving, so stop sprinting.
	var sprinting := (controls_enabled and Input.is_action_pressed("sprint")) or _sprint_toggled

	# --- Horizontal movement ---
	var speed := walk_speed
	if _inventory.is_overweight():
		speed = encumbered_speed  # Too heavy: slow, and no sprinting.
		_sprint_toggled = false
	elif sprinting:
		speed = sprint_speed
	var target_velocity := move_dir * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	var rate := acceleration if move_dir.length() > 0.01 else deceleration
	if not is_on_floor():
		rate *= air_control
	horizontal = horizontal.move_toward(target_velocity, rate * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()

	# --- Face the movement direction ---
	# Only the visual model turns. The collision capsule is round, so it
	# doesn't need to.
	if move_dir.length() > 0.1:
		# Godot models face -Z by default, hence the minus signs.
		var target_angle := atan2(-move_dir.x, -move_dir.z)
		var weight := 1.0 - exp(-turn_speed * delta)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_angle, weight)
