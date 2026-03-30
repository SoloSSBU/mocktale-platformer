extends CharacterBody2D

# --- Movement Settings ---
@export var move_speed := 200.0
@export var accel := 1200.0
@export var air_accel := 700.0
@export var friction := 1500.0
@export var gravity := 1450.0
@export var max_fall_speed := 300
@export var jump_force := -400.0
@export var stomp_bounce_force := -400.0

# --- Jump Helpers ---
@export var coyote_time := 0.1
@export var jump_buffer := 0.1
var coyote_timer := 0.0
var jump_buffer_timer := 0.0

# --- Dash Settings ---
@export var dash_speed := 450.0
@export var dash_time := 0.2
@export var dash_cooldown := 0.2
@onready var afterimage = $AfterImageSpawner
@onready var kiwiafterimage = $KiwiAfterimage
var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var super_dash_window := 0.3
var super_dash_timer := 0.0
var dash_direction := Vector2.ZERO
var can_dash := true
var dash_initiated := false
var dash_left_ground := false
var dash_startup := 0.03
var is_frozen := false
var dash_startup_timer := 0.0

# --- Wall Slide / Wall Jump ---
@export var wall_slide_speed := 100.0
@export var wall_jump_horizontal := 300.0
@export var wall_jump_vertical := -300.0
const WALL_BOUNCE_GRAVITY_TIME: float = 0.15  # How long gravity is reduced
const WALL_BOUNCE_GRAVITY_MULT: float = 0.5  # Gravity multiplier during window
var wall_bounce_timer: float = 0.0
var wall_dir := 0

# --- Climb ---
@export var climb_speed := 80.0
@export var climb_snap_distance := 4.0
@export var climb_slip_speed := 60.0
var is_climbing := false
var stamina := 110.0
var current_stamina := 0.0
var climb_dir := 0
var converting_wall_jump := false
var top_out_timer := 0.0
var top_out_time := 0.15


# --- Wall Jump Lock ---
var wall_jump_lock_timer := 0.0
@export var wall_jump_lock_duration := 0.15
@export var wall_jump_blend_min := 0.0
@export var wall_jump_blend_max := 0.08

# --- Wall Stick / Slide ---
var wall_stick_timer := -1.0
@export var wall_stick_duration := 0.0
var wall_stick_velocity := 0.0
@export var wall_stick_gravity_scale := 0.5

# --- Wall Jump Leniency ---
@export var wall_coyote_time := 0.1
var wall_coyote_timer := 0.0
var last_wall_dir := 0

# --- Spawn ---
var spawn_position: Vector2

# --- Bouncing state ---
var is_bouncing := false

# --- Input direction ---
var input_dir := 0.0

# --- Direction facing ---
var facing_right := true

# --- Camera ---
@onready var camera: Camera2D = get_tree().get_first_node_in_group("room_camera")
@export var explosion_scene: PackedScene
@export var wind_scene: PackedScene
@export var dust_scene: PackedScene
@export var death_scene: PackedScene
@onready var rooms: Node2D = get_tree().get_first_node_in_group("rooms")
@onready var spawn: Marker2D = get_tree().get_first_node_in_group("spawn")

# --- Jump Helpers ---
@export var jump_cut_gravity_multiplier := 2.5   # multiplies gravity when jump released early
@export var jump_hold_time := 5.0              # max seconds you can hold jump for higher jump
var vel := Vector2.ZERO
var jump_timer := 0.0
var is_jumping := false

# --- Recent Platform Velocity ---
var max_floor_vel_recently: Vector2
var floor_vel_buffer_x := 0.0
var floor_vel_buffer_y := 0.0

# --- Jump Hangtime ---
@export var apex_gravity_multiplier := 0.5
@export var apex_velocity_threshold := 50.0   # how close to 0 counts as "apex"
var jump_was_released := false

# --- Geyser ---
var touching_geyser := false
var geyser_force := 3000
var max_geyser_velocity_y := -400

@onready var sprite := $Node2D/AnimatedSprite2D

@onready var wakeuptime := 0.35
var is_crouching := false

# ---Corner Correction---
const HEAD_CORRECTION_PIXELS := 9
var previous_position: Vector2

var ignore_just_pressed := false

var last_horizontal := 0  # store this as a member variable
var key_left_held := false
var key_right_held := false
var key_up_held := false
var key_down_held := false

func is_physically_held(action: String) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			if Input.is_physical_key_pressed(event.physical_keycode) or Input.is_key_pressed(event.keycode):
				return true
		elif event is InputEventJoypadButton:
			if Input.is_joy_button_pressed(event.device if event.device >= 0 else 0, event.button_index):
				return true
	return false

func sync_held_keys():
	key_left_held = Input.is_action_pressed("move_left")
	key_right_held = Input.is_action_pressed("move_right")
	key_up_held = Input.is_action_pressed("ui_up")
	key_down_held = Input.is_action_pressed("ui_down")

