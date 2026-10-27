extends CharacterBody2D

#---------------------------------------------------->
# Nodes & Visual Setup
#---------------------------------------------------->
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: CollisionShape2D = $RegularHitbox

@onready var base_scale: Vector2 = anim_sprite.scale
@onready var base_pos: Vector2 = anim_sprite.position

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

#---------------------------------------------------->
# State Variables
#---------------------------------------------------->
var charging: bool = false
var charge_time: float = 0.0
var sprite_squash: Vector2 = Vector2.ONE
var was_on_floor_last_frame: bool = true
var target_visual_rotation: float = 0.0
const FEET_OFFSET: float = 14.0

#---------------------------------------------------->
# Lifecycle
#---------------------------------------------------->
func _ready() -> void:
	floor_snap_length = 16.0
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(55.0)

func _physics_process(delta: float) -> void:
	var direction: float = Input.get_axis("left", "right")
	
	_handle_jump(delta)
	
	if not charging:
		_handle_sprite_facing(direction)
	_handle_movement(direction, delta)
	
	move_and_slide()
	
	# Visual updates AFTER move_and_slide so floor normals are up to date
	_handle_ground_snap(delta)
	_handle_squash_animation(delta)
	_handle_sprite_animation(direction)

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
		anim_sprite.flip_h = (direction < 0.0)

#---------------------------------------------------->
# AnimatedSprite2D Animations
#---------------------------------------------------->
func _handle_sprite_animation(direction: float) -> void:
	if not is_instance_valid(anim_sprite):
		return
		
	var frames = anim_sprite.sprite_frames
	
	if not is_on_floor():
		if frames and frames.has_animation("jump"):
			anim_sprite.play("jump")
		else:
			anim_sprite.stop()
	elif charging:
		if frames and frames.has_animation("charge"):
			anim_sprite.play("charge")
		else:
			anim_sprite.stop()
	elif direction != 0.0 and abs(velocity.x) > 10.0:
		anim_sprite.play("walk")
	else:
		if frames and frames.has_animation("idle"):
			anim_sprite.play("idle")
		else:
			anim_sprite.stop()

#---------------------------------------------------->
# Jump Logic
#---------------------------------------------------->
func _handle_jump(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		charge_time = 0.0
		charging = false
	elif Input.is_action_pressed("up"):
		charge_time = min(charge_time + delta, max_charge_time)
		charging = true
		var charge_pct: float = charge_time / max_charge_time
		sprite_squash = Vector2(1.0 + 0.35 * charge_pct, 1.0 - 0.35 * charge_pct)
	elif Input.is_action_just_released("up") or charging:
		velocity.y = lerp(min_jump_v, max_jump_v, charge_time / max_charge_time)
		sprite_squash = Vector2(0.7, 1.35)
		charge_time = 0.0
		charging = false

#---------------------------------------------------->
# Smooth Ground Alignment (Rotates Sprite Only!)
#---------------------------------------------------->
func _handle_ground_snap(delta: float) -> void:
	if is_on_floor():
		var normal = get_floor_normal()
		# Only tilt if on a noticeable slope, otherwise stay flat (prevents seam jitter)
		if abs(normal.x) > 0.05:
			target_visual_rotation = normal.angle() + PI / 2.0
		else:
			target_visual_rotation = 0.0
	else:
		target_visual_rotation = 0.0
	
	# Rotate ONLY the sprite, keeping the physics capsule perfectly stable
	anim_sprite.rotation = lerp_angle(anim_sprite.rotation, target_visual_rotation, 12.0 * delta)

#---------------------------------------------------->
# Visual Squash & Stretch
#---------------------------------------------------->
func _handle_squash_animation(delta: float) -> void:
	if is_on_floor() and not was_on_floor_last_frame and velocity.y >= 0:
		sprite_squash = Vector2(1.3, 0.7)
	was_on_floor_last_frame = is_on_floor()
	
	if not charging:
		sprite_squash = sprite_squash.lerp(Vector2.ONE, 12.0 * delta)
	
	if charging and charge_time >= max_charge_time:
		var jitter: float = 1.8
		anim_sprite.offset = Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
	else:
		anim_sprite.offset = Vector2.ZERO
	
	anim_sprite.scale = base_scale * sprite_squash
	anim_sprite.position.y = base_pos.y + FEET_OFFSET * (1.0 - sprite_squash.y)
