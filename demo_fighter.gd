extends "res://image_removebg_preview.gd"

const DEATH_SHEET: Texture2D = preload("res://assets/deathanimation.png")
const BOUNCE_SHEET: Texture2D = preload("res://assets/bouncebacklinefinal.png")
var bounce_time: float = 0.0
var team: int = 0
var element: int = 0
var bot: bool = false
var human_index: int = -1
var aim_direction := Vector2.RIGHT
var push_velocity := Vector2.ZERO
var slow_time: float = 0.0
var element_time: float = 0.0
var applied_element: int = -1
var invincible_time: float = 0.0
var flash_time: float = 0.0
var base_move_speed: float = 160.0

func configure_animations() -> void:
	super.configure_animations()
	body_includes_head = true
	var frames := body_sprite.sprite_frames
	# Reuse the standing pose until separate idle/hurt art is supplied.
	for anim in ["idle", "hurt"]:
		frames.clear(anim)
		frames.add_frame(anim, frames.get_frame_texture("attack", 0))
		frames.set_animation_speed(anim, 4.0)
	frames.set_animation_loop("idle", true)
	frames.set_animation_loop("hurt", false)
	frames.set_animation_speed("attack", 7.0)
	frames.set_animation_speed("walk", 6.0)
	frames.clear("death")
	frames.set_animation_speed("death", 2.4)
	frames.set_animation_loop("death", false)
	for region in [Rect2(442, 373, 198, 198), Rect2(1233, 320, 198, 214), Rect2(2110, 372, 230, 166)]:
		var atlas := AtlasTexture.new()
		atlas.atlas = DEATH_SHEET
		atlas.region = region
		atlas.filter_clip = true
		var padding: Vector2 = Vector2(230, 214) - region.size
		atlas.margin = Rect2(Vector2(padding.x / 2, padding.y), padding)
		frames.add_frame("death", atlas)
	animation_size_multipliers["death"] = 214.0 / 198.0
	if not frames.has_animation("bounce"): frames.add_animation("bounce")
	frames.clear("bounce")
	frames.set_animation_speed("bounce", 14)
	frames.set_animation_loop("bounce", false)
	for region in [Rect2(426,379,141,141), Rect2(1309,373,141,141), Rect2(2223,368,140,140), Rect2(3160,377,140,138), Rect2(3967,379,140,141), Rect2(4858,391,140,141), Rect2(5793,391,138,141)]:
		var atlas := AtlasTexture.new()
		atlas.atlas = BOUNCE_SHEET
		atlas.region = region
		atlas.filter_clip = true
		var padding: Vector2 = Vector2(141,141) - region.size
		atlas.margin = Rect2(Vector2(padding.x / 2, padding.y), padding)
		frames.add_frame("bounce", atlas)
	speed = base_move_speed
	respawn_time = 3.5
	hp_regen_delay = 4.0
	hp_regen_per_second = 4.0
	energy_regen_per_second = 14.0
	energy_regen_delay = 0.8

func _physics_process(delta: float) -> void:
	bounce_time = maxf(0, bounce_time - delta)
	slow_time = maxf(0, slow_time - delta)
	element_time = maxf(0, element_time - delta)
	invincible_time = maxf(0, invincible_time - delta)
	flash_time = maxf(0, flash_time - delta)
	if element_time <= 0:
		applied_element = -1
	speed = base_move_speed * (0.55 if slow_time > 0 else 1.0)
	super._physics_process(delta)
	if not is_dead:
		position += push_velocity * delta
	push_velocity = push_velocity.move_toward(Vector2.ZERO, 750.0 * delta)
	body_sprite.modulate = Color(1.8, 1.0, 1.0) if flash_time > 0 else Color.WHITE
	if invincible_time > 0:
		body_sprite.modulate.a = 0.55 + 0.35 * absf(sin(invincible_time * 14))

func start_attack() -> void:
	if bounce_time > 0: return
	if not is_dead and not is_attacking and aim_direction.length_squared() > 0.01:
		facing_direction = aim_direction.normalized()
		body_sprite.flip_h = facing_direction.x < 0
	super.start_attack()

func take_damage(amount: int) -> void:
	if is_dead or invincible_time > 0:
		return
	flash_time = 0.14
	if bounce_time > 0:
		hp = maxf(0, hp - maxi(0, amount))
		hp_regen_wait = hp_regen_delay
		update_hud()
		if hp <= 0: die()
		return
	super.take_damage(amount)

func respawn() -> void:
	bounce_time = 0
	super.respawn()
	push_velocity = Vector2.ZERO
	slow_time = 0
	applied_element = -1
	element_time = 0
	invincible_time = 1.2

func play_anim(anim_name: StringName) -> void:
	super.play_anim(anim_name)
	# Keep feet on one baseline even when the death frame becomes wider.
	if anim_name == &"death":
		body_sprite.position.y = 36.0 - 107.0 * body_sprite.scale.y
	else:
		body_sprite.position.y = 0

func trigger_bounce(impulse: Vector2) -> void:
	if is_dead: return
	push_velocity = impulse
	bounce_time = 0.5
	is_attacking = false
	is_hurt = true
	velocity = Vector2.ZERO
	play_anim("bounce")

func _on_animation_finished() -> void:
	if not simulation_authority or is_dead: return
	if body_sprite.animation == &"bounce":
		bounce_time = 0
		is_hurt = false
		play_anim("idle")
	else:
		super._on_animation_finished()