func apply_head_corner_correction(previous_velocity: Vector2, delta: float):
	if previous_velocity.y >= 0:
		return
	
	var expected_y = previous_position.y + previous_velocity.y * delta
	var actual_y = global_position.y
	
	# If we didn't move as far up as expected, we were blocked
	if actual_y <= expected_y + 0.5:
		return
	
	# Search for a valid horizontal snap
	var correction := 0

	for i in range(1, HEAD_CORRECTION_PIXELS + 1):
		# Check right
		if can_snap(Vector2(i, 0)):
			correction = i
			break

		# Check left
		if can_snap(Vector2(-i, 0)):
			correction = -i
			break

	if correction != 0:
		global_position.x += correction
		velocity.y = previous_velocity.y
		# Recover the lost upward movement from this frame
		global_position.y = previous_position.y + previous_velocity.y * delta

func can_snap(offset: Vector2) -> bool:
	if test_move(global_transform, offset):
		return false
	var new_transform := global_transform.translated(offset)
	# Offset slightly away from the edge before probing upward
	var inset := new_transform.translated(Vector2(sign(offset.x), 0))
	if test_move(inset, Vector2(0, -1)):
		return false
	return true

#func can_snap(offset: Vector2) -> bool:
	## 1. Horizontal space must be free
	#if test_move(global_transform, offset):
		#return false
#
	## 2. After moving horizontally,
	##    there must NOT be a ceiling above
	#var new_transform := global_transform.translated(offset)
#
	#if test_move(new_transform, Vector2(0, -1)):
		#return false
#
	#return true

const DASH_CORRECTION_PIXELS := 9

const DOWN_DASH_CORRECTION_PIXELS := 9

func apply_downward_dash_corner_correction(previous_velocity: Vector2):
	# Only downward dash
	if previous_velocity.y <= 0 or !is_dashing:
		return
		
	# Must be vertical dash
	if previous_velocity.x != 0:
		return
	
	# If vertical velocity didn't get blocked, do nothing
	if velocity.y == previous_velocity.y:
		return

	# We were blocked downward — try horizontal nudges
	for i in range(1, DOWN_DASH_CORRECTION_PIXELS + 1):

		# Try right
		if not test_move(global_transform, Vector2(i, 0)):
			var shifted := global_transform.translated(Vector2(i, 0))

			# From shifted position, can we move down?
			if not test_move(shifted, Vector2(0, 1)):
				global_position.x += i
				velocity.y = previous_velocity.y
				return

		# Try left
		if not test_move(global_transform, Vector2(-i, 0)):
			var shifted := global_transform.translated(Vector2(-i, 0))

			if not test_move(shifted, Vector2(0, 1)):
				global_position.x -= i
				velocity.y = previous_velocity.y
				return

func apply_dash_corner_correction(previous_velocity: Vector2):
	if previous_velocity.y != 0:
		return

	var dash_dir :int = sign(previous_velocity.x)
	if dash_dir == 0:
		return

	# Only if dash was blocked
	if sign(velocity.x) == dash_dir:
		return

	# --- 1️⃣ Try upward correction (ledge climb) ---
	for i in range(1, DASH_CORRECTION_PIXELS + 1):
		if test_move(global_transform, Vector2(0, -i)):
			continue

		var raised := global_transform.translated(Vector2(0, -i))

		if test_move(raised, Vector2(dash_dir, 0)):
			continue

		global_position.y -= i
		velocity.x = previous_velocity.x
		return

	# --- 2️⃣ Try downward correction (ceiling skim) ---
	for i in range(1, DASH_CORRECTION_PIXELS + 1):
		if test_move(global_transform, Vector2(0, i)):
			continue

		var lowered := global_transform.translated(Vector2(0, i))

		if test_move(lowered, Vector2(dash_dir, 0)):
			continue

		global_position.y += i
		velocity.x = previous_velocity.x
		return

func reset_state() -> void:
	is_crouching = false
	$CollisionShape2D.shape.size.y = 22
	$CollisionShape2D.position.y = -11
	velocity = Vector2.ZERO
	is_dashing = false
	can_dash = true
	is_jumping = false
	is_climbing = false
	set_physics_process(true)
	modulate.a = 1.0
	velocity = Vector2.ZERO
	uncrouch()
	for i in 3:
		move_and_slide()


func can_dash_snap(offset: Vector2) -> bool:
	var new_transform := global_transform.translated(offset)

	# 1. Space must be free at snap position
	if test_move(global_transform, offset):
		return false

	# 2. There must be ground below new position
	if not test_move(new_transform, Vector2(0, 1)):
		return false
	return true

# ---Squish---
@export var squish_stiffness := 260.0
@export var squish_damping := 20.0
var _base_scale := Vector2.ONE
var _scale_velocity := Vector2.ZERO
@onready var original_sprite_y = sprite.position.y
var squish_amount := 1.0

func squish(amount: Vector2):
	sprite.scale = Vector2(
		_base_scale.x * amount.x,
		_base_scale.y * amount.y
	)
	squish_amount = amount.y

