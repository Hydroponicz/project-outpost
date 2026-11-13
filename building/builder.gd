class_name Builder
extends Node
## Lives on the player. While the hammer is selected on the hotbar:
##   - Build menu (RMB / Y) picks a piece.
##   - A see-through "ghost" follows the crosshair: green = can place,
##     red = blocked (overlapping something, or missing materials).
##   - Aiming at an existing piece snaps the ghost so their snap points
##     line up (wall onto floor edge, floor next to floor, ...).
##     Aiming at open ground places it freely.
##   - Hit (LMB / RT) places, scroll / d-pad left-right rotates,
##     MMB / B removes the piece you're looking at (full refund).
##
## No workbench is needed to build.

## Emitted when the on-screen build hint text changes ("" = hide it).
signal hint_changed(text: String)

const PIECE_FOLDER := "res://building/pieces/"
## Rotation step, like Valheim.
const ROTATION_STEP := 0.39269908  # 22.5 degrees, in radians.

@export var camera: Camera3D
@export var body: CharacterBody3D
@export var hotbar: Hotbar
@export var inventory: Inventory
@export var camera_rig: CameraRig
@export var build_menu: BuildMenu
## How far away (from the character) you can place and remove pieces.
@export var build_range: float = 8.0
## How much (in meters, per side) pieces may overlap and still be placed.
## Needed because walls stand centered on floor edges, so floors on top of
## walls and walls meeting at corners overlap by a sliver.
@export var overlap_tolerance: float = 0.125
@export var ghost_color_ok: Color = Color(0.3, 1.0, 0.4, 0.4)
@export var ghost_color_blocked: Color = Color(1.0, 0.3, 0.3, 0.4)

## False while a menu is open. Turning it back on blocks placing until the
## hit button is released (so the click that picked a piece doesn't place one).
var enabled: bool = true:
	set(value):
		if value and not enabled:
			_place_blocked = true
		enabled = value
## Every piece found in PIECE_FOLDER, in menu order.
var pieces: Array[BuildPieceData] = []
## The piece chosen in the build menu, or null.
var selected: BuildPieceData = null

var _templates: Dictionary = {}  # BuildPieceData -> PieceTemplate
var _ghost: Node3D = null
var _ghost_material := StandardMaterial3D.new()
var _rotation_steps: int = 0
var _placement := Transform3D()
var _placement_ok: bool = false
var _remove_target: BuildPiece = null
var _hint: String = ""
## See "enabled". Also set by a click that grabs the mouse back after Esc.
var _place_blocked: bool = false


## What the builder needs to know about a piece without placing it:
## its meshes (for the ghost), snap points, and collision shape.
class PieceTemplate:
	var meshes: Array = []  # [Mesh, Transform3D] pairs
	var snaps: Array[Vector3] = []
	var query_shape: Shape3D
	var shape_xform := Transform3D()
	var center := Vector3.ZERO
	var radius: float = 1.0


func _ready() -> void:
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_load_pieces()


func is_active() -> bool:
	return enabled and hotbar.is_holding(&"hammer")


func select_piece(piece: BuildPieceData) -> void:
	selected = piece
	_rebuild_ghost()


func get_piece(id: StringName) -> BuildPieceData:
	for piece in pieces:
		if piece.id == id:
			return piece
	return null


func has_materials(piece: BuildPieceData) -> bool:
	for cost in piece.cost:
		if inventory.count_item(cost.item) < cost.amount:
			return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not is_active():
		return
	if event.is_action_pressed("build_menu"):
		build_menu.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_remove"):
		_try_remove()
		get_viewport().set_input_as_handled()
	elif selected != null and event.is_action_pressed("build_rotate_left"):
		_rotation_steps -= 1
		get_viewport().set_input_as_handled()
	elif selected != null and event.is_action_pressed("build_rotate_right"):
		_rotation_steps += 1
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# A click while the mouse is free just grabs it back; don't place with it.
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_place_blocked = true


func _physics_process(_delta: float) -> void:
	var active := is_active()
	camera_rig.scroll_zoom_locked = active and selected != null  # Scroll rotates instead.

	var hit := _raycast() if active else {}
	_update_remove_target(hit)
	_update_ghost(hit, active)
	_update_hint(active)

	# Placing is checked here as "just pressed" rather than from input events:
	# the right trigger is analog and sends a stream of events while squeezed,
	# which used to place several pieces at once.
	if _place_blocked:
		if not Input.is_action_pressed("hit"):
			_place_blocked = false
	elif active and selected != null and Input.is_action_just_pressed("hit"):
		_try_place()


