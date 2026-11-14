extends Node2D
const FLAG_SHEET = preload("res://assets/flaggggfinal.png")
const FLAG_REGIONS = [Rect2(531,328,184,196), Rect2(1343,310,175,196), Rect2(2221,328,175,196), Rect2(2957,310,175,196)]
var flag_frames: Array[Texture2D] = []

const SPELL_ART = preload("res://spell_art.gd")

var arena
var viewer
var container: SubViewportContainer
var camera: Camera2D
var frame_cache: Dictionary = {}

func _ready() -> void:
	for region in FLAG_REGIONS:
		var frame := AtlasTexture.new()
		frame.atlas = FLAG_SHEET
		frame.region = region
		frame.filter_clip = true
		flag_frames.append(frame)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	camera = Camera2D.new()
	camera.position = viewer.position
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1920
	camera.limit_bottom = 1080
	add_child(camera)
	camera.make_current()

func _process(delta: float) -> void:
	if not is_instance_valid(viewer):
		return
	camera.position = camera.position.lerp(viewer.position, 1.0 - exp(-10 * delta))
	queue_redraw()

func mouse_world() -> Vector2:
	var root_mouse: Vector2 = arena.get_viewport().get_mouse_position()
	return camera.get_screen_center_position() + root_mouse - container.position - container.size / 2

func cropped_frame(texture: Texture2D) -> Texture2D:
	var key := texture.get_instance_id()
	if frame_cache.has(key):
		return frame_cache[key]
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var crop := AtlasTexture.new()
	crop.atlas = texture
	crop.region = Rect2(image.get_used_rect())
	crop.filter_clip = true
	frame_cache[key] = crop
	return crop