# ---Dialogue Walk---
signal reached_target
var move_target: float
var moving_to_target := false
func walk_to_position(target: float):
	move_target = target
	moving_to_target = true
	
func update_spawn(room: String, entrance: String):
	var room_node : Node2D
	var new_spawn : Marker2D
	if rooms.has_node(room):
		room_node = rooms.get_node(room)
		if room_node.has_node("Spawn_" + entrance):
			new_spawn = room_node.get_node("Spawn_" + entrance)
			#GameState.spawn_path = str(new_spawn.get_path())
			spawn.position = new_spawn.position
	

func spawn_explosion(pos: Vector2):
	var explosion = explosion_scene.instantiate()
	explosion.get_child(0).global_position = pos
	explosion.get_child(0).pos = pos
	explosion.get_child(0).rotation = dash_direction.angle()
	get_tree().current_scene.add_child(explosion)  # add to root or level container
	#await get_tree().create_timer(0.15).timeout
	#var wind = wind_scene.instantiate()
	#get_tree().current_scene.add_child(wind)
	#wind.global_position = position
	#wind.rotation = dash_direction.angle()

func spawn_dust(pos: Vector2, jump_dir = 0):
	var dust = dust_scene.instantiate()
	dust.global_position = pos
	#dust.rotation = jump_dir * PI / 2
	var dustsprite := dust.get_child(0)
	if jump_dir != 0:
		dustsprite.rotation = jump_dir * PI / 2
		dustsprite.global_position.y -= 10
	dustsprite.global_position.y -= 12
	get_tree().current_scene.add_child(dust)  # add to root or level container
	
func spawn_death_animation(pos: Vector2):
	var death = death_scene.instantiate()
	death.global_position = pos
	get_tree().current_scene.add_child(death)

func has_floor_support() -> bool:
	return $FloorRay.is_colliding() or $FloorRay2.is_colliding()
	
func crouch():
	is_crouching = true
	$CollisionShape2D.shape.size.y = 16
	$CollisionShape2D.position.y = -8
	play_for_both("crouch")
	
func uncrouch():
	is_crouching = false
	$CollisionShape2D.shape.size.y = 24
	$CollisionShape2D.position.y = -12
	play_for_both("idle")

#Snaps player to wall at start of climb
func snap_to_wall():
	var max_snap := 4.0
	var half_width = $CollisionShape2D.shape.size.x / 2.0
	var from = global_position + Vector2(climb_dir * half_width, 0)
	var to = from + Vector2(climb_dir * max_snap, 0)
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [self]
	var result = get_world_2d().direct_space_state.intersect_ray(query)
	if result:
		global_position.x = result.position.x - (climb_dir * half_width)
		
func adjust_hitboxes(yoffset: float, ysize: float):
	sprite.offset.y = yoffset
	$CollisionShape2D.shape.size.y = ysize
	$WallJumpBoxLeft/CollisionShape2D.shape.size.y = ysize
	$WallJumpBoxRight/CollisionShape2D.shape.size.y = ysize
	$WallJumpBoxLeftSuper/CollisionShape2D.shape.size.y = ysize
	$WallJumpBoxRightSuper/CollisionShape2D.shape.size.y = ysize

func climb(delta):
	adjust_hitboxes(-65, 21)
	# Stay flush
	velocity.x = 0
	# Jump input
	if is_just_pressed("jump") or jump_buffer_timer > 0:
		wall_climb_jump()
		move_and_slide()
		return
	# If stamina available
	if current_stamina > 0:
		var v_input = Input.get_axis("ui_up", "ui_down")
		velocity.y = v_input * climb_speed
		if velocity.y < 0:
			sprite.play("climbing")
			current_stamina -= 45.45 * delta
		elif velocity.y > 0 and !has_floor_support():
			sprite.play("wall_slide")
			current_stamina -= 10.0 * delta
		else:
			sprite.play("climb_idle")
			current_stamina -= 10.0 * delta
		check_top_out()
	else:
		sprite.play("climb_tired")
		velocity.y = min(wall_slide_speed, velocity.y + gravity * delta * 0.5)

	move_and_slide()
	check_spikes()
	
func wall_climb_jump():
	var input = Input.get_axis("move_left", "move_right")
	# Holding away from wall?
	if input == -climb_dir or current_stamina <= 0:
		# Outward jump
		velocity.x = -climb_dir * wall_jump_horizontal
		velocity.y = wall_jump_vertical
		converting_wall_jump = false
		
	else:
		# Neutral jump
		velocity.x = 0
		velocity.y = wall_jump_vertical
		converting_wall_jump = true
		current_stamina -= 27.5
	is_climbing = false
	wall_jump_lock_timer = wall_jump_lock_duration
	jump_buffer_timer = 0
	is_dashing = false
	is_bouncing = false
	is_jumping = true
	jump_timer = 0.0
	jump_was_released = false
	wall_bounce_timer = WALL_BOUNCE_GRAVITY_TIME
	spawn_dust(global_position, -climb_dir)
	squish(Vector2(0.6, 1.4))
	
