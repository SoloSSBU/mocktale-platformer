# DeathPlane.gd
extends Area2D

func _ready():
	body_entered.connect(self._on_body_entered)

func _on_body_entered(body: Node):
	if body.is_in_group("player"):
		body.die()
