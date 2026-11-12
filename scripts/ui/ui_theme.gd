class_name UITheme
extends RefCounted

# UITheme
# Centralized styling helper creating consistent NASA Mission Control aesthetics.

const COLOR_BG_DARK = Color(0.03, 0.05, 0.09, 0.96)
const COLOR_PANEL_BG = Color(0.06, 0.10, 0.17, 0.94)
const COLOR_CARD_BG = Color(0.08, 0.13, 0.22, 0.92)
const COLOR_ACCENT_CYAN = Color(0.0, 0.90, 1.0, 1.0)
const COLOR_ACCENT_GOLD = Color(1.0, 0.75, 0.1, 1.0)
const COLOR_TEXT_WHITE = Color(0.95, 0.96, 0.98, 1.0)
const COLOR_TEXT_MUTED = Color(0.65, 0.72, 0.82, 1.0)
const COLOR_BORDER = Color(0.18, 0.32, 0.48, 0.8)
const COLOR_BORDER_ACTIVE = Color(0.0, 0.85, 1.0, 0.9)
const COLOR_SUCCESS = Color(0.15, 0.90, 0.45, 1.0)
const COLOR_WARNING = Color(1.0, 0.65, 0.05, 1.0)
const COLOR_DANGER = Color(1.0, 0.25, 0.30, 1.0)

# Subsystem Category Colors
const COLOR_CAT_STRUCTURE = Color(0.55, 0.62, 0.75, 1.0)
const COLOR_CAT_POWER = Color(1.0, 0.82, 0.20, 1.0)
const COLOR_CAT_INSTRUMENTS = Color(0.68, 0.55, 0.98, 1.0)
const COLOR_CAT_COMMS = Color(0.22, 0.75, 0.98, 1.0)
const COLOR_CAT_PROPULSION = Color(0.98, 0.30, 0.40, 1.0)
const COLOR_CAT_LANDING = Color(0.98, 0.55, 0.20, 1.0)
const COLOR_CAT_DATA = Color(0.15, 0.85, 0.60, 1.0)

static var reduced_motion: bool = false
static var high_contrast: bool = false

static func get_category_color(cat: String) -> Color:
	match cat:
		"Structure": return COLOR_CAT_STRUCTURE
		"Power": return COLOR_CAT_POWER
		"Instruments": return COLOR_CAT_INSTRUMENTS
		"Communications": return COLOR_CAT_COMMS
		"Propulsion": return COLOR_CAT_PROPULSION
		"Landing": return COLOR_CAT_LANDING
		"Data": return COLOR_CAT_DATA
		_: return COLOR_ACCENT_CYAN

static func create_panel_style(bg_color: Color = COLOR_PANEL_BG, border_color: Color = COLOR_BORDER, corner_radius: int = 6) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(corner_radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func create_badge_style(bg_color: Color, border_color: Color = Color(0,0,0,0)) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(1 if border_color.a > 0 else 0)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb

static func style_progress_bar(bar: ProgressBar, fill_color: Color, bg_color: Color = Color(0.08, 0.12, 0.18, 0.9)) -> void:
	if bar == null: return
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = bg_color
	bg_sb.set_corner_radius_all(3)
	bg_sb.border_color = COLOR_BORDER
	bg_sb.set_border_width_all(1)

	var fill_sb = StyleBoxFlat.new()
	fill_sb.bg_color = fill_color
	fill_sb.set_corner_radius_all(3)

	bar.add_theme_stylebox_override("background", bg_sb)
	bar.add_theme_stylebox_override("fill", fill_sb)

static func style_button(btn: Button, is_primary: bool = false) -> void:
	if btn == null: return
	
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal = StyleBoxFlat.new()
	var hover = StyleBoxFlat.new()
	var pressed = StyleBoxFlat.new()

	if is_primary:
		normal.bg_color = Color(0.0, 0.42, 0.62, 0.95)
		normal.border_color = COLOR_ACCENT_CYAN
		hover.bg_color = Color(0.0, 0.58, 0.85, 1.0)
		hover.border_color = Color(1, 1, 1, 1)
		pressed.bg_color = Color(0.0, 0.32, 0.48, 1.0)
		pressed.border_color = COLOR_ACCENT_CYAN
	else:
		normal.bg_color = Color(0.07, 0.12, 0.20, 0.88)
		normal.border_color = COLOR_BORDER
		hover.bg_color = Color(0.11, 0.20, 0.32, 0.95)
		hover.border_color = COLOR_ACCENT_CYAN
		pressed.bg_color = Color(0.05, 0.09, 0.15, 1.0)
		pressed.border_color = COLOR_ACCENT_CYAN

	for sb in [normal, hover, pressed]:
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	btn.add_theme_color_override("font_hover_color", COLOR_ACCENT_CYAN)

	# Sound hookups
	btn.mouse_entered.connect(func():
		var am = Engine.get_main_loop().root.get_node_or_null("AudioManager") if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root else null
		if am != null: am.play_hover()
	)
	btn.pressed.connect(func():
		var am = Engine.get_main_loop().root.get_node_or_null("AudioManager") if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root else null
		if am != null: am.play_click()
	)