func check_top_out():

	if velocity.y >= 0:
		return  # Only check while climbing upward
	var half_height = $CollisionShape2D.shape.size.y / 2.0
	var half_width = $CollisionShape2D.shape.size.x / 2.0

	var wall_offset = climb_dir * (half_width + 1)

	# --- 1️⃣ Head check (should be EMPTY) ---
	var head_pos = $CollisionShape2D.global_position + Vector2(wall_offset, -half_height + 2)

	# --- 2️⃣ Mid check (should be EMPTY) ---
	var mid_pos = $CollisionShape2D.global_position + Vector2(wall_offset, 0)

	# --- 3️⃣ Foot check (should HIT) ---
	var foot_pos = $CollisionShape2D.global_position + Vector2(wall_offset, half_height - 2)
	if not point_hits_wall(head_pos) \
	and not point_hits_wall(mid_pos) \
	and point_hits_wall(foot_pos):

		perform_top_out()

func point_hits_wall(pos: Vector2) -> bool:

	var space = get_world_2d().direct_space_state

	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.exclude = [self]
	query.collision_mask = 0xFFFFFFFF

	var result = space.intersect_point(query)

	return not result.is_empty()

func perform_top_out():
	# Snap slightly upward so we clear edge
	global_position.y -= 12

	# Give diagonal hop
	velocity.x = climb_dir * 200
	velocity.y = -100
	top_out_timer = top_out_time
	is_climbing = false
	
func is_just_pressed(action: String) -> bool:
	if ignore_just_pressed:
		return false
	return Input.is_action_just_pressed(action)

func _unhandled_input(event):
	if event is InputEventKey or event is InputEventJoypadButton:
		if event.is_action_pressed("move_left"):
			key_left_held = true
			last_horizontal = -1
		elif event.is_action_released("move_left"):
			key_left_held = false
			if key_right_held:
				last_horizontal = 1
				
		if event.is_action_pressed("move_right"):
			key_right_held = true
			last_horizontal = 1
		elif event.is_action_released("move_right"):
			key_right_held = false
			if key_left_held:
				last_horizontal = -1

		if event.is_action_pressed("ui_up"):
			key_up_held = true
		elif event.is_action_released("ui_up"):
			key_up_held = false

		if event.is_action_pressed("ui_down"):
			key_down_held = true
		elif event.is_action_released("ui_down"):
			key_down_held = false

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	rooms = get_tree().get_first_node_in_group("rooms")
	spawn_position = global_position
	$Node2D/AnimatedSprite2D.play("idle")
	$Node2D/AnimatedSprite2D.animation_finished.connect(_on_anim_finished)
	$Node2D/NoDashSprite.animation_finished.connect(_on_anim_finished)
	floor_snap_length = 0.0
	
	#for squish
	_base_scale = sprite.scale
	
	#setup spawn
	if GameState.spawn_path != "":
		var marker = get_node(GameState.spawn_path)
		global_position = marker.global_position
	
func _process(delta):
	#for climb afterimage
	$KiwiAfterimage/Kiwi.flip_v = !facing_right
	$KiwiAfterimage/Kiwi.rotation = -PI/2
	$KiwiAfterimage/Kiwi.flip_h = velocity.y < 0
	$KiwiAfterimage.color.a = (current_stamina / 110) * 1.0
	$KiwiAfterimage/Notes.self_modulate.a = (current_stamina / 110) * 1.0
	afterimage.set_active(is_dashing)
	kiwiafterimage.set_active(is_climbing and velocity.y != 0)
	if is_climbing and velocity.y != 0 and $KiwiAfterimage.color.a > 0:
		$KiwiAfterimage/Notes.visible = true
	else:
		$KiwiAfterimage/Notes.visible = false
	
	#for squish
	var displacement = sprite.scale - _base_scale
	var spring_force = -displacement * squish_stiffness
	var damping_force = -_scale_velocity * squish_damping
	var acceleration = spring_force + damping_force
	
	_scale_velocity += acceleration * delta
	sprite.scale += _scale_velocity * delta
	if (sprite.scale.x < 1.01 and sprite.scale.x > 0.99 and 
		sprite.scale.y < 1.01 and sprite.scale.y > 0.99
	):
		sprite.scale = Vector2.ONE
	sprite.position.y = original_sprite_y - (sprite.scale.y - _base_scale.y) * 24 * 0.5

