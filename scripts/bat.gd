extends CharacterBody2D

enum State { IDLE, FLYING_TO_TARGET, WAITING, RETURNING, DEAD }

@export var target_marker: Marker2D
var target_position: Vector2


@export var fly_speed := 200.0
@export var wait_time := 2.0

var state = State.IDLE
var player
var start_position: Vector2
var wait_timer := 0.0

@onready var sprite = $AnimatedSprite2D
@onready var animplayer = $AnimatedSprite2D/AnimationPlayer

func _ready():
	player = get_tree().get_first_node_in_group("player")
	start_position = global_position
	target_position = target_marker.global_position

func _physics_process(delta):
	# Check for dash at any point to interrupt and fly to target
	if player and player.is_dashing and state != State.DEAD:
		state = State.FLYING_TO_TARGET
		wait_timer = 0.0

	match state:
		State.IDLE:
			sprite.play("idle")
			velocity = Vector2.ZERO

		State.FLYING_TO_TARGET:
			sprite.play("flying")
			fly_toward(target_position, delta)
			if global_position.distance_to(target_position) < 4.0:
				global_position = target_position
				velocity = Vector2.ZERO
				state = State.WAITING

		State.WAITING:
			sprite.play("flying")
			velocity = Vector2.ZERO
			wait_timer += delta
			if wait_timer >= wait_time:
				state = State.RETURNING

		State.RETURNING:
			sprite.play("flying")
			fly_toward(start_position, delta)
			if global_position.distance_to(start_position) < 4.0:
				global_position = start_position
				velocity = Vector2.ZERO
				state = State.IDLE

	move_and_slide()

func fly_toward(destination: Vector2, _delta: float):
	var direction = (destination - global_position).normalized()
	velocity = direction * fly_speed
	sprite.flip_h = velocity.x > 0

func die():
	state = State.DEAD
	velocity = Vector2.ZERO
	sprite.play("death")
	animplayer.play("death")
	await sprite.animation_finished
	queue_free()

func _on_hitbox_body_entered(body):
	if body.name == "Player":
		body.die()
