extends Area2D

@export var direction: int = -1  # -1 for left, 1 for right
var wall_detected: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D):
	if body == get_parent():
		return
	if body is StaticBody2D or body is TileMapLayer or body is TileMap or body.is_in_group("walls"):
		wall_detected = true

func _on_body_exited(_body: Node2D):
	# Check if any walls still overlapping
	var still_has_wall = false
	for overlap in get_overlapping_bodies():
		if overlap != get_parent() and (overlap is StaticBody2D or overlap is TileMapLayer or overlap is TileMap):
			still_has_wall = true
			break
	
	wall_detected = still_has_wall
