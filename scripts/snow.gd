#extends StaticBody2D
# Room.gd
extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var spawn_point: Marker2D = $PlayerSpawn
@export var camera_groups := [
	[Vector2(0, -1)] 
]

func _ready():
	# Set player at spawn initially
	respawn_player()
		
func respawn_player():
	player.global_position = spawn_point.global_position
	player.velocity = Vector2.ZERO
	# reset other player states if needed
