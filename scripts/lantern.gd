extends Node2D

@export var lightrange :float = 1
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$PointLight2D.scale = Vector2(lightrange, lightrange)
