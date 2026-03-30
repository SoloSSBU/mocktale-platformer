@tool
extends Node2D

@export var room_size := Vector2(640, 360)
@export var line_color := Color(1.0, 1.0, 1.0, 1.0)
@export var line_width := 3.0

func _process(_delta):
	if Engine.is_editor_hint():
		queue_redraw()

func _ready():
	if not Engine.is_editor_hint():
		queue_free()


func _draw():
	var half_extent := 10  # how many rooms in each direction

	# Vertical room boundaries
	for x in range(-half_extent, half_extent + 1):
		var x_pos :int = round(x * room_size.x)
		draw_line(
			Vector2(x_pos, -half_extent * room_size.y),
			Vector2(x_pos,  half_extent * room_size.y),
			line_color,
			line_width
		)

	# Horizontal room boundaries
	for y in range(-half_extent, half_extent + 1):
		var y_pos :int = round(y * room_size.y)
		draw_line(
			Vector2(-half_extent * room_size.x, y_pos),
			Vector2( half_extent * room_size.x, y_pos),
			line_color,
			line_width
		)