func _physics_process(delta):
	previous_position = global_position
	
		# Re-sync if a key is marked held but physically isn't
	if key_left_held and not is_physically_held("move_left"):
		key_left_held = false
		if key_right_held:
			last_horizontal = 1
	if key_right_held and not is_physically_held("move_right"):
		key_right_held = false
		if key_left_held:
			last_horizontal = -1
	if key_up_held and not is_physically_held("ui_up"):
		key_up_held = false
	if key_down_held and not is_physically_held("ui_down"):
		key_down_held = false
	if is_physically_held("move_left") and not key_left_held:
		key_left_held = true
		last_horizontal = -1
	if is_physically_held("move_right") and not key_right_held:
		key_right_held = true
		last_horizontal = 1
	if is_physically_held("ui_up") and not key_up_held:
		key_up_held = true
	if is_physically_held("ui_down") and not key_down_held:
		key_down_held = true
	# Resolve left/right from raw physical state
	if key_left_held and key_right_held:
		if last_horizontal == 1:
			Input.action_press("move_right")
			Input.action_release("move_left")
		else:
			Input.action_press("move_left")
			Input.action_release("move_right")
	elif key_left_held:
		Input.action_press("move_left")
		Input.action_release("move_right")
	elif key_right_held:
		Input.action_press("move_right")
		Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")
	if key_up_held:
		Input.action_press("ui_up")
		Input.action_release("ui_down")
	elif key_down_held:
		Input.action_press("ui_down")
		Input.action_release("ui_up")
	else:
		Input.action_release("ui_up")
		Input.action_release("ui_down")

	# Analog stick digital override
	if not Input.get_connected_joypads().is_empty():
		var axis_x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		var axis_y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
		var threshold = 0.5
		if axis_x < -threshold:
			Input.action_press("move_left")
			Input.action_release("move_right")
		elif axis_x > threshold:
			Input.action_press("move_right")
			Input.action_release("move_left")
		if axis_y < -threshold:
			Input.action_press("ui_up")
			Input.action_release("ui_down")
		elif axis_y > threshold:
			Input.action_press("ui_down")
			Input.action_release("ui_up")
	### --- GameCube Controller Override ---
	##if not Input.get_connected_joypads().is_empty():
		##var axis_x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		##var axis_y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
		##var axis_x = Input.get_axis("move_left", "move_right")
		##var axis_y = Input.get_axis("ui_up", "ui_down")
	#var threshold = 0.5
		##if abs(abs(axis_x) - threshold) <= 0:
			##axis_x = 0
		##if abs(abs(axis_y) - threshold) <= 0:
			##axis_y = 0
	#var left  = Input.is_action_pressed("move_left")
	#var right = Input.is_action_pressed("move_right")
	#var axis_x := 0
	#if Input.is_action_just_pressed("move_left"):
		#last_horizontal = -1
	#elif Input.is_action_just_pressed("move_right"):
		#last_horizontal = 1
