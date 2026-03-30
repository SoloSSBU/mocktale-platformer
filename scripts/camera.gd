extends Camera2D

@export var pan_time := 0.25

var is_panning := false
var follow_player := false
var current_bounds: Rect2
var has_bounds := false
var player: CharacterBody2D
var half_view: Vector2
@onready var spawn_point: Marker2D = $Spawn
var spawn_room_name: String = ""
var spawn_entrance: String = ""
var spawn_time: float = 2.0
var spawn_timer: float = 0.0

var rooms: Node2D

var current_room: CameraRoom = null
var all_rooms: Array[CameraRoom] = []


func reinitialize() -> void:
	print("reinitializing")
	# Clear stale references
	player = null
	all_rooms.clear()
	current_room = null
	follow_player = false
	is_panning = false
	has_bounds = false
	
	# Re-find player
	player = get_tree().get_first_node_in_group("player")
	while player == null:
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
	
	# Re-collect rooms from the new level
	_collect_rooms()
	
	# Apply spawn if we have one, otherwise go to starting room
	if spawn_room_name != "":
		_apply_saved_spawn()
	else:
		current_room = _get_room_at(player.global_position)
		if current_room == null and all_rooms.size() > 0:
			current_room = all_rooms[0]
		if current_room:
			global_position = current_room.global_position
			_apply_room_state(current_room)
		player.reset_state()
			
func _apply_saved_spawn() -> void:
	print(player)
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	for room in all_rooms:
		if room.name == spawn_room_name:
			current_room = room
			global_position = room.global_position
			_apply_room_state(room)
			
			if player:
				print("resetting state")
				# Try the exact entrance first, then fall back through options
				var spawn_node := _get_spawn_node(room)
				
				if spawn_node:
					player.global_position = spawn_node.global_position
					player.spawn_position = spawn_node.global_position
					player.reset_state()
				else:
					# Last resort: use the room center
					player.global_position = room.global_position
					player.spawn_position = room.global_position
					player.reset_state()
					
				player.velocity = Vector2.ZERO
				player.is_dashing = false
				player.can_dash = true
				player.is_jumping = false
				player.is_climbing = false
				player.set_physics_process(true)
				player.modulate.a = 1.0
			return
	
	# Room name not found at all — fall back to whatever room the player is in
	current_room = _get_room_at(player.global_position)
	if current_room == null and all_rooms.size() > 0:
		current_room = all_rooms[0]
	if current_room:
		global_position = current_room.global_position
		_apply_room_state(current_room)
	if player:
		player.set_physics_process(true)
		player.modulate.a = 1.0
		
func _get_spawn_node(room: CameraRoom) -> Node2D:
	var attempts := ["Spawn_" + spawn_entrance, "Spawn_Left", "Spawn_Right", "Spawn_Up", "Spawn_Down"]
	for attempt in attempts:
		var node := room.get_node_or_null(attempt)
		if node:
			return node
	return null

func _ready():
	spawn_timer = spawn_time
	half_view = get_viewport_rect().size * 0.5
	process_priority = -1

	player = get_tree().get_first_node_in_group("player")
	while player == null:
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
	var level := get_parent().get_parent().get_node("LevelContainer").get_child(0)
	
	spawn_point.global_position = level.get_node("PlayerSpawn").global_position
	rooms = level.get_node("CameraRooms")
	# Grab all CameraRoom nodes from the level (assumed to be siblings or
	# children of a common root — adjust get_parent() depth as needed)
	_collect_rooms()

	current_room = _get_room_at(player.global_position)
	if current_room == null and all_rooms.size() > 0:
		current_room = all_rooms[0]

	if current_room:
		#global_position = current_room.global_position
		_apply_room_state(current_room)


func _physics_process(delta):
	if spawn_timer > 0:
		spawn_timer -= delta
	if is_panning:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return

	_check_room_transition()

	if follow_player:
		_update_camera_follow()

	_handle_dialogue_zoom()


# ─── Room Collection ────────────────────────────────────────────────────────

func _collect_rooms() -> void:
	all_rooms.clear()
	# Walk up to the level root and find all CameraRoom nodes beneath it.
	# Adjust this if your scene tree structure differs.
	var level_root := _get_level_root()
	if level_root:
		_find_rooms_recursive(level_root)

