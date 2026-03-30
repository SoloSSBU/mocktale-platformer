# Explosion.gd
extends AnimatedSprite2D  # or Node2D if the root is Node2D
@export var pos = Vector2.ZERO

func _ready():
	animation_finished.connect(_on_animation_finished)

func _process(_delta):
	position = pos

func _on_animation_finished():
	queue_free()