#
	#if left and not right:
		#Input.action_press("move_left")
		#Input.action_release("move_right")
	#elif right and not left:
		#Input.action_press("move_right")
		#Input.action_release("move_left")
	#elif left and right:
		#if last_horizontal == 1:
			#Input.action_press("move_right")
			#Input.action_release("move_left")
		#elif last_horizontal == -1:
			#Input.action_press("move_left")
			#Input.action_release("move_right")
	#else:
		#Input.action_release("move_left")
		#Input.action_release("move_right")
		#if axis_x < -threshold:
			#Input.action_press("move_left")
			#Input.action_release("move_right")
		#elif axis_x > threshold:
			#Input.action_press("move_right")
			#Input.action_release("move_left")
		#else:
			#Input.action_release("move_left")
			#Input.action_release("move_right")
		
		#if axis_y < -threshold:
			#Input.action_press("ui_up")
			#Input.action_release("ui_down")
		#elif axis_y > threshold:
			#Input.action_press("ui_down")
			#Input.action_release("ui_up")
		#else:
			#Input.action_release("ui_up")
			#Input.action_release("ui_down")
			
	if ignore_just_pressed:
		ignore_just_pressed = false
	
	# rest of your existing _physics_process code...
	if !is_climbing:
		adjust_hitboxes(-68.0, 24)
		
	var old_velocity_y = velocity.y
	if top_out_timer > 0.0:
		if !(can_dash and is_just_pressed("dash")):
			var friction_effect = friction * delta
			velocity.x -= sign(velocity.x) * friction_effect
			velocity.y += gravity * delta
			top_out_timer -= delta
			move_and_slide()
			change_animation()
			return
		else:
			top_out_timer = 0
	
	if SceneTransition.transitioning == true:
		#camera.update_camera(global_position)
		velocity.y += gravity * delta
		move_and_slide()
		return
		
	#freeze frames at start of dash
	if is_frozen:
		dash_startup_timer += delta
		if dash_startup_timer > dash_startup:
			dash_startup_timer = 0
			is_frozen = false
			spawn_explosion(sprite.global_position)
		else:
			return
	# --- Cutscene/Dialogue Handling ---
	if moving_to_target:
		var distance = (move_target - global_position.x)
		var direction = sign(distance)
		if abs(distance) < 2.0:  # close enough
			global_position.x = move_target
			moving_to_target = false
			velocity = Vector2.ZERO
			# Optionally signal the NPC to start dialogue
			reached_target.emit()
			#emit_signal("reached_target")
		else:
			velocity.x = direction * move_speed * 0.6
		move_and_slide()
		change_animation()
		$Node2D/AnimatedSprite2D.flip_h = (direction >= 0)
		return  # skip normal input while walking
		
	if DialogueManager.active:
		velocity = Vector2.ZERO
		is_dashing = false
		change_animation()
		return
		
	var input_dir_vect = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	if has_floor_support() and input_dir_vect == Vector2(0, 1) and !is_dashing and !is_climbing:
		crouch()
	elif is_crouching:
		uncrouch()
	
	# --- DASH HANDLING ---
	if is_dashing:
		is_bouncing = true
		dash_timer -= delta

		if dash_initiated:
			velocity = dash_direction * dash_speed
			dash_initiated = false
		else:
			velocity.x = dash_direction.x * dash_speed
			if dash_direction.y != 0:
				velocity.y = dash_direction.y * dash_speed
	
		if has_floor_support() and dash_direction.y > 0.3:
			# Convert diagonal dash into ground dash
			dash_direction = Vector2(sign(dash_direction.x), 0)
			velocity.y = 0
			velocity.x = dash_direction.x * dash_speed


		if not has_floor_support():
			dash_left_ground = true

		# Mid-dash refund (wavedash)
		if has_floor_support() and not dash_left_ground:
			can_dash = true
		dash_left_ground = false
		
		if dash_timer <= 0:
			is_dashing = false
			is_bouncing = false
			if dash_direction.y < 0:
				velocity.y = -60
			else:
				velocity.y = 0

	# --- DASH COOLDOWN ---
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	if super_dash_timer > 0:
		super_dash_timer -= delta

	# --- HORIZONTAL INPUT ---
	input_dir = Input.get_axis("move_left", "move_right")
	var current_accel := accel if has_floor_support() else air_accel
	
	# --- WALL DETECTION ---
	wall_dir = 0
	var wjboxl := $WallJumpBoxLeft
	var wjboxr := $WallJumpBoxRight
	var wjboxls := $WallJumpBoxLeftSuper
	var wjboxrs := $WallJumpBoxRightSuper
	var regwindow :bool = (wjboxl.wall_detected or wjboxr.wall_detected)
	var superwindow :bool = ((wjboxls.wall_detected or wjboxrs.wall_detected) and is_dashing)
	if !has_floor_support() and (regwindow or superwindow):

		is_bouncing = false
		#if abs(wall_normal.x) > 0.1:
		if wjboxr.wall_detected or (wjboxrs.wall_detected and is_dashing):
			wall_dir = -1
		else:
			wall_dir = 1
			#refresh wall leniency
		last_wall_dir = wall_dir
		wall_coyote_timer = wall_coyote_time
			
		if wall_stick_timer == -1.0 and velocity.y >= 0:
			wall_stick_timer = wall_stick_duration
		if wall_stick_timer > 0:
			wall_stick_timer -= delta
	else:
		wall_coyote_timer -= delta
	#reset wall_stick_timer when not on wall
	
	if ((not is_on_wall()) or has_floor_support()):
		wall_stick_timer = -1.0
			

	# --- CLAMP HORIZONTAL AGAINST WALL ---
	if is_on_wall():
		if (wall_dir == 1 and velocity.x < 0) or (wall_dir == -1 and velocity.x > 0):
			#velocity.x = 0
			pass
	
	# --- Check if Climbing ---
	if has_floor_support():
		current_stamina = stamina
	#Check to start climb
	if (!is_climbing 
		and ((wjboxl.wall_detected and !facing_right)
		or (wjboxr.wall_detected and facing_right))
		and Input.is_action_pressed("climb")
		and velocity.y >= 0
		and !is_dashing):
		climb_dir = sign(float(facing_right) - 0.5)
		is_climbing = true
		snap_to_wall()
		
	if is_climbing and (
		Input.is_action_pressed("climb")
		and !is_just_pressed("dash")
		and ((wjboxl.wall_detected and !facing_right)
		or (wjboxr.wall_detected and facing_right))):
		climb(delta)
		#camera.update_camera(global_position)
		return
	elif is_climbing:
		is_climbing = false
		velocity.y = 0
	
	# --- HORIZONTAL ACCELERATION ---
	if wall_jump_lock_timer > 0 and not is_bouncing:
		var t = 1.0 - (wall_jump_lock_timer / wall_jump_lock_duration)
		var blend_factor = lerp(wall_jump_blend_min, wall_jump_blend_max, t)
		velocity.x = lerp(velocity.x, input_dir * move_speed, blend_factor)
		wall_jump_lock_timer -= delta
	else:
		if input_dir != 0:
			var holding_move_dir: bool = input_dir != 0.0 and sign(input_dir) == sign(velocity.x)
			if !is_bouncing or !holding_move_dir:
				velocity.x = move_toward(velocity.x, input_dir * move_speed, current_accel * delta * 1.5)
			elif is_bouncing and holding_move_dir and input_dir == -1:
				velocity.x = min(velocity.x, move_toward(velocity.x, input_dir * move_speed, current_accel * delta))
			elif is_bouncing and holding_move_dir and input_dir == 1:
				velocity.x = max(velocity.x, move_toward(velocity.x, input_dir * move_speed, current_accel * delta))
		else:
			var friction_effect = friction * delta
			if abs(velocity.x) < friction_effect:
				velocity.x = 0
			else: 
				velocity.x -= sign(velocity.x) * friction_effect

	# --- COYOTE TIME ---
	if has_floor_support():
		is_bouncing = false
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	# --- JUMP BUFFER ---
	if is_just_pressed("jump"):
		jump_buffer_timer = jump_buffer
	elif jump_buffer_timer > 0:
		jump_buffer_timer -= delta

	# --- JUMP & WALL JUMP ---
	update_recent_floor_velocity(delta)
	if velocity.y > 0:
		check_stomp()
	if jump_buffer_timer > 0:
		if has_floor_support() or coyote_timer > 0:
			if is_dashing:
				is_dashing = false
				is_bouncing = true
			velocity.y = jump_force + max_floor_vel_recently.y
			velocity.x += max_floor_vel_recently.x
			jump_buffer_timer = 0
			coyote_timer = 0
			is_jumping = true
			jump_timer = 0.0
			jump_was_released = false
			is_bouncing = true
			spawn_dust(global_position)
			squish(Vector2(0.6, 1.4))
		elif wall_dir != 0 or wall_coyote_timer > 0:
			if super_dash_timer > 0 and dash_direction == Vector2.UP:
				velocity.y = -dash_speed
			else:
				velocity.y = min(wall_jump_vertical, velocity.y)
			var jump_dir := wall_dir if wall_dir != 0 else last_wall_dir
			velocity.x = wall_jump_horizontal * jump_dir
			wall_jump_lock_timer = wall_jump_lock_duration
			jump_buffer_timer = 0
			is_dashing = false
			is_bouncing = false
			is_jumping = true
			jump_timer = 0.0
			jump_was_released = false
			wall_bounce_timer = WALL_BOUNCE_GRAVITY_TIME
			spawn_dust(global_position, jump_dir)
			squish(Vector2(0.4, 1.6))
	if is_jumping:
		#Check for first frame of jump to not cancel and end jump if on floor.
		if has_floor_support() and jump_timer != 0:
			is_jumping = false
			jump_was_released = false
			squish(Vector2(1.4, 0.6))
		else:
			jump_timer += delta
	if is_jumping and Input.is_action_just_released("jump"):
		jump_was_released = true
		
	# --- DASH INPUT ---
	if (is_just_pressed("dash") 
		and can_dash 
		and dash_cooldown_timer <= 0
		#and !DialogueManager.active
		and !DialogueManager.can_talk):
		start_dash()

	# --- GRAVITY / WALL SLIDE (DISABLED DURING DASH) ---
	var change_anim = true
	if Input.is_action_pressed("ui_down"):
		max_fall_speed = 450
	else:
		max_fall_speed = 300
	var gravity_scale := 1.0
	if wall_bounce_timer > 0:
		gravity_scale = WALL_BOUNCE_GRAVITY_MULT
		wall_bounce_timer -= delta
	if not is_dashing and not has_floor_support():
		if is_on_wall() and wall_jump_lock_timer <= 0:
			if wall_stick_timer > 0:
				velocity.y = 0
			else:
				if velocity.y > 0 and int(facing_right) != wall_dir:
					velocity.y = min(velocity.y + gravity * delta, wall_slide_speed)
					adjust_hitboxes(-65, 21)
					sprite.play("wall_slide")
					change_anim = false
				else:
					velocity.y = velocity.y + gravity * delta
		elif not has_floor_support():
			if (
				is_jumping
				and not jump_was_released
				and Input.is_action_pressed("jump")
				and abs(velocity.y) < apex_velocity_threshold
			):
				gravity_scale = apex_gravity_multiplier
			# If jump button held and within jump_hold_time, use normal gravity
			if is_jumping and Input.is_action_pressed("jump") and jump_timer < jump_hold_time:
				velocity.y += gravity * gravity_scale * delta
			# Jump released early -> increase gravity for shorter hop
			elif is_jumping and not Input.is_action_pressed("jump") and velocity.y < 0:
				velocity.y += gravity * jump_cut_gravity_multiplier * delta
			elif velocity.y <= max_fall_speed:
				velocity.y += gravity * delta
	
	# Clamp fall speed
	if velocity.y > max_fall_speed:
		velocity.y = max_fall_speed

	# --- POST-DASH LANDING REFILL (FIX) ---
	if has_floor_support() and not is_dashing:
		can_dash = true
	# --- MOVE ---
	var previous_velocity := velocity
	if touching_geyser:
		velocity.y = max(old_velocity_y - (geyser_force * delta), max_geyser_velocity_y)
		velocity.x = 0
		can_dash = true
	move_and_slide()
	apply_head_corner_correction(previous_velocity, delta)
	apply_dash_corner_correction(previous_velocity)
	apply_downward_dash_corner_correction(previous_velocity)
	
	# Check every object the player is currently touching
	check_spikes()

	if change_anim:
		change_animation()
	#camera.update_camera(global_position)
	
