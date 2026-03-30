extends CanvasLayer

@onready var color_rect = $ColorRect
@onready var anim_player = $AnimationPlayer
@onready var current_scene_path = get_tree().current_scene.scene_file_path
var transitioning = false

func _ready():
	# Make sure it's always on top
	layer = 100
	color_rect.visible = false

func fade_to_black(callback: Callable):
	color_rect.visible = true
	anim_player.play("fade_to_black")
	await anim_player.animation_finished
	callback.call()

func fade_from_black():
	anim_player.play("fade_from_black")
	await anim_player.animation_finished
	color_rect.visible = false

func wipe_transition(callback: Callable):
	color_rect.visible = true
	anim_player.play("wipe")
	await anim_player.animation_finished
	callback.call()
	
	await anim_player.animation_finished
	color_rect.visible = false

func reload_scene_with_transition():
	color_rect.visible = true
	transitioning = true
	anim_player.play("wipe")
	await anim_player.animation_finished
	reload_level()
	
	anim_player.play_backwards("wipe")
	await anim_player.animation_finished
	transitioning = false
	color_rect.visible = false
	
func reload_level() -> void:
	var main := get_tree().root.get_node("Main")
	main.reload_level()