func _get_level_root() -> Node:
	# Camera2D -> CameraHolder -> Main, then grab LevelContainer by name
	var main := get_parent().get_parent()
	return main.get_node("LevelContainer")

func _find_rooms_recursive(node: Node) -> void:
	if node is CameraRoom:
		all_rooms.append(node)
	for child in node.get_children():
		_find_rooms_recursive(child)


# ─── Room Detection ──────────────────────────────────────────────────────────

# Find whichever room's bounds contain this position.
func _get_room_at(pos: Vector2) -> CameraRoom:
	for room in all_rooms:
		if room.get_world_bounds().has_point(pos):
			return room
	return null


# ─── Transition Logic ────────────────────────────────────────────────────────

func _check_room_transition() -> void:
	if is_panning or current_room == null:
		return
	var new_room := _get_room_at(player.global_position)
	if new_room != null and new_room != current_room:
		# Determine exit direction (which edge the player crossed)
		var exit_dir := _get_exit_direction(player.global_position, current_room)
		_on_room_changed(new_room, exit_dir)


# Returns the cardinal direction the player exited from based on which
# edge of the current room bounds they are closest to / beyond.
func _get_exit_direction(pos: Vector2, room: CameraRoom) -> Vector2:
	var bounds := room.get_world_bounds()
	var center := bounds.get_center()
	var delta := pos - center

	# Pick whichever axis has the greater overshoot relative to half-size
	var half := bounds.size * 0.5
	var norm_x := delta.x / half.x if half.x > 0 else 0.0
	var norm_y := delta.y / half.y if half.y > 0 else 0.0

	if abs(norm_x) >= abs(norm_y):
		return Vector2.RIGHT if delta.x > 0 else Vector2.LEFT
	else:
		return Vector2.DOWN if delta.y > 0 else Vector2.UP


func _on_room_changed(new_room: CameraRoom, exit_dir: Vector2) -> void:
	var prev_room := current_room

	# Only pan if switching to a different group (or either room has no group)
	var same_group := (
		prev_room.group_id >= 0
		and new_room.group_id >= 0
		and prev_room.group_id == new_room.group_id
	)

	if not same_group:
		await _pan_to_room(new_room, exit_dir)
		#spawn_point.global_position = new_room.get_child(0).global_position
		

	current_room = new_room
	_apply_room_state(new_room)

	# Spawn point update — pass exit direction so player script can set
	# the correct spawn edge for this room.
	print(player)
	if player:
		var entrance_dir := -exit_dir  # direction player came FROM
		print(new_room)
		spawn_room_name = new_room.name
		print(spawn_room_name)
		spawn_entrance = _dir_to_string(entrance_dir)
		print(spawn_entrance)
		
#func apply_spawn() -> void:
	#print(spawn_room_name)
	#if spawn_room_name == "":
		#return  # First load, no spawn info yet — use default player start
#
	#for room in all_rooms:
		#if room.name == spawn_room_name:
			#current_room = room
			#global_position = room.global_position
			#_apply_room_state(room)
#
			## Find the matching spawn marker inside the room node
			#var spawn_name := "Spawn_" + spawn_entrance
			#var spawn := room.get_node_or_null(spawn_name)
			#print(spawn)
			#print(player)
			#if spawn and player:
				##player.global_position = spawn.global_position
				#print("setting player pos")
			#return


# ─── Panning ─────────────────────────────────────────────────────────────────

func _pan_to_room(new_room: CameraRoom, exit_dir: Vector2) -> void:
	print(new_room.name)
	if new_room.name != "Room1" and spawn_timer <= 0:
		print("test")
	GameState.spawn_path = new_room.get_child(0).get_path()
	print(GameState.spawn_path)
	is_panning = true
	follow_player = false
	get_tree().paused = true

	# Pre-clamp camera inside current bounds before releasing limits
	if has_bounds:
		var clamped_x : float = clamp(global_position.x, current_bounds.position.x + half_view.x,
			current_bounds.position.x + current_bounds.size.x - half_view.x)
		var clamped_y : float = clamp(global_position.y, current_bounds.position.y + half_view.y,
			current_bounds.position.y + current_bounds.size.y - half_view.y)
		global_position = Vector2(clamped_x, clamped_y)

	_unbound()

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "global_position", new_room.global_position, pan_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

	# Refund jump/dash when moving upward
	if player:
		if exit_dir == Vector2.UP:
			player.velocity = Vector2(0, -500)
			player.is_dashing = false
			player.is_jumping = false
			player.is_climbing = false
		player.current_stamina = player.stamina
		player.can_dash = true

	get_tree().paused = false
	player.sync_held_keys()
	is_panning = false


