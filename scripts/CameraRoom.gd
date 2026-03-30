class_name CameraRoom
extends Node2D

@export var room_up: CameraRoom = null
@export var room_down: CameraRoom = null
@export var room_left: CameraRoom = null
@export var room_right: CameraRoom = null

# Rooms sharing the same group_id >= 0 use bounded follow.
# Set to -1 for a normal single-pan room.
@export var group_id: int = -1

# The bounding rect for this room (used for clamping the follow camera).
# Set this manually to match your room's actual tile/art boundaries.
@export var bounds: Rect2 = Rect2(0, 0, 640, 360)

func get_world_bounds() -> Rect2:
	# Offset the exported bounds by this node's global position,
	# so you can place the node at the room center and define
	# bounds relative to that center.
	return Rect2(global_position + bounds.position, bounds.size)

func get_neighbor(direction: Vector2) -> CameraRoom:
	if direction == Vector2.UP:    return room_up
	if direction == Vector2.DOWN:  return room_down
	if direction == Vector2.LEFT:  return room_left
	if direction == Vector2.RIGHT: return room_right
	return null
