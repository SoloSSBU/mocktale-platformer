extends CharacterBody2D

@export var windup_distance := 8.0
@export var windup_time := 0.12
@export var move_speed := 300.0
@export var return_speed := 80.0
@export var direction := -1
@export var gravity := 800

@onready var raycast: RayCast2D = $RayCast2D
@onready var top_trigger: Area2D = $TopTrigger
@export var idle_pause := 0.5
var idle_timer := 0.0

var start_position: Vector2
var state := "idle"
var windup_timer := 0.0
var triggered := false
var rail_y: float
signal activated
signal deactivated


func _ready():
	start_position = global_position
	raycast.target_position.x = abs(raycast.target_position.x) * direction
	top_trigger.body_entered.connect(_on_top_entered)
	top_trigger.body_exited.connect(_on_top_exited)
	rail_y = global_position.y
	add_to_group("minecart")
	motion_mode = MotionMode.MOTION_MODE_FLOATING
	process_physics_priority = -1


func _physics_process(delta):
	if state != "jumping":
		velocity.y = 0
	match state:
		"idle":
			deactivated.emit()
			velocity = Vector2.ZERO
			pass

		"windup":
			velocity.x = -direction * (windup_distance / windup_time)
			windup_timer += delta
			if windup_timer >= windup_time:
				state = "moving"


		"moving":
			velocity.x = direction * move_speed
			if raycast.is_colliding():
				var collider = raycast.get_collider()
				if collider is TileMapLayer and collider.name == "RailStops":
					velocity = Vector2.ZERO
					state = "returning"
				elif collider.name == "BrokenRail":
					velocity.y = -350
					state = "jumping"

		"returning":
			var to_start := start_position - global_position
			if to_start.length() < 1.0:
				global_position = start_position
				state = "idle"
				if triggered:
					state = "pausing"
					idle_timer = 0.0
			else:
				velocity.x = to_start.normalized().x * return_speed
				
		"jumping":
			velocity.x = direction * move_speed
			velocity.y += gravity * delta
			
		"pausing":
			velocity = Vector2.ZERO
			idle_timer += delta
			if idle_timer >= idle_pause:
				state = "windup"
				windup_timer = 0.0
				activated.emit()
	move_and_slide()
	if state != "jumping":
		global_position.y = rail_y


func _on_top_entered(body: Node):
	if not body.is_in_group("player"):
		return
	triggered = true
	if state == "idle":
		state = "windup"
		windup_timer = 0.0

func _on_top_exited(body: Node):
	if !triggered:
		return
	if not body.is_in_group("player"):
		return
	triggered = false

func check_for_player_landing():
	move_and_slide()

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider()

		if body.is_in_group("player") and collision.get_normal().y < -0.7:
			triggered = true
			state = "windup"
			windup_timer = 0.0
			break
