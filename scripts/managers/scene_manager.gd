extends Node

# SceneManager Autoload Singleton
# Manages scene transitions with visual fading and navigation history.

signal scene_transition_started(target_scene: String)
signal scene_transition_finished(target_scene: String)

var _fader_layer: CanvasLayer = null
var _color_rect: ColorRect = null
var _is_transitioning: bool = false

const SCENES = {
	"main_menu": "res://scenes/main/main_menu.tscn",
	"mission_selection": "res://scenes/missions/mission_selection.tscn",
	"briefing": "res://scenes/missions/briefing.tscn",
	"designer": "res://scenes/spacecraft/spacecraft_designer.tscn",
	"simulation": "res://scenes/simulation/simulation_scene.tscn",
	"report": "res://scenes/ui/mission_report.tscn"
}

func _ready() -> void:
	_setup_transition_overlay()

func _setup_transition_overlay() -> void:
	_fader_layer = CanvasLayer.new()
	_fader_layer.layer = 128
	add_child(_fader_layer)
	
	_color_rect = ColorRect.new()
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.color = Color(0.02, 0.04, 0.08, 0.0) # Deep space navy black
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fader_layer.add_child(_color_rect)

func switch_to_scene(scene_key: String, fade_duration: float = 0.25) -> void:
	if _is_transitioning:
		return
	
	var path: String = SCENES.get(scene_key, scene_key)
	if not ResourceLoader.exists(path):
		push_error("[SceneManager] Scene path does not exist: " + path)
		return

	_is_transitioning = true
	emit_signal("scene_transition_started", path)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fade out
	var tween = create_tween()
	tween.tween_property(_color_rect, "color:a", 1.0, fade_duration)
	await tween.finished

	# Change scene
	var err = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("[SceneManager] Failed to change scene to: " + path)

	# Fade in
	var tween_in = create_tween()
	tween_in.tween_property(_color_rect, "color:a", 0.0, fade_duration)
	await tween_in.finished

	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	emit_signal("scene_transition_finished", path)
