#extends StaticBody2D
# Room.gd
extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var spawn_point: Marker2D = $PlayerSpawn
#First room in group should always be least x value if tied go least y value
@export var camera_groups := [
	[Vector2(-4,-1), Vector2(0,-1), Vector2(-1,-1), Vector2(-2,-1), Vector2(-3,-1),
	 Vector2(0, -2), Vector2(0, -3)]
]

func _ready():
	var camera = get_tree().get_first_node_in_group("room_camera")
	camera._collect_rooms()
	player.velocity = Vector2.ZERO
	#camera.apply_spawn()
	# Set player at spawn initially
	#respawn_player()
		
#func respawn_player():
	#if GameState.spawn_path:
		#player.global_position = get_node(GameState.spawn_path).global_position
	#player.velocity = Vector2.ZERO
	## reset other player states if needed