func _draw() -> void:
	if not is_instance_valid(arena) or not is_instance_valid(viewer):
		return
	draw_texture_rect(arena.MAP_TEXTURE, arena.WORLD_RECT, false)
	var font := ThemeDB.fallback_font
	var visible_rect := Rect2(camera.get_screen_center_position() - container.size / 2, container.size).grow(12)
	for point in arena.brush_blades:
		if visible_rect.has_point(point):
			draw_line(point - Vector2(4, 0), point - Vector2(0, 8), Color(0.18, 0.35, 0.06, 0.6), 2)
			draw_line(point - Vector2(0, 8), point + Vector2(3, -2), Color(0.38, 0.65, 0.08, 0.6), 2)
	SPELL_ART.draw_ground(self, arena)
	var flag_color := Color("#e2d29c")
	if arena.flag_owner >= 0:
		flag_color = arena.BLUE if arena.flag_owner == 0 else arena.ORANGE
	draw_circle(arena.FLAG_POSITION, arena.FLAG_RADIUS, Color(flag_color, 0.08))
	draw_arc(arena.FLAG_POSITION, arena.FLAG_RADIUS, 0, TAU, 80, Color(flag_color, 0.8), 3, true)
	if arena.builder >= 0:
		draw_arc(arena.FLAG_POSITION, 54, -PI / 2, -PI / 2 + TAU * arena.build_progress / arena.shield_build_seconds, 48, arena.BLUE if arena.builder == 0 else arena.ORANGE, 5, true)
	if arena.flag_shield > 0:
		draw_circle(arena.FLAG_POSITION, 46, Color(flag_color, 0.16))
		draw_arc(arena.FLAG_POSITION, 46, 0, TAU, 48, flag_color, 3, true)
		draw_arc(arena.FLAG_POSITION + Vector2(-5, -5), 36, PI, PI * 1.6, 16, Color.WHITE, 2, true)
	draw_circle(arena.FLAG_POSITION + Vector2(0, 26), 23, Color("#313a42"))
	var flag_frame: Texture2D = flag_frames[int(arena.elapsed * 6) % 4]
	var flag_size := flag_frame.get_size() * (64.0 / 196.0)
	draw_texture_rect(flag_frame, Rect2(arena.FLAG_POSITION + Vector2(-5, -40), flag_size), false)
	var flag_text: String = "ЩИТ %d" % ceili(arena.flag_shield) if arena.flag_shield > 0 else "СТРОЙТЕ ЩИТ"
	caption(arena.FLAG_POSITION + Vector2(0, -59), flag_text, flag_color, 12)
	for mob in arena.mobs:
		if mob.hp <= 0:
			continue
		var p: Vector2 = mob.pos
		draw_circle(p + Vector2(0, 10), 18, Color(0, 0, 0, 0.25))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-17, 8), p + Vector2(-13, -13), p + Vector2(0, -21), p + Vector2(14, -12), p + Vector2(19, 8)]), Color("#786c5b"))
		draw_circle(p + Vector2(-6, -5), 3, Color("#ffd887"))
		draw_circle(p + Vector2(6, -5), 3, Color("#ffd887"))
		draw_rect(Rect2(p + Vector2(-18, -29), Vector2(36, 4)), Color("#292a29"))
		draw_rect(Rect2(p + Vector2(-18, -29), Vector2(36 * mob.hp / 55, 4)), Color("#d8ca94"))
	var ordered: Array = arena.players.duplicate()
	ordered.sort_custom(func(a, b): return a.position.y < b.position.y)
	for player in ordered:
		if not arena.is_visible_to(player, viewer.team):
			continue
		var sprite: AnimatedSprite2D = player.body_sprite
		var texture := cropped_frame(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame))
		var size := texture.get_size() * sprite.scale
		var dest := Rect2(player.position + Vector2(-size.x / 2, 20 - size.y), size)
		if sprite.flip_h:
			dest.position.x += size.x
			dest.size.x = -size.x
		var tint := sprite.modulate
		var hidden: bool = arena.brush_at(player.position) >= 0
		if hidden and player.team == viewer.team:
			tint.a *= 0.6
		var team_color: Color = arena.BLUE if player.team == 0 else arena.ORANGE
		draw_circle(player.position + Vector2(0, 15), 17, Color(team_color, 0.25))
		draw_texture_rect(texture, dest, false, tint)
		if player.is_dead:
			continue
		draw_rect(Rect2(player.position + Vector2(-20, -30), Vector2(40, 4)), Color("#202b36"))
		draw_rect(Rect2(player.position + Vector2(-20, -30), Vector2(40 * player.hp / player.max_hp, 4)), team_color)
		draw_circle(player.position + Vector2(25, -28), 3, arena.ELEMENT_COLORS[player.element])
		if player == viewer:
			var aim: Vector2 = player.aim_direction.normalized()
			draw_line(player.position + aim * 24, player.position + aim * 42, Color.WHITE, 1, true)
			if hidden:
				var spotted: bool = arena.is_revealed(player, 1 - player.team)
				caption(player.position + Vector2(0, -39), "РАСКРЫТ" if spotted else "В КУСТАХ", Color("#ffb19c") if spotted else Color("#caeaa5"), 10)
		if arena.squad and arena.fusion[player.team].ready:
			draw_arc(player.position, 28, arena.elapsed * 2, arena.elapsed * 2 + 4.5, 24, Color("#ffe7a2"), 2, true)
	for shot in arena.projectiles:
		var pos: Vector2 = shot.pos
		var dir: Vector2 = shot.vel.normalized()
		var side := dir.orthogonal()
		var color: Color = arena.ELEMENT_COLORS[shot.element]
		if shot.ultimate:
			color = arena.ELEMENT_COLORS[shot.pair[0]].lerp(arena.ELEMENT_COLORS[shot.pair[1]], 0.5)
			draw_circle(pos, 18, Color(color, 0.3))
			draw_circle(pos, 10, color)
			draw_arc(pos, 19, arena.elapsed * 7, arena.elapsed * 7 + 5, 24, Color.WHITE, 2, true)
		elif shot.element == 0:
			draw_colored_polygon(PackedVector2Array([pos + dir * 9, pos + side * 5 - dir * 3, pos - dir * 17, pos - side * 5 - dir * 3]), color)
		elif shot.element == 1:
			draw_line(pos - dir * 14, pos, Color(color, 0.4), 7, true)
			draw_circle(pos, 5, color)
		elif shot.element == 2:
			draw_colored_polygon(PackedVector2Array([pos + dir * 11, pos + side * 4, pos - dir * 11, pos - side * 4]), color)
		elif shot.element == 3:
			draw_polyline(PackedVector2Array([pos - dir * 15, pos - dir * 5 + side * 5, pos - side * 4, pos + dir * 8]), color, 3, true)
		else:
			draw_arc(pos, 9, dir.angle() - 1.4, dir.angle() + 1.4, 16, color, 3, true)
			draw_arc(pos - dir * 9, 7, dir.angle() - 1.4, dir.angle() + 1.4, 16, Color(color, 0.5), 2, true)
	SPELL_ART.draw_foreground(self, arena)
	for fx in arena.effects:
		var progress: float = 1.0 - fx.life / 0.85
		var color: Color = fx.color
		color.a = 1 - progress
		draw_arc(fx.pos, maxf(2, fx.radius * progress), 0, TAU, 36, color, 2, true)
		if not fx.text.is_empty():
			caption(fx.pos + Vector2(0, -40 - progress * 22), fx.text, color, 12)

func caption(pos: Vector2, text: String, color: Color, font_size: int) -> void:
	var font := ThemeDB.fallback_font
	pos.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.03, 0.04, 0.06, color.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
