extends PointLight2D

@export var player: Node2D
@export var fade_start_y := -4880.0
@export var fade_end_y := -4880.0
@export var min_energy := 0.0
@export var max_energy := 1.0

func _process(_delta):
	if player == null:
		player = get_parent() as Node2D
	if player == null:
		return
	var t := inverse_lerp(fade_start_y, fade_end_y, player.global_position.y)
	t = clamp(t, 0.0, 1.0)
	energy = lerp(min_energy, max_energy, t)
