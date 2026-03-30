extends Node2D

@export var afterimage_scene: PackedScene
@export var source_sprite: AnimatedSprite2D
@export var spawn_interval: float = 0.05
@export var lifetime: float = 0.3
@export var color: Color = Color(0.5, 0.5, 0.5, 0.6)
@export var delay := 0.0
var _position_history: Array = []

var _active: bool = false
var _timer: float = -0.1
var _afterimages := []

func set_active(active: bool) -> void:
	# Only reset timer when transitioning from inactive to active
	#if active and not _active:
		#_timer = spawn_interval  # Start ready to spawn immediately
	_active = active

func start():
	set_active(true)
	#_spawn_afterimage()  # Spawn one immediately

func stop():
	set_active(false)
	_timer = -0.05
	#clear_all()  # <-- add this

func clear_all() -> void:
	for entry in _afterimages:
		if entry.node and is_instance_valid(entry.node):
			entry.node.queue_free()
	_afterimages.clear()

func _exit_tree() -> void:
	clear_all()  # <-- catches the "scene reloads mid-afterimage" case

func _process(delta: float) -> void:
	if source_sprite:
		_position_history.append({
			"pos": source_sprite.global_position,
			"rot": source_sprite.global_rotation
		})

		# Keep history length reasonable (0.5 sec buffer is plenty)
		if _position_history.size() > 60:
			_position_history.pop_front()
	
	if _active:
		_timer += delta
		if _timer >= spawn_interval:
			_timer -= spawn_interval
			_spawn_afterimage()
	
	_update_lifetimes(delta)

func _spawn_afterimage() -> void:
	if afterimage_scene == null:
		push_warning("afterimage_scene not assigned!")
		return
	
	elif source_sprite == null:
		push_warning("source_sprite not assigned!")
		return
		
	var instance = afterimage_scene.instantiate()
	# Account for the sprite's offset when positioning
	#var spawn_pos = source_sprite.global_position
	var frames_back := int(delay * 60.0)  # delay is in seconds
	frames_back = clamp(frames_back, 0, _position_history.size() - 1)

	var history_index = _position_history.size() - 1 - frames_back
	var history = _position_history[history_index]

	var spawn_pos = history.pos
	if source_sprite is AnimatedSprite2D:
		# Add the offset influence for AnimatedSprite2D
		var offset_rotated = source_sprite.offset.rotated(source_sprite.global_rotation)
		spawn_pos += offset_rotated * source_sprite.global_scale
	
	instance.global_position = spawn_pos
	#instance.global_rotation = source_sprite.global_rotation
	
	instance.global_rotation = history.rot
	
	get_tree().current_scene.add_child(instance)
	
	if instance.has_method("setup"):
		instance.setup(source_sprite)
	else:
		push_warning("AfterImage instance does not have setup()")
		return
	
	if instance.has_method("set_color"):
		instance.set_color(color)
	
	var sprite_ref = instance.get_node_or_null("Sprite2D")
	
	_afterimages.append({
		"node": instance,
		"time": 0.0,
		"sprite": sprite_ref
	})

func _update_lifetimes(delta: float) -> void:
	for i in range(_afterimages.size()):
		var entry = _afterimages[i]
		entry.time += delta
		var percent = clamp(entry.time / lifetime, 0.0, 1.0)
		var fade_alpha = 1.0 - percent
		if entry.sprite and is_instance_valid(entry.sprite):
			var mat = entry.sprite.material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("fade_alpha", fade_alpha)
	# Delete once fade is complete
	while _afterimages.size() > 0 and _afterimages[0].time >= lifetime:
		var oldest = _afterimages[0]
		_afterimages.pop_front()
		if oldest.node and is_instance_valid(oldest.node):
			oldest.node.queue_free()