func check_spikes():
	for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			
			# If the thing we hit is our Spike layer, die!
			if collider is TileMapLayer and collider.name == "Hazards":
				die()
			elif collider is TileMapLayer and collider.name == "TransparentSpikes" and velocity.y >= 0:
				die()
	
func change_animation():
	#if can_dash:
		#$Node2D/AnimatedSprite2D.visible = true
		#$Node2D/NoDashSprite.visible = false
	#else:
		#$Node2D/AnimatedSprite2D.visible = false
		#$Node2D/NoDashSprite.visible = true
	if !is_dashing and sprite.animation == "dash":
		$Node2D.rotation = Vector2.ZERO.angle()
	if is_dashing:
		if sprite.animation != "dash":
			play_for_both("dash")
			#if facing_right:
				#$Node2D.rotation = dash_direction.angle()
			#else:
				#$Node2D.rotation = dash_direction.angle() - (PI)
			is_frozen = true
			velocity = Vector2.ZERO
	elif !has_floor_support():
		if velocity.y <= 200:
			play_for_both("idle")
		elif velocity.y <= 330:
			#play_for_both("jump")
			#play_for_both("slow_fall")
			pass
		elif sprite.animation != "fall_start" and sprite.animation != "falling":
			#play_for_both("fall_start")
			pass
	elif sprite.animation != "landing":
		if sprite.animation == "falling" or sprite.animation == "fall_start" or sprite.animation == "slow_fall":
			play_for_both("landing")
			spawn_dust(global_position)
		elif velocity.x != 0:
			play_for_both("walk")
		elif !is_crouching:
			play_for_both("idle")
		
	if input_dir < 0:
		facing_right = false
	elif input_dir > 0:
		facing_right = true
	sprite.flip_h = !(input_dir < 0 or (input_dir == 0 and !facing_right))

