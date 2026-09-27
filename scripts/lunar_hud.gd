extends Control

## Lightweight procedural HUD artwork.
## mode="reticle" draws the camera interaction marker; mode="lunar" presents
## the deterministic lunar state without textures or particle effects.

@export_enum("reticle", "lunar") var mode := "lunar"
var phase_name := "DARK"
var phase_index := 0
var illumination := 0.0
var _refresh_timer := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	_refresh_state()

func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer < 0.25:
		return
	_refresh_timer = 0.0
	if mode == "lunar":
		_refresh_state()
	queue_redraw()

func _refresh_state() -> void:
	var lunar := get_tree().get_first_node_in_group("lunar_cycle")
	if not lunar:
		lunar = get_tree().current_scene.get_node_or_null("LunarCycle") if get_tree().current_scene else null
	if lunar and lunar.has_method("get_lunar_state"):
		var state: Dictionary = lunar.get_lunar_state()
		phase_name = str(state.get("phase_name", "DARK")).to_upper()
		phase_index = int(state.get("phase_index", 0))
		var phase := float(state.get("phase", 0.0))
		illumination = 0.5 + 0.5 * cos((phase - 0.5) * TAU)

func _draw() -> void:
	if mode == "reticle":
		_draw_reticle()
	else:
		_draw_lunar()

func _draw_reticle() -> void:
	var center := size * 0.5
	var active := Color(0.48, 0.90, 0.92, 0.92)
	var shadow := Color(0.01, 0.02, 0.025, 0.72)
	var gap := 4.0
	var arm := 8.0
	draw_line(center + Vector2(-gap - arm, 0), center + Vector2(-gap, 0), shadow, 3.0, true)
	draw_line(center + Vector2(gap, 0), center + Vector2(gap + arm, 0), shadow, 3.0, true)
	draw_line(center + Vector2(0, -gap - arm), center + Vector2(0, -gap), shadow, 3.0, true)
	draw_line(center + Vector2(0, gap), center + Vector2(0, gap + arm), shadow, 3.0, true)
	draw_line(center + Vector2(-gap - arm, 0), center + Vector2(-gap, 0), active, 1.5, true)
	draw_line(center + Vector2(gap, 0), center + Vector2(gap + arm, 0), active, 1.5, true)
	draw_line(center + Vector2(0, -gap - arm), center + Vector2(0, -gap), active, 1.5, true)
	draw_line(center + Vector2(0, gap), center + Vector2(0, gap + arm), active, 1.5, true)
	draw_circle(center, 1.6, active, true)

func _draw_lunar() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.025, 0.035, 0.90)
	panel_style.border_color = Color(0.24, 0.66, 0.70, 0.62)
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 5
	draw_style_box(panel_style, panel)

	var moon_center := Vector2(28.0, size.y * 0.5)
	var radius := minf(16.0, size.y * 0.31)
	var dark := Color(0.045, 0.065, 0.085, 1)
	var glow := Color(0.78, 0.88, 0.92, 1)
	draw_circle(moon_center, radius + 2.0, Color(0.20, 0.55, 0.60, 0.22), true)
	draw_circle(moon_center, radius, glow, true)
	# A shifted dark disc gives a cheap, texture-free phase silhouette.
	var phase := float(phase_index) / 8.0
	var shift := cos(phase * TAU) * radius * 0.95
	draw_circle(moon_center + Vector2(shift, 0), radius + 0.25, dark, true)
	if phase_index == 4:
		draw_circle(moon_center, radius, glow, true)

	var font := get_theme_default_font()
	if font:
		var title := "LUNAR  //  " + phase_name
		font.draw_string(get_canvas_item(), Vector2(54.0, 23.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.48, 0.88, 0.90, 1.0))
		var pct := "%d%% ILLUMINATION" % int(round(illumination * 100.0))
		font.draw_string(self, Vector2(54.0, 41.0), pct, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.72, 0.80, 0.83, 0.90))