# ─── Bounds & Follow ─────────────────────────────────────────────────────────

# Sets up bounds/follow state based on whether the room belongs to a group.
func _apply_room_state(room: CameraRoom) -> void:
	if room.group_id >= 0:
		# Collect all rooms in this group and build a combined bounding rect
		var group_bounds := _calculate_group_bounds(room.group_id)
		_set_bounds(group_bounds)
		follow_player = true
	else:
		_unbound()
		follow_player = false
		# Snap to the room's center position
		global_position = room.global_position


func _update_camera_follow() -> void:
	if not follow_player or not has_bounds or player == null or is_panning:
		return

	var target_x :float = clamp(
		player.global_position.x,
		current_bounds.position.x + half_view.x,
		current_bounds.position.x + current_bounds.size.x - half_view.x
	)
	var target_y :float = clamp(
		player.global_position.y,
		current_bounds.position.y + half_view.y,
		current_bounds.position.y + current_bounds.size.y - half_view.y
	)

	global_position = global_position.lerp(Vector2(target_x, target_y), 10.0 * get_physics_process_delta_time())


func _calculate_group_bounds(group_id: int) -> Rect2:
	var combined := Rect2()
	var first := true
	for room in all_rooms:
		if room.group_id == group_id:
			var b := room.get_world_bounds()
			if first:
				combined = b
				first = false
			else:
				combined = combined.merge(b)
	return combined


func _set_bounds(bounds: Rect2) -> void:
	current_bounds = bounds
	limit_left   = int(bounds.position.x)
	limit_top    = int(bounds.position.y)
	limit_right  = int(bounds.position.x + bounds.size.x)
	limit_bottom = int(bounds.position.y + bounds.size.y)
	has_bounds = true


func _unbound() -> void:
	limit_left   = int(-1e9)
	limit_top    = int(-1e9)
	limit_right  = int(1e9)
	limit_bottom = int(1e9)
	has_bounds   = false


# ─── Dialogue Zoom ───────────────────────────────────────────────────────────
var pre_dialogue_position: Vector2
var dialogue_zoom_active := false

func _handle_dialogue_zoom() -> void:
	if DialogueManager.active:
		if not dialogue_zoom_active:
			dialogue_zoom_active = true
			pre_dialogue_position = global_position
			
		# Midpoint between player and NPC
		var target_pos := player.global_position.lerp(DialogueManager.npc_position, 0.5) - Vector2(0, 50)
		
		# Clamp to bounds so camera doesn't pan outside the room
		if has_bounds:
			target_pos.x = clamp(target_pos.x, current_bounds.position.x + half_view.x, current_bounds.position.x + current_bounds.size.x - half_view.x)
			target_pos.y = clamp(target_pos.y, current_bounds.position.y + half_view.y, current_bounds.position.y + current_bounds.size.y - half_view.y)
		
		if zoom != Vector2(0.7, 0.7) or global_position != target_pos:
			var tween := create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "zoom", Vector2(0.7, 0.7), 0.7)
			tween.parallel().tween_property(self, "global_position", target_pos, 0.7)
	else:
		if dialogue_zoom_active:
			dialogue_zoom_active = false
			# Return to previous position
			var tween := create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "zoom", Vector2(0.5, 0.5), 0.7)
			tween.parallel().tween_property(self, "global_position", pre_dialogue_position, 0.7)



#func _handle_dialogue_zoom() -> void:
	#var target_zoom: Vector2
	#if DialogueManager.active:
		#target_zoom = Vector2(0.7, 0.7)
	#else:
		#target_zoom = Vector2(0.5, 0.5)
