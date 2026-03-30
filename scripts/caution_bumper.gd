extends Node2D

@export var minecart: Node
@export var activate_animation := "activate"
@export var deactivate_animation := "idle"
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	sprite.stop()

func _on_minecart_activated() -> void:
	sprite.play(activate_animation)

func _on_minecart_deactivated() -> void:
	sprite.play(deactivate_animation)
