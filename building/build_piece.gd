class_name BuildPiece
extends Node
## Marks its parent (a StaticBody3D) as a player-built piece: it can be
## snapped to and removed with the hammer.
##
## Snap points are Marker3D children of a sibling node named "SnapPoints".

## Must match a BuildPieceData id (used to look up the refund when removed).
@export var piece_id: StringName = &""


## World positions of this piece's snap points.
func get_snap_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var holder := get_parent().get_node_or_null("SnapPoints")
	if holder == null:
		return points
	for child in holder.get_children():
		var marker := child as Node3D
		if marker != null:
			points.append(marker.global_position)
	return points


## Whether it can be removed right now (e.g. a chest with items in it can't).
func can_remove() -> bool:
	var owner_node := get_parent()
	if owner_node.has_method("can_be_removed"):
		return owner_node.call("can_be_removed")
	return true


## Finds the BuildPiece on a physics body, or null if it isn't a built piece.
static func find_on(node: Node) -> BuildPiece:
	if node == null:
		return null
	for child in node.get_children():
		if child is BuildPiece:
			return child
	return null