#
	#if zoom != target_zoom:
		#var tween := create_tween()
		#tween.set_trans(Tween.TRANS_SINE)
		#tween.set_ease(Tween.EASE_OUT)
		#tween.tween_property(self, "zoom", target_zoom, 0.7)


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _dir_to_string(dir: Vector2) -> String:
	if dir == Vector2.UP:    return "Up"
	if dir == Vector2.DOWN:  return "Down"
	if dir == Vector2.LEFT:  return "Left"
	return "Right"


#extends Camera2D
#
#@export var room_size := Vector2(640, 360)
#@export var pan_time := 0.25
#@onready var camera_holder := get_parent()
#
#var current_room := Vector2(0, -1)
#var is_panning := false
#var camera_groups: Array = []
#var follow_player := false
#var current_bounds : Rect2
#var has_bounds := false
#var player: CharacterBody2D
#var prev_group: Array = []
#var half_view: Vector2
#
#
#func _physics_process(_delta):
	#if is_panning:
		#return
	#if player == null:
		#player = get_tree().get_first_node_in_group("player")
	#if follow_player:
		#update_camera_follow()
	#if DialogueManager.active:
		#var tween := create_tween()
		#tween.set_trans(Tween.TRANS_SINE)
		#tween.set_ease(Tween.EASE_OUT)
#
		#tween.tween_property(
			#self,
			#"zoom",
			#Vector2(0.7, 0.7), # smaller = zoom in
			#0.7
		#)
	#elif zoom != Vector2(0.5, 0.5):
		#var tween := create_tween()
		#tween.set_trans(Tween.TRANS_SINE)
		#tween.set_ease(Tween.EASE_OUT)
#
		#tween.tween_property(
			#self,
			#"zoom",
			#Vector2(0.5, 0.5), # smaller = zoom in
			#0.7
		#)
#
## --- Call this every frame or _process/_physics_process ---
#func update_camera_follow() -> void:
	#if not follow_player or !has_bounds or player == null or is_panning:
		#return
#
#
#
	## Clamp the player's global position within current camera bounds
	#var target_x : float = clamp(
		#player.global_position.x,
		#current_bounds.position.x + half_view.x,
		#current_bounds.position.x + current_bounds.size.x - half_view.x
	#)
#
	#var target_y : float = clamp(
		#player.global_position.y,
		#current_bounds.position.y + half_view.y,
		#current_bounds.position.y + current_bounds.size.y - half_view.y
	#)
#
	## To smooth:
	#var speed := 10.0
	#global_position = global_position.lerp(Vector2(target_x, target_y), speed * get_physics_process_delta_time())
#
#
#func _ready():
	#player = get_tree().get_first_node_in_group("player")
	#while player == null:
		#await get_tree().process_frame
	#current_room = get_room_from_position(player.global_position)
	#global_position = get_room_center(current_room)
	#prev_group = get_special_group_for_room(current_room)
	#half_view = get_viewport_rect().size * 0.5
	## Process before the camera (lower priority = earlier execution)
	#process_priority = -1
	#
#
#func get_room_from_position(pos: Vector2) -> Vector2:
	#return Vector2(
		#floor(pos.x / room_size.x),
		#floor(pos.y / room_size.y)
	#)
#
#func get_room_center(room: Vector2) -> Vector2:
	#return (room * room_size + room_size / 2)
#
#func update_camera(player_pos: Vector2):
	#if is_panning:
		#return
	#var new_room = get_room_from_position(player_pos)
	#if new_room != current_room:
		#on_room_changed(new_room)
#
## Returns the camera bounds for a room, or null if it's a normal single room
## Returns a Rect2 for the room group, or sets has_bounds = false if it's a normal single room
#func get_bounds_for_room(room: Vector2) -> Rect2:
	#for group in camera_groups:
		#if room in group:
			## calculate bounds covering all rooms in this group
			#return calculate_group_bounds(group)
#
	## not in a special group
	#has_bounds = false
	#return Rect2()  # zero-size Rect2 as placeholder
#
#func prepare_for_pan() -> void:
	#is_panning = true
	#follow_player = false
	#unbound()  # remove all limits so tween can move freely
	#if player:
		#player.set_process(false)
