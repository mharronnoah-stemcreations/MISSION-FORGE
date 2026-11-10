class_name UITheme
extends RefCounted

# UITheme
# Centralized styling helper creating consistent NASA Mission Control aesthetics.

const COLOR_BG_DARK = Color(0.04, 0.07, 0.11, 0.95)
const COLOR_PANEL_BG = Color(0.07, 0.11, 0.18, 0.92)
const COLOR_ACCENT_CYAN = Color(0.0, 0.9, 1.0, 1.0)
const COLOR_ACCENT_GOLD = Color(1.0, 0.75, 0.1, 1.0)
const COLOR_TEXT_WHITE = Color(0.95, 0.96, 0.98, 1.0)
const COLOR_TEXT_MUTED = Color(0.65, 0.72, 0.82, 1.0)
const COLOR_BORDER = Color(0.18, 0.32, 0.48, 0.8)
const COLOR_SUCCESS = Color(0.2, 0.9, 0.4, 1.0)
const COLOR_WARNING = Color(1.0, 0.65, 0.0, 1.0)
const COLOR_DANGER = Color(1.0, 0.25, 0.25, 1.0)

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

static func style_button(btn: Button, is_primary: bool = false) -> void:
	if btn == null: return
	
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal = StyleBoxFlat.new()
	var hover = StyleBoxFlat.new()
	var pressed = StyleBoxFlat.new()

	if is_primary:
		normal.bg_color = Color(0.0, 0.45, 0.65, 0.9)
		normal.border_color = COLOR_ACCENT_CYAN
		hover.bg_color = Color(0.0, 0.60, 0.85, 1.0)
		hover.border_color = Color(1, 1, 1, 1)
		pressed.bg_color = Color(0.0, 0.35, 0.50, 1.0)
		pressed.border_color = COLOR_ACCENT_CYAN
	else:
		normal.bg_color = Color(0.08, 0.14, 0.22, 0.85)
		normal.border_color = COLOR_BORDER
		hover.bg_color = Color(0.12, 0.22, 0.34, 0.95)
		hover.border_color = COLOR_ACCENT_CYAN
		pressed.bg_color = Color(0.06, 0.10, 0.16, 1.0)
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

	btn.mouse_entered.connect(func():
		if AudioManager != null: AudioManager.play_hover()
	)
	btn.pressed.connect(func():
		if AudioManager != null: AudioManager.play_click()
	)
