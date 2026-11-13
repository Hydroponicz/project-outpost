class_name BuildMenu
extends CanvasLayer
## Lists the pieces the hammer can build, with their cost.
## Opened with RMB / Y while holding the hammer.
##   Mouse: click a piece.  Gamepad: up/down, A to pick, B to close.
## Picking "Stop building" puts the hammer away from building mode.

@export var player: Player
@export var builder: Builder
@export var inventory: Inventory

var is_open: bool = false

var _rows: Array[RecipeRow] = []
var _cursor: int = 0

@onready var _list: VBoxContainer = $Center/Panel/Margin/VBox/List


func _ready() -> void:
	visible = false
	# Row 0 = "Stop building", then one row per piece.
	for i in builder.pieces.size() + 1:
		var row := RecipeRow.new()
		row.index = i
		row.hovered.connect(_on_row_hovered)
		row.clicked.connect(_choose)
		_list.add_child(row)
		_rows.append(row)


func open() -> void:
	is_open = true
	visible = true
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Start on the currently selected piece.
	_cursor = builder.pieces.find(builder.selected) + 1 if builder.selected != null else 1
	_cursor = clampi(_cursor, 0, _rows.size() - 1)
	_refresh()


func close() -> void:
	is_open = false
	visible = false
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	# The same button that opened the menu closes it. (Handled as an event so
	# the press that OPENED it isn't also seen as closing it.)
	if is_open and event.is_action_pressed("build_menu"):
		close()
		get_viewport().set_input_as_handled()


## Read once per frame as "just pressed" (an analog stick sends a stream of
## events while held, which would skip several rows per push).
func _process(_delta: float) -> void:
	if not is_open:
		return
	if Input.is_action_just_pressed("menu_cancel") or Input.is_action_just_pressed("toggle_mouse_capture"):
		close()
	elif Input.is_action_just_pressed("menu_accept"):
		_choose(_cursor)
	elif Input.is_action_just_pressed("menu_up"):
		_cursor = maxi(_cursor - 1, 0)
		_refresh()
	elif Input.is_action_just_pressed("menu_down"):
		_cursor = mini(_cursor + 1, _rows.size() - 1)
		_refresh()


func _choose(index: int) -> void:
	builder.select_piece(null if index == 0 else builder.pieces[index - 1])
	close()


func _on_row_hovered(index: int) -> void:
	_cursor = index
	_refresh()


func _refresh() -> void:
	_rows[0].show_entry("Stop building", "Put the hammer's building mode away", true, _cursor == 0)
	for i in builder.pieces.size():
		var piece := builder.pieces[i]
		var parts: PackedStringArray = []
		for cost in piece.cost:
			parts.append("%s %d/%d" % [cost.item.display_name, inventory.count_item(cost.item), cost.amount])
		_rows[i + 1].show_entry(piece.display_name, "   ".join(parts),
				builder.has_materials(piece), _cursor == i + 1)
