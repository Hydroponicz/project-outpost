class_name World
extends Node3D
## The root of a playable level. Tells the SaveSystem when the level is
## ready (so a save can be loaded into it) and gives access to the player.

@onready var _player: Player = $Player


func _ready() -> void:
	SaveSystem.world_ready(self)


func get_player() -> Player:
	return _player
