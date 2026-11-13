class_name World
extends Node3D
## The root of a playable level. Tells the SaveSystem when the level is
## ready (so a save can be loaded into it), gives access to the player, and
## keeps the navigation map (where workers can walk) up to date.
##
## The navigation map is rebuilt in the background shortly after anything
## changes it: building or removing pieces, trees falling or growing.
## Anything can ask for that with:
##   get_tree().call_group(&"world", &"request_nav_rebake")

## Wait this long after a change before rebuilding (changes often come in bursts).
const REBAKE_DELAY := 0.5

var _rebake_left: float = -1.0
var _rebake_again: bool = false

@onready var _player: Player = $Player
@onready var _navigation: NavigationRegion3D = $Navigation


func _ready() -> void:
	add_to_group(&"world")
	_navigation.bake_finished.connect(_on_bake_finished)
	SaveSystem.world_ready(self)
	request_nav_rebake()


func _process(delta: float) -> void:
	if _rebake_left < 0.0:
		return
	_rebake_left -= delta
	if _rebake_left <= 0.0:
		_rebake_left = -1.0
		if _navigation.is_baking():
			_rebake_again = true  # Finish this one first, then go again.
		else:
			_navigation.bake_navigation_mesh(true)  # true = in the background.


func get_player() -> Player:
	return _player


func request_nav_rebake() -> void:
	_rebake_left = REBAKE_DELAY


func _on_bake_finished() -> void:
	if _rebake_again:
		_rebake_again = false
		request_nav_rebake()
