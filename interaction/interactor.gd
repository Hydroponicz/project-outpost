class_name Interactor
extends Node
## Lives on the player. Every physics frame it looks for an object at the
## center of the screen, then lets you use it (interact button) or hit it
## (hit button), depending on what the object supports.
##
## How targeting works:
##   1. Cast an invisible ray from the camera, straight through screen center.
##   2. Take the first thing it hits. Walls block it, so no using things
##      through walls.
##   3. Only accept it if it's within "reach" of the CHARACTER (not the
##      camera, which can be zoomed far back), and it has an Interactable
##      and/or Hittable attached.

## Emitted when the target changes. "target" is the targeted physics body,
## or null when nothing is targeted.
signal target_changed(target: Node3D)

@export var camera: Camera3D
@export var body: CharacterBody3D
## How far the character can reach, in meters.
@export var reach: float = 2.5
## Reach is measured from this height above the character's feet (about chest height).
@export var reach_origin_height: float = 1.0
## How far the camera ray looks. Only needs to be longer than max zoom + reach.
@export var ray_length: float = 20.0

@export_group("Hitting")
## Damage per hit. Bare hands = 1. Tools will raise this in a later step.
@export var hit_damage: int = 1
## Seconds between swings. Holding the hit button keeps swinging.
@export var hit_cooldown: float = 0.6

## The physics body currently targeted, or null.
var target: Node3D = null

var _cooldown_left: float = 0.0


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	# The targeted object might have been deleted (e.g. a tree that broke).
	if target != null and not is_instance_valid(target):
		target = null
		target_changed.emit(null)

	var new_target := _find_target()
	if new_target != target:
		target = new_target
		target_changed.emit(target)

	_try_hit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and target != null:
		var interactable := Interactable.find_on(target)
		if interactable != null:
			interactable.interact(body)
			get_viewport().set_input_as_handled()


func _try_hit() -> void:
	if _cooldown_left > 0.0 or target == null:
		return
	if not Input.is_action_pressed("hit"):
		return
	# A click that just recaptures the mouse shouldn't count as a hit.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not InputPrompts.using_gamepad:
		return
	var hittable := Hittable.find_on(target)
	if hittable == null:
		return
	hittable.take_hit(body, hit_damage)
	_cooldown_left = hit_cooldown


func _find_target() -> Node3D:
	var from := camera.global_position
	var to := from - camera.global_basis.z * ray_length  # Cameras look along -Z.

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # World layer only: skips the player and dropped items.
	query.exclude = [body.get_rid()]

	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var reach_origin := body.global_position + Vector3.UP * reach_origin_height
	if reach_origin.distance_to(hit.position) > reach:
		return null

	var collider: Node3D = hit.collider
	if Interactable.find_on(collider) != null or Hittable.find_on(collider) != null:
		return collider
	return null
