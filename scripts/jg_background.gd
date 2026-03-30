extends Node2D

@export var camera: Camera2D
@export var far_speed := 0.1
@export var farmid_speed := 0.2
@export var mid_speed := 0.35
@export var nearmid_speed := 0.55
@export var near_speed := 0.75
@export var fog1_speed := 8.0
@export var fog2_speed := 5.0

var _fog1_offset := 0.0
var _fog2_offset := 0.0

func _ready():
	process_priority = 0

func _physics_process(delta):
	if camera == null:
		camera = get_viewport().get_camera_2d()
	if camera == null:
		return

	_update_layer($Far, far_speed)
	_update_layer($FarMid, farmid_speed)
	_update_layer($Mid, mid_speed)
	_update_layer($NearMid, nearmid_speed)
	_update_layer($Near, near_speed)
	_update_fog(delta)

func _update_layer(sprite: Sprite2D, speed: float):
	var cam_pos := camera.get_screen_center_position()
	var scroll_x := cam_pos.x * speed
	sprite.global_position.x = cam_pos.x - scroll_x

func _update_fog(delta: float):
	_fog1_offset -= fog1_speed * delta
	_fog2_offset -= fog2_speed * delta

	var fog1_width :float= $Fog1.texture.get_width() * $Fog1.scale.x
	var fog2_width :float= $Fog2.texture.get_width() * $Fog2.scale.x
	_fog1_offset = fposmod(_fog1_offset, fog1_width)
	_fog2_offset = fposmod(_fog2_offset, fog2_width)

	$Fog1.global_position.x = _fog1_offset
	$Fog2.global_position.x = _fog2_offset