# --- Placing ---

func _update_ghost(hit: Dictionary, active: bool) -> void:
	if _ghost == null:
		return
	if not active or selected == null or hit.is_empty():
		_ghost.visible = false
		_placement_ok = false
		return

	_placement = _compute_placement(hit)
	_placement_ok = not _overlaps(_placement) and has_materials(selected)
	_ghost.global_transform = _placement
	_ghost.visible = true
	_ghost_material.albedo_color = ghost_color_ok if _placement_ok else ghost_color_blocked


func _compute_placement(hit: Dictionary) -> Transform3D:
	var rotation_basis := Basis(Vector3.UP, _rotation_steps * ROTATION_STEP)
	var hit_pos: Vector3 = hit.position
	var placement := Transform3D(rotation_basis, hit_pos)  # Free placement on the ground.

	var target := BuildPiece.find_on(hit.collider)
	var hit_normal: Vector3 = hit.normal
	# Walls aimed at the top of a floor: go to its nearest edge, lined up.
	if target != null and selected.align_to_floor_edges and hit_normal.y > 0.7:
		var edge := _floor_edge_placement(target, hit_pos)
		if edge != Transform3D.IDENTITY:
			return edge

	var template: PieceTemplate = _templates[selected]
	if target == null or template.snaps.is_empty():
		return placement
	var target_points := target.get_snap_points()
	if target_points.is_empty():
		return placement

	# 1. The target's snap point nearest to where we're aiming.
	var anchor := target_points[0]
	for point in target_points:
		if point.distance_to(hit_pos) < anchor.distance_to(hit_pos):
			anchor = point

	# 2. Try lining up each of the ghost's snap points with it. Prefer the one
	#    that puts the piece on the side we're aiming from, and that doesn't
	#    overlap anything.
	var desired_center := hit_pos + hit_normal * template.radius
	var best_score := INF
	for snap in template.snaps:
		var origin := anchor - rotation_basis * snap
		var candidate := Transform3D(rotation_basis, origin)
		var score := (origin + rotation_basis * template.center).distance_to(desired_center)
		if _overlaps(candidate):
			score += 100.0
		if score < best_score:
			best_score = score
			placement = candidate
	return placement


## Placement on the edge of a floor-like piece nearest to "aim", turned to
## run along that edge. Returns IDENTITY if the target isn't floor-shaped.
func _floor_edge_placement(target: BuildPiece, aim: Vector3) -> Transform3D:
	var root := target.get_parent() as Node3D
	var to_local := root.global_transform.affine_inverse()

	# The floor's size, from its snap points (in its own local space).
	var half_x := 0.0
	var half_z := 0.0
	var top := -INF
	for point in target.get_snap_points():
		var local := to_local * point
		half_x = maxf(half_x, absf(local.x))
		half_z = maxf(half_z, absf(local.z))
		top = maxf(top, local.y)
	if half_x < 0.1 or half_z < 0.1:
		return Transform3D.IDENTITY  # Not floor-shaped (e.g. a wall).

	# Which edge is closest to where we're aiming?
	var aim_local := to_local * aim
	var edge_mid: Vector3
	var turn := 0.0
	if half_x - absf(aim_local.x) < half_z - absf(aim_local.z):
		edge_mid = Vector3(signf(aim_local.x) * half_x, top, 0.0)  # Left/right edge,
		turn = PI * 0.5  # which runs front-to-back, so turn the wall 90 degrees.
	else:
		edge_mid = Vector3(0.0, top, signf(aim_local.z) * half_z)  # Front/back edge.
	if edge_mid.x == 0.0 and edge_mid.z == 0.0:
		edge_mid.z = half_z  # Aiming at the exact center: pick one.

	var root_basis := root.global_transform.basis.orthonormalized()
	return Transform3D(root_basis * Basis(Vector3.UP, turn), root.global_transform * edge_mid)


## True if the selected piece at "xform" would overlap the world or the player.
## The shape is shrunk by overlap_tolerance, so touching or slightly
## overlapping pieces are fine.
func _overlaps(xform: Transform3D) -> bool:
	var template: PieceTemplate = _templates[selected]
	if template.query_shape == null:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = template.query_shape
	query.transform = xform * template.shape_xform
	query.collision_mask = 1 | 2  # World + Player.
	return not body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _try_place() -> void:
	if selected == null or _ghost == null or not _ghost.visible:
		return
	if not has_materials(selected):
		_show_message("Not enough materials")
		return
	if not _placement_ok:
		_show_message("Can't build there")
		return
	for cost in selected.cost:
		inventory.remove_item(cost.item, cost.amount)
	var piece: Node3D = selected.scene.instantiate()
	get_tree().current_scene.add_child(piece)
	piece.global_transform = _placement


