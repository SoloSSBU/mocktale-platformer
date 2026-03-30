extends AnimatedSprite2D

@onready var player = $Player

func _ready():
	play("idle")

func process(_delta):
	player.velocity = Vector2.ZERO