#play an animation on both player sprites
func play_for_both(anim : String):
	$Node2D/AnimatedSprite2D.play(anim)
	$Node2D/NoDashSprite.play(anim)
	
func _on_anim_finished():
	if sprite.animation == "fall_start":
		play_for_both("falling")
	if sprite.animation == "landing":
		$Node2D.position = Vector2.ZERO
		play_for_both("idle")

func start_dash():
	is_dashing = true
	dash_timer = dash_time
	dash_cooldown_timer = dash_cooldown
	super_dash_timer = super_dash_window
	afterimage.start()

	var input_dir_vect = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	if input_dir_vect == Vector2.ZERO:
		if velocity.x == 0:
			if facing_right:
				dash_direction = Vector2.RIGHT
			else:
				dash_direction = Vector2.LEFT
		else:
			dash_direction = Vector2.RIGHT * sign(velocity.x)
	else:
		dash_direction = input_dir_vect.normalized()

	can_dash = false
	dash_initiated = true
	if dash_direction.y < 0:
		dash_left_ground = true
	else:
		dash_left_ground = false
	squish(Vector2(1.0, 1.0) * abs(dash_direction) + Vector2(0.5, 0.5))
	afterimage.stop()

func stomp_bounce():
	velocity.y = stomp_bounce_force
	is_jumping = true
	can_dash = true

func die():
	if SceneTransition.transitioning:
		return
	set_physics_process(false)
	is_dashing = false
	spawn_death_animation(global_position)
	afterimage.stop()
	self.modulate.a = 0
	SceneTransition.reload_scene_with_transition()


func respawn():
	global_position = spawn_position
	velocity = Vector2.ZERO

	# Reset state
	is_dashing = false
	can_dash = true
	dash_timer = 0
	dash_cooldown_timer = 0

	coyote_timer = 0
	jump_buffer_timer = 0
	wall_jump_lock_timer = 0
	wall_stick_timer = -1.0
	is_bouncing = false

func update_recent_floor_velocity(delta):
	if floor_vel_buffer_x >= 0.1:
		max_floor_vel_recently.x = 0.0
	if floor_vel_buffer_y >= 0.1:
		max_floor_vel_recently.y = 0.0
	var x = get_platform_velocity().x
	var y = get_platform_velocity().y
	if abs(x) >= abs(max_floor_vel_recently.x):
		max_floor_vel_recently.x = get_platform_velocity().x
		floor_vel_buffer_x = 0.0
	else:
		floor_vel_buffer_x += delta
	if y <= max_floor_vel_recently.y:
		max_floor_vel_recently.y = get_platform_velocity().y
		floor_vel_buffer_y = 0.0
	else:
		floor_vel_buffer_y += delta
		
func check_stomp():
	for ray in [$FloorRay, $FloorRay2]:
		ray.force_raycast_update()
		if ray.is_colliding():
			var collider = ray.get_collider()
			if collider.is_in_group("stompable"):
				var bat = collider.get_parent()
				bat.die()
				stomp_bounce()
				break
