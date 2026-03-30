extends Node2D

@export var startup_time: float = 0.6
@export var spray_time: float = 3.0
@export var boost_force: float = 3000.0
@export var start_delay: float = 0
@export var max_upward_speed: float = -900.0  # negative because up
@export var cooldown_time: float = 1.5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area: Area2D = $Area2D
@onready var one_way: CollisionShape2D = $OneWayCollision/CollisionShape2D

var first_spray := true
var spraying := false
var player_in_area = null


func _ready():
	spraying = false
	one_way.disabled = true
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	sprite.frame_changed.connect(_on_frame_changed)
	await get_tree().create_timer(start_delay).timeout
	start_cycle()


func start_cycle():
	if not first_spray:
		await get_tree().create_timer(cooldown_time).timeout
	sprite.visible = true
	sprite.play("startup")
	area.get_child(0).disabled = true  # ensure off during startup
	await get_tree().create_timer(startup_time).timeout
	
	spraying = true
	sprite.play("spray")
	area.get_child(0).disabled = false  # only enable now
	one_way.disabled = false
	await get_tree().create_timer(spray_time).timeout
	
	spraying = false
	sprite.stop()
	one_way.disabled = true
	sprite.visible = false
	area.get_child(0).disabled = true
	first_spray = false
	
	start_cycle()


func _physics_process(_delta):
	if player_in_area:
		player_in_area.touching_geyser = spraying


func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_area = body
		if spraying:
			body.touching_geyser = true
		body.velocity.x = 0


func _on_body_exited(body):
	if body == player_in_area:
		body.touching_geyser = false
		player_in_area = null


func _on_frame_changed():
	if sprite.animation == "spray":
		if sprite.frame >= 2 and sprite.frame <= 8:
			one_way.disabled = false
		else:
			one_way.disabled = true
		if sprite.frame >= 9:
			area.get_child(0).disabled = true
