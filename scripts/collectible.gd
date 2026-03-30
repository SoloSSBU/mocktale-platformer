extends Area2D

@export var next_room: String

func _ready():
	body_entered.connect(_on_body_entered)
	
func _change_scene_deferred(scene_path):
	get_tree().change_scene_to_file(scene_path)
	
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		call_deferred("_change_scene_deferred", next_room)
