extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

func setup(source_sprite: Node2D) -> void:
	if not sprite:
		push_warning("Sprite2D child not found in AfterImage scene!")
		return
	
	# Make sure material is unique for this instance
	if sprite.material:
		sprite.material = sprite.material.duplicate()
	else:
		print("WARNING: No material on sprite!")
	
	# ... rest of setup code
	# Copy visual appearance
	if source_sprite is Sprite2D:
		sprite.texture = source_sprite.texture
		sprite.scale = source_sprite.scale
		sprite.flip_h = source_sprite.flip_h
		sprite.flip_v = source_sprite.flip_v
		sprite.centered = source_sprite.centered
	elif source_sprite is AnimatedSprite2D:
		var tex = source_sprite.sprite_frames.get_frame_texture(
			source_sprite.animation, source_sprite.frame
		)
		sprite.texture = tex
		sprite.scale = source_sprite.scale
		sprite.flip_h = source_sprite.flip_h
		sprite.flip_v = source_sprite.flip_v
		sprite.centered = source_sprite.centered
	
	sprite.modulate = Color(1, 1, 1, 1)

func set_color(c: Color) -> void:
	if sprite:
		sprite.material.set_shader_parameter("silhouette_color", c)
