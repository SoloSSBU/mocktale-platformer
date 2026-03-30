extends Area2D

@export var launch_speed := -600  # negative = up

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	# Make sure we only affect the player
	if body.is_in_group("player"):
		# Launch the player upward
		body.velocity.y = launch_speed

		# Optional: add a small animation / sound
		if has_node("AnimationPlayer"):
			$AnimationPlayer.play("bounce")
		if has_node("AudioStreamPlayer2D"):
			$AudioStreamPlayer2D.play()
