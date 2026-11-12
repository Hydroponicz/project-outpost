extends Control
## A small dot in the center of the screen with a dark outline,
## so it's visible on both light and dark backgrounds.

@export var radius: float = 3.0
@export var color: Color = Color(1, 1, 1, 0.9)
@export var outline_color: Color = Color(0, 0, 0, 0.6)


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, radius + 1.5, outline_color)
	draw_circle(center, radius, color)
