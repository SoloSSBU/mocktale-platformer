extends Node

@onready var level_container = $LevelContainer
@onready var pause_menu = $PauseMenu
var current_level: Node = null
var current_path: String
const LEVELS := {
	#"cave": preload("res://cave.tscn"),
	"snow": preload("res://scenes/snow.tscn"),
	"lava": preload("res://scenes/lava.tscn"),
	"sand": preload("res://scenes/sand.tscn"),
	"level1": preload("res://scenes/level1.tscn")
}

func _unhandled_input(event):
	if event.is_action_pressed("pause") and SceneTransition.transitioning == false:
		if get_tree().paused:
			pause_menu.close()
		else:
			pause_menu.open()

func _ready():
	load_level("level1")
	current_path = "res://level1.tscn"
	print(Input.get_connected_joypads())
	for pad in Input.get_connected_joypads():
		print(Input.get_joy_name(pad))
		
#func _input(event):
	#if event is InputEventJoypadButton:
		#print("Button: ", event.button_index)
	#if event is InputEventJoypadMotion:
		#print("Axis: ", event.axis, " value: ", event.axis_value)


func load_level(path: String):
	if current_level:
		current_level.queue_free()

	var scene = LEVELS[path]
	current_level = scene.instantiate()
	level_container.add_child(current_level)
	#$CameraHolder/Camera2D.set_camera_groups(
	#	current_level.camera_groups
	#)
	#current_level.camera = $CameraHolder/Camera2D
	
func reload_level() -> void:
	print("reloading level")
	# Remove the current level
	for child in level_container.get_children():
		child.queue_free()
	# Wait a frame for queue_free to process
	await get_tree().process_frame
	# Reload the level scene
	var level = load(current_path).instantiate()
	level_container.add_child(level)
	$CameraHolder/Camera2D.reinitialize()
