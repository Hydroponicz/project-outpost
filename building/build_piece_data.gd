class_name BuildPieceData
extends Resource
## One thing the player can build with the hammer. Each piece is a .tres file
## in building/pieces/ and is loaded automatically.
##
## To add a piece: make a scene whose root is a StaticBody3D with its origin at
## the bottom center, a CollisionShape3D, a "BuildPiece" child (set its
## piece_id to this file's id), and optionally a "SnapPoints" node holding
## Marker3D children at the corners/edges. Then make a BuildPieceData file
## pointing at that scene.

## Unique ID. Must match the piece_id on the scene's BuildPiece node.
@export var id: StringName = &""
@export var display_name: String = "Piece"
## The scene that gets placed.
@export var scene: PackedScene
## Materials used to build it (fully refunded when removed).
@export var cost: Array[ItemAmount] = []
## Position in the build menu (lower = higher up).
@export var sort_order: int = 0
## Walls etc.: when aimed anywhere on top of a floor, jump to the floor's
## nearest edge and turn to line up with it (no manual rotating needed).
@export var align_to_floor_edges: bool = false
