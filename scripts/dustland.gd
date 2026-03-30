extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var anim := randi() % 3
	$AnimatedSprite2D.play("dust" + str(anim + 1))

func _on_animation_finished():
	queue_free()
