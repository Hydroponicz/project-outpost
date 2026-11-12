extends StaticBody3D
## Gray-box test object for the interaction system.
## Changes color each time it's used.

const COLORS: Array[Color] = [
	Color(0.8, 0.8, 0.8),
	Color(0.9, 0.3, 0.3),
	Color(0.3, 0.8, 0.4),
	Color(0.3, 0.5, 0.9),
]

var _color_index: int = 0
var _material := StandardMaterial3D.new()

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	# Each box gets its own material, so boxes change color independently.
	_material.albedo_color = COLORS[0]
	_mesh.material_override = _material
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(_by: Node) -> void:
	_color_index = (_color_index + 1) % COLORS.size()
	_material.albedo_color = COLORS[_color_index]
