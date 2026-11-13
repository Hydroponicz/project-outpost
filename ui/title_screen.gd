extends Control
## The first screen: Continue (only if a save exists), New Game, Quit.
## Mouse: click. Gamepad / keyboard: up/down, A / Enter.
## New Game over an existing save asks for a second press to confirm.

var _options: Array[StringName] = []
var _rows: Array[RecipeRow] = []
var _cursor: int = 0
var _confirm_new_game: bool = false

@onready var _list: VBoxContainer = $Center/VBox/List


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if SaveSystem.has_save():
		_options.append(&"continue")
	_options.append_array([&"new_game", &"quit"])
	for i in _options.size():
		var row := RecipeRow.new()
		row.index = i
		row.hovered.connect(_on_row_hovered)
		row.clicked.connect(_choose)
		_list.add_child(row)
		_rows.append(row)
	_refresh()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("menu_accept"):
		_choose(_cursor)
	elif Input.is_action_just_pressed("menu_up"):
		_move(-1)
	elif Input.is_action_just_pressed("menu_down"):
		_move(1)


func _move(step: int) -> void:
	_cursor = clampi(_cursor + step, 0, _rows.size() - 1)
	_confirm_new_game = false
	_refresh()


func _choose(index: int) -> void:
	match _options[index]:
		&"continue":
			SaveSystem.continue_game()
		&"new_game":
			if SaveSystem.has_save() and not _confirm_new_game:
				_confirm_new_game = true  # Ask once more before wiping the save.
				_cursor = index
				_refresh()
			else:
				SaveSystem.new_game()
		&"quit":
			get_tree().quit()


func _on_row_hovered(index: int) -> void:
	if index != _cursor:
		_confirm_new_game = false
	_cursor = index
	_refresh()


func _refresh() -> void:
	for i in _rows.size():
		var title := ""
		var detail := ""
		match _options[i]:
			&"continue":
				title = "Continue"
			&"new_game":
				title = "New Game"
				if _confirm_new_game:
					detail = "This deletes your save. Press again to confirm."
			&"quit":
				title = "Quit"
		_rows[i].show_entry(title, detail, true, i == _cursor)
