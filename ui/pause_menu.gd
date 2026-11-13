class_name PauseMenu
extends CanvasLayer
## Esc / Start in the world: pauses the game and shows Resume, Save Game,
## Quit to Title (saves first) and Quit Game (saves first).
## Mouse: click. Gamepad / keyboard: up/down, A / Enter. Esc / Start / B resumes.
##
## Runs while the game is paused (process_mode = Always, set in the scene).

const OPTIONS: Array[String] = ["Resume", "Save Game", "Quit to Title", "Quit Game"]

@export var player: Player

var is_open: bool = false

var _rows: Array[RecipeRow] = []
var _cursor: int = 0

@onready var _list: VBoxContainer = $Center/Panel/Margin/VBox/List
@onready var _info: Label = $Center/Panel/Margin/VBox/Info


func _ready() -> void:
	visible = false
	for i in OPTIONS.size():
		var row := RecipeRow.new()
		row.index = i
		row.hovered.connect(_on_row_hovered)
		row.clicked.connect(_choose)
		_list.add_child(row)
		_rows.append(row)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if is_open:
		resume()
		get_viewport().set_input_as_handled()
	elif player.controls_enabled:  # Not while another menu is open (Esc closes that).
		open()
		get_viewport().set_input_as_handled()


## Read once per frame as "just pressed" (see the inventory screen for why).
func _process(_delta: float) -> void:
	if not is_open:
		return
	if Input.is_action_just_pressed("menu_cancel"):
		resume()
	elif Input.is_action_just_pressed("menu_accept"):
		_choose(_cursor)
	elif Input.is_action_just_pressed("menu_up"):
		_cursor = maxi(_cursor - 1, 0)
		_refresh()
	elif Input.is_action_just_pressed("menu_down"):
		_cursor = mini(_cursor + 1, _rows.size() - 1)
		_refresh()


func open() -> void:
	is_open = true
	visible = true
	_cursor = 0
	_info.text = ""
	player.set_controls_enabled(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func resume() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _choose(index: int) -> void:
	match index:
		0:
			resume()
		1:
			_info.text = "Game saved" if SaveSystem.save_game() else "Could not save!"
		2:
			SaveSystem.quit_to_title()
		3:
			SaveSystem.quit_game()


func _on_row_hovered(index: int) -> void:
	_cursor = index
	_refresh()


func _refresh() -> void:
	for i in _rows.size():
		_rows[i].show_entry(OPTIONS[i], "", true, i == _cursor)
