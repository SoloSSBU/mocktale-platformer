#extends Node
#
#var current_room: Node = null
#var player: Node = null
#
#func go_to_room(room_scene: PackedScene) -> void:
	## Remove old room
	#if current_room and current_room.is_inside_tree():
		#current_room.queue_free()
		#current_room = null
#
	## Instance the new room
	#current_room = room_scene.instantiate()
	#add_child(current_room) # <-- parent it to the RoomManager singleton, not the previous room
#
	## Move player to new start
	#if not player:
		#player = get_tree().get_nodes_in_group("player")[0]
#
	#if player and current_room.has_node("PlayerSpawn"):
		#pass
		#player.global_position = current_room.get_node("PlayerSpawn").global_position
