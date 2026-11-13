extends Node3D
## Shows the tool in the character's hand: a gray-box handle and a colored
## head (shaped a bit differently for axes and pickaxes). No animation yet.
## Sits on the character's Visual node, so it turns with the character.

@export var hotbar: Hotbar
@export var inventory: Inventory

var _shown_item: ItemData = null
var _model: Node3D = null


func _ready() -> void:
	hotbar.selection_changed.connect(_on_selection_changed)
	inventory.changed.connect(_update)
	_update()


func _on_selection_changed(_index: int) -> void:
	_update()


func _update() -> void:
	var held := hotbar.get_held_tool()
	var item: ItemData = held.item if held != null else null
	if item == _shown_item:
		return
	_shown_item = item
	if _model != null:
		_model.queue_free()
		_model = null
	if item != null:
		_model = _build_model(item)
		add_child(_model)


func _build_model(item: ItemData) -> Node3D:
	var root := Node3D.new()

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.5, 0.35, 0.2)
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.05, 0.6, 0.05)
	handle_mesh.material = wood
	var handle := MeshInstance3D.new()
	handle.mesh = handle_mesh
	handle.position = Vector3(0, 0.3, 0)
	root.add_child(handle)

	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = item.drop_color
	var head_mesh := BoxMesh.new()
	head_mesh.material = head_material
	var head := MeshInstance3D.new()
	if item.tool_type == &"pickaxe":
		head_mesh.size = Vector3(0.06, 0.07, 0.42)  # Long pick, both ways.
		head.position = Vector3(0, 0.58, 0)
	else:
		head_mesh.size = Vector3(0.06, 0.16, 0.2)  # Axe blade, forward.
		head.position = Vector3(0, 0.52, -0.1)
	head.mesh = head_mesh
	root.add_child(head)

	return root