#
#func pan_to_room(new_room: Vector2) -> void:
	#if is_panning:
		#return
	#is_panning = true
	#get_tree().paused = true
	## --- Step 1: Pre-clamp the camera inside the current bounds ---
	#if has_bounds:
		#var clamped_x = clamp(global_position.x, limit_left + room_size.x/2, limit_right - room_size.x/2)
		#var clamped_y = clamp(global_position.y, limit_top + room_size.y/2, limit_bottom - room_size.y/2)
		#global_position = Vector2(clamped_x, clamped_y)
	## --- Step 2: Unbind the camera so tween can move freely ---
	#unbound()  # sets limit_* to huge values or removes limits
#
	## --- Step 3: Tween to the new room ---
	#var tween = create_tween()
	#tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	#tween.tween_property(
		#self,
		#"global_position",
		#get_room_center(new_room),
		#pan_time
	#).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
#
	#await tween.finished
#
	## --- Step 4: Restore bounds if needed ---
	#if follow_player and current_bounds:
		#set_bounds(current_bounds)
#
	#is_panning = false
	##If moving up a room give a jump, dash refund and cancel dash
	#if player and new_room.y < current_room.y:
		#player.velocity = Vector2(0, -500)
		#player.is_dashing = false
		#player.is_jumping = false
		#player.is_climbing = false
	#if player:
		#player.current_stamina = player.stamina
		#player.can_dash = true
	#get_tree().paused = false
	#
#func set_camera_groups(groups: Array) -> void:
	#camera_groups = groups
#
#
## --- Called when the player enters a new room ---
#func on_room_changed(room_coord: Vector2) -> void:
	#var group : Array = get_special_group_for_room(room_coord)
#
	## Only pan if the group changed
	#if group != prev_group or group == []:
		#await pan_to_room(room_coord)
		#if player == null:
			#player = get_tree().get_first_node_in_group("player")
		#var room_str
		#if group != []:
			#room_str = str(int(group[0].x)) + ", " + str(int(group[0].y))
		#else:
			#room_str = str(int(room_coord.x)) + ", " + str(int(room_coord.y))
		#var entrance_dir: Vector2 = current_room - room_coord
		#var entrance_str: String
		#if entrance_dir == Vector2.UP:
			#entrance_str = "Up"
		#elif entrance_dir == Vector2.DOWN:
			#entrance_str = "Down"
		#elif entrance_dir == Vector2.LEFT:
			#entrance_str = "Left"
		#else:
			#entrance_str = "Right"
		#player.update_spawn(room_str, entrance_str)
#
	## Apply bounds and follow AFTER pan
	#if group != []:
		#set_bounds(calculate_group_bounds(group))
		#follow_player = true
	#else:
		#unbound()
		#follow_player = false
	#current_room = room_coord
	#prev_group = group
#
## --- Returns the camera group that contains this room, or null ---
#func get_special_group_for_room(room_coord: Vector2):
	#for group in camera_groups:
		#if room_coord in group:
			#return group
	#return []
#
## --- Sets camera limits for a multi-room area ---
#func unbound() -> void:
	##Effectively remove all camera limits
	#global_position = global_position
	#limit_left = int(-1e9)
	#limit_top = int(-1e9)
	#limit_right = int(1e9)
	#limit_bottom = int(1e9)
	#global_position = global_position
	## Mark that there are no bounds
	#has_bounds = false
#
#
#func set_bounds(bounds: Rect2) -> void:
	#current_bounds = bounds
	#limit_left = int(bounds.position.x)
	#limit_top = int(bounds.position.y)
	#limit_right = int(bounds.position.x + bounds.size.x)
	#limit_bottom = int(bounds.position.y + bounds.size.y)
	#has_bounds = true
#
#
## --- Combines multiple rooms into one camera bounding rect ---
#func calculate_group_bounds(group: Array) -> Rect2:
	#var min_coord := Vector2(9999, 9999)
	#var max_coord := Vector2(-9999, -9999)
#
	#for coord in group:
		#min_coord.x = min(min_coord.x, coord.x)
		#min_coord.y = min(min_coord.y, coord.y)
		#max_coord.x = max(max_coord.x, coord.x)
		#max_coord.y = max(max_coord.y, coord.y)
#
	#var pos := min_coord * room_size
	#var size := (max_coord - min_coord + Vector2.ONE) * room_size
#
	#return Rect2(pos, size)

	
