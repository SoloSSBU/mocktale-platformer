extends StaticBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var detector: Area2D = $TopDetector
@onready var puff = $Puff
@onready var flash: ColorRect = $Flash

@export var shake_amount: float = 3.0
@export var shake_time: float = 0.2
@export var fade_out_time: float = 0.35
@export var fade_in_time: float = 0.35
@export var delay_before_fall: float = 0.1
@export var respawn_delay: float = 1.0

var triggered := false
var original_position: Vector2


func _ready():
	detector.body_entered.connect(_on_body_entered)
	sprite.play("idle")
	original_position = sprite.position
	modulate.a = 1.0
	flash.modulate.a = 0.0


func _on_body_entered(body):
	if triggered:
		return
		
	if body.is_in_group("player"):
		# Get the platform's "up" direction (its local Y axis in world space)
		var platform_normal = global_transform.y
		print(platform_normal)
		print(body.velocity.dot(platform_normal))
		# If dot product >= 0, player is moving in the same direction as (or perpendicular to) the normal
		# We want them moving INTO the platform, so we check <= 0
		if body.velocity.dot(platform_normal) >= -1:
			triggered = true
			start_cycle()

#func _on_body_entered(body):
	#if triggered:
		#return
		#
	#if body.is_in_group("player") and body.velocity.y >= 0:
		#triggered = true
		#start_cycle()


func start_cycle():
	sprite.play("falling")
	await shake()
	# Wait until animation reaches frame 2
	while sprite.animation == "falling" and sprite.frame < 2:
		await sprite.frame_changed

	collision.disabled = true
	print("coll disabled")

	
	await get_tree().create_timer(delay_before_fall).timeout
	puff.emitting = true

	# Fade out
	var tween_out = create_tween()
	tween_out.tween_property(sprite, "modulate:a", 0.0, fade_out_time)
	await tween_out.finished

	await get_tree().create_timer(respawn_delay).timeout

	# Wait until player is no longer overlapping
	await wait_until_clear()

	respawn()


func shake():
	var timer := 0.0
	while timer < shake_time:
		timer += get_process_delta_time()
		sprite.position = original_position + Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		await get_tree().process_frame
	sprite.position = original_position


func wait_until_clear():
	while true:
		var overlapping := false
		
		for body in detector.get_overlapping_bodies():
			if body.is_in_group("player"):
				overlapping = true
				break
		
		if not overlapping:
			return
		
		await get_tree().process_frame


func respawn():
	sprite.play("idle")
	#modulate.a = 0.0

	# Fade in
	var tween_in = create_tween()
	tween_in.tween_property(sprite, "modulate:a", 1.0, fade_in_time)

	# White flash
	flash.modulate.a = 1.0
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.2)

	await tween_in.finished
	
	print("coll enabled")
	collision.disabled = false
	triggered = false
