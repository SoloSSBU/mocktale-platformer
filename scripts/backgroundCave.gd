extends Node2D

@export var camera: Camera2D

@export var far_speed := 0.2
@export var mid_speed := 0.5
@export var near_speed := 0.8
@export var min_y := -4389.0


func _ready():
	# Process before the camera (lower priority = earlier execution)
	process_priority = 0

func _physics_process(_delta):
	if camera == null:
		camera = get_viewport().get_camera_2d()
	if camera == null:
		return
	_update_layer($Back, 1.0)
	_update_layer($Far, far_speed)
	_update_layer($Mid, mid_speed)
	_update_layer($Near, near_speed)



func _update_layer(sprite: Sprite2D, speed: float):
	var cam_pos := camera.get_screen_center_position()
	var cam_x := cam_pos.x
	#var tex_width := sprite.texture.get_width() * sprite.scale.x

	# Move relative to camera
	var scroll_x := cam_x * speed

	# Wrap so it repeats forever
	#scroll_x = fposmod(scroll_x, tex_width)

	# Center on camera, then apply scroll
	sprite.global_position.x = cam_x - scroll_x
	#var tex_height := sprite.texture.get_height() * sprite.scale.y
	
	#var cam_xform : Transform2D = camera.get_camera_screen_transform()
	#var cam_poss : Vector2 = -cam_xform.origin
	sprite.global_position.y = max(lerp(sprite.global_position.y, cam_pos.y, 0.8), min_y)
	
#func _update_layer(sprite: Sprite2D, speed: float):
	#var cam_pos := camera.get_screen_center_position()
	#var zoom := camera.zoom  # e.g. Vector2(0.5, 0.5)
	#
	#var scroll_x := cam_pos.x * speed
	#
	#sprite.position.x = (cam_pos.x - scroll_x) / zoom.x
	#sprite.position.y = lerp(sprite.position.y, cam_pos.y / zoom.y, 0.8) + 360