# --- Removing ---

func _update_remove_target(hit: Dictionary) -> void:
	_remove_target = null
	if hit.is_empty():
		return
	_remove_target = BuildPiece.find_on(hit.collider)


func _try_remove() -> void:
	if _remove_target == null or not is_instance_valid(_remove_target):
		return
	if not _remove_target.can_remove():
		_show_message("Empty it first")
		return
	var data := get_piece(_remove_target.piece_id)
	if data != null:
		for cost in data.cost:
			var leftover := inventory.add_item(cost.item, cost.amount)
			if leftover > 0:
				(body as Player).drop_items(cost.item, leftover)
	_remove_target.get_parent().queue_free()
	_remove_target = null


# --- Helpers ---

func _raycast() -> Dictionary:
	var from := camera.global_position
	var to := from - camera.global_basis.z * 30.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # World only (ground and built pieces).
	query.exclude = [body.get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or body.global_position.distance_to(hit.position) > build_range:
		return {}
	return hit


func _update_hint(active: bool) -> void:
	var text := ""
	if active:
		var parts: PackedStringArray = []
		parts.append("[%s] Pieces" % InputPrompts.get_label(&"build_menu"))
		if selected != null:
			parts.append("[%s] Place %s" % [InputPrompts.get_label(&"hit"), selected.display_name])
			parts.append("[%s] Rotate" % InputPrompts.get_label(&"build_rotate_left"))
		if _remove_target != null:
			var data := get_piece(_remove_target.piece_id)
			var piece_name := data.display_name if data != null else "piece"
			parts.append("[%s] Remove %s" % [InputPrompts.get_label(&"build_remove"), piece_name])
		text = "   ".join(parts)
	if text != _hint:
		_hint = text
		hint_changed.emit(_hint)


func _show_message(text: String) -> void:
	(body as Player).show_message(text)


func _rebuild_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if selected == null:
		return
	_ghost = Node3D.new()
	var template: PieceTemplate = _templates[selected]
	for pair in template.meshes:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = pair[0]
		mesh_instance.transform = pair[1]
		mesh_instance.material_override = _ghost_material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghost.add_child(mesh_instance)
	_ghost.visible = false
	get_tree().current_scene.add_child(_ghost)


func _load_pieces() -> void:
	for file in DirAccess.get_files_at(PIECE_FOLDER):
		# Exported games rename files to "name.tres.remap"; load the original name.
		var file_name := file.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var piece := load(PIECE_FOLDER + file_name) as BuildPieceData
		if piece != null and piece.scene != null:
			pieces.append(piece)
			_templates[piece] = _make_template(piece)
	pieces.sort_custom(func(a: BuildPieceData, b: BuildPieceData) -> bool: return a.sort_order < b.sort_order)


## Opens the piece's scene (without adding it to the world) and copies out
## what the ghost and the placement checks need.
func _make_template(piece: BuildPieceData) -> PieceTemplate:
	var template := PieceTemplate.new()
	var instance: Node3D = piece.scene.instantiate()
	_collect(instance, Transform3D.IDENTITY, template)
	instance.free()
	return template


func _collect(node: Node, xform: Transform3D, template: PieceTemplate) -> void:
	for child in node.get_children():
		var child_xform := xform
		if child is Node3D:
			child_xform = xform * (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			template.meshes.append([(child as MeshInstance3D).mesh, child_xform])
		elif child is Marker3D and node.name == "SnapPoints":
			template.snaps.append(child_xform.origin)
		elif child is CollisionShape3D and template.query_shape == null:
			var shape := (child as CollisionShape3D).shape
			template.shape_xform = child_xform
			template.center = child_xform.origin
			if shape is BoxShape3D:
				var box := shape.duplicate() as BoxShape3D
				var shrink := overlap_tolerance * 2.0
				box.size = Vector3(maxf(box.size.x - shrink, 0.01), maxf(box.size.y - shrink, 0.01),
						maxf(box.size.z - shrink, 0.01))
				template.query_shape = box
				template.radius = maxf(box.size.x, maxf(box.size.y, box.size.z)) * 0.5
			else:
				template.query_shape = shape
		_collect(child, child_xform, template)
