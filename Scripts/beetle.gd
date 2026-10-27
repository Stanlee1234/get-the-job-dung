extends CharacterBody2D

#---------------------------------------------------->
# Nodes & Visual Setup
#---------------------------------------------------->
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: CollisionShape2D = $CollisionShape2D

@onready var base_scale: Vector2 = $AnimatedSprite2D.scale
@onready var base_pos: Vector2 = $AnimatedSprite2D.position

#---------------------------------------------------->
# Export Settings
#---------------------------------------------------->
@export_group("Movement")
@export var speed: float = 160.0
@export var accel: float = 1200.0
@export var friction: float = 1400.0
@export var gravity: float = 980.0

@export_group("Jump")
@export var min_jump_v: float = -180.0
@export var max_jump_v: float = -400.0
@export var max_charge_time: float = 0.9

@export_group("Slopes & Steps")
@export var max_step_height: float = 6.0 # Auto-step up ledges up to this height in pixels

#---------------------------------------------------->
# State Variables
#---------------------------------------------------->
var charging: bool = false
var charge_time: float = 0.0
var walk_cycle: float = 0.0
var sprite_squash: Vector2 = Vector2.ONE
var was_on_floor_last_frame: bool = true
const FEET_OFFSET: float = 14.0

#---------------------------------------------------->
# Lifecycle
#---------------------------------------------------->
func _ready() -> void:
	floor_snap_length = 16.0
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(55.0) # Treats steeper slopes as walkable floors

func _physics_process(delta: float) -> void:
	var direction: float = Input.get_axis("left", "right")
	
	_handle_ground_snap(delta)
	_handle_jump(delta)
	
	if not charging:
		_handle_sprite_facing(direction)
	_handle_movement(direction, delta)
	_handle_squash_animation(delta)
	_handle_walk_waddle(delta)
	
	# Step-up logic for small ledges
	if is_on_floor() and direction != 0.0:
		_handle_step_up()
		
	move_and_slide()

#---------------------------------------------------->
# Movement & Facing
#---------------------------------------------------->
func _handle_movement(direction: float, delta: float) -> void:
	if charging:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	elif direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

func _handle_sprite_facing(direction: float) -> void:
	if direction != 0.0:
		sprite.flip_h = (direction < 0.0)

#---------------------------------------------------->
# Jump Logic
#---------------------------------------------------->
func _handle_jump(delta: float) -> void:
	# In air: apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		charge_time = 0.0
		charging = false
	# Charging jump on ground
	elif Input.is_action_pressed("up"):
		charge_time = min(charge_time + delta, max_charge_time)
		charging = true
		
		# Squash down while charging
		var charge_pct: float = charge_time / max_charge_time
		sprite_squash = Vector2(1.0 + 0.35 * charge_pct, 1.0 - 0.35 * charge_pct)
	# Jump Release
	elif Input.is_action_just_released("up") or charging:
		velocity.y = lerp(min_jump_v, max_jump_v, charge_time / max_charge_time)
		sprite_squash = Vector2(0.7, 1.35)
		
		charge_time = 0.0
		charging = false

#---------------------------------------------------->
# Ground Alignment
#---------------------------------------------------->
func _handle_ground_snap(delta: float) -> void:
	if is_on_floor():
		var target_angle: float = get_floor_normal().angle() + PI / 2.0
		rotation = lerp_angle(rotation, target_angle, 15.0 * delta)
	else:
		rotation = lerp_angle(rotation, 0.0, 10.0 * delta)

#---------------------------------------------------->
# Visual Animations
#---------------------------------------------------->
func _handle_squash_animation(delta: float) -> void:
	if is_on_floor() and not was_on_floor_last_frame and velocity.y >= 0:
		sprite_squash = Vector2(1.3, 0.7)
	was_on_floor_last_frame = is_on_floor()
	
	if not charging:
		sprite_squash = sprite_squash.lerp(Vector2.ONE, 12.0 * delta)
	
	if charging and charge_time >= max_charge_time:
		var jitter: float = 1.8
		sprite.offset = Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
	else:
		sprite.offset = Vector2.ZERO
	
	sprite.scale = base_scale * sprite_squash
	sprite.position.y = base_pos.y + FEET_OFFSET * (1.0 - sprite_squash.y)

func _handle_walk_waddle(delta: float) -> void:
	var is_walking: bool = is_on_floor() and abs(velocity.x) > 15.0 and not charging
	if is_walking:
		var speed_factor: float = clamp(abs(velocity.x) / speed, 0.6, 1.4)
		walk_cycle += delta * 18.0 * speed_factor
		var target_tilt: float = sin(walk_cycle) * deg_to_rad(9.0)
		sprite.rotation = lerp_angle(sprite.rotation, target_tilt, 18.0 * delta)
	else:
		walk_cycle = 0.0
		sprite.rotation = lerp_angle(sprite.rotation, 0.0, 14.0 * delta)

#---------------------------------------------------->
# Small Ledge / Step-Up Helper
#---------------------------------------------------->
func _handle_step_up() -> void:
	var step_vector = Vector2(sign(velocity.x) * 2.0, 0)
	if test_move(global_transform, step_vector):
		for h in range(1, int(max_step_height) + 1):
			var up_transform = global_transform.translated(Vector2(0, -h))
			if not test_move(up_transform, step_vector):
				global_position.y -= h
				break
