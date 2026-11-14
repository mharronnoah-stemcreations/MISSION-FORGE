extends Control

# SimulationScene
# Real-time 3D mission simulation and Mission Control telemetry interface.
# Coordinates deterministic simulation engine ticks, 3D trajectory visualization,
# live telemetry streaming, in-flight interactive decisions, and mission event feed.
# Features:
# - Visual telemetry gauges: Energy flow (DoD), Comms DSN margin, SSD buffer fill, Propellant reserve
# - 4 Camera Modes: Orbit Vista, Spacecraft Focus, Surface Operations, Free Orbit/Pan/Zoom Cam
# - Skippable cinematic approach intro sequence
# - Dynamic thruster plume particle burn visualization

enum CameraMode { VISTA, FOCUS, SURFACE, FREE }

@onready var sim_engine: SimulationEngine = $SimulationEngine
@onready var planet_node: PlanetVisualizer = $ViewportContainer/SubViewport/PlanetNode
@onready var craft_node: Node3D = $ViewportContainer/SubViewport/CraftPivot/SpacecraftVisual
@onready var craft_pivot: Node3D = $ViewportContainer/SubViewport/CraftPivot
@onready var cam_3d: Camera3D = $ViewportContainer/SubViewport/Camera3D

# Telemetry HUD
@onready var lbl_phase: Label = $UI/PanelTop/HBox/LblPhase
@onready var bar_phase_progress: ProgressBar = $UI/PanelTop/HBox/BarProgress
@onready var lbl_mission_name: Label = $UI/PanelTop/HBox/LblMissionName

@onready var val_time: Label = $UI/PanelTelemetry/VBox/Grid/ValTime
@onready var val_alt: Label = $UI/PanelTelemetry/VBox/Grid/ValAlt
@onready var val_vel: Label = $UI/PanelTelemetry/VBox/Grid/ValVel

# Telemetry Subsystem Gauges
@onready var bar_bat: ProgressBar = $UI/PanelTelemetry/VBox/BarBat
@onready var val_bat_flow: Label = $UI/PanelTelemetry/VBox/ValBatFlow
@onready var bar_sig: ProgressBar = $UI/PanelTelemetry/VBox/BarSig
@onready var val_sig_flow: Label = $UI/PanelTelemetry/VBox/ValSigFlow
@onready var bar_buf: ProgressBar = $UI/PanelTelemetry/VBox/BarBuf
@onready var val_buf_flow: Label = $UI/PanelTelemetry/VBox/ValBufFlow
@onready var bar_prop: ProgressBar = $UI/PanelTelemetry/VBox/BarProp
@onready var val_prop_flow: Label = $UI/PanelTelemetry/VBox/ValPropFlow

# Event Log
@onready var list_events: VBoxContainer = $UI/PanelEvents/VBox/Scroll/ListEvents
@onready var scroll_events: ScrollContainer = $UI/PanelEvents/VBox/Scroll

# Sim controls
@onready var btn_pause: Button = $UI/PanelControls/HBox/BtnPause
@onready var btn_1x: Button = $UI/PanelControls/HBox/Btn1x
@onready var btn_2x: Button = $UI/PanelControls/HBox/Btn2x
@onready var btn_4x: Button = $UI/PanelControls/HBox/Btn4x
@onready var btn_skip: Button = $UI/PanelControls/HBox/BtnSkip

# Camera Switcher Controls
@onready var btn_cam_vista: Button = $UI/PanelControls/HBox/BtnCamVista
@onready var btn_cam_focus: Button = $UI/PanelControls/HBox/BtnCamFocus
@onready var btn_cam_surface: Button = $UI/PanelControls/HBox/BtnCamSurface
@onready var btn_cam_free: Button = $UI/PanelControls/HBox/BtnCamFree
@onready var btn_cam_sample: Button = $UI/PanelControls/HBox/BtnCamSample

# Cinematic Approach Banner
@onready var panel_intro: PanelContainer = $UI/PanelIntro
@onready var btn_skip_intro: Button = $UI/PanelIntro/HBoxIntro/BtnSkipIntro
@onready var lbl_intro_title: Label = $UI/PanelIntro/HBoxIntro/VBoxIntroText/LblIntroTitle
@onready var lbl_intro_sub: Label = $UI/PanelIntro/HBoxIntro/VBoxIntroText/LblIntroSub

# Interactive Decision Modal
@onready var modal_decision: PanelContainer = $UI/ModalDecision
@onready var lbl_dec_header: Label = $UI/ModalDecision/VBox/LblDecHeader
@onready var lbl_dec_context: Label = $UI/ModalDecision/VBox/LblDecContext
@onready var vbox_options: VBoxContainer = $UI/ModalDecision/VBox/VBoxOptions

# Surface Sampling Cutscene UI
@onready var cutscene_sampling: Control = $UI/CutsceneSampling
@onready var lbl_rec: Label = $UI/CutsceneSampling/BarTop/HBoxTop/LblRec
@onready var lbl_cutscene_title: Label = $UI/CutsceneSampling/BarTop/HBoxTop/VBoxInfo/LblCutsceneTitle
@onready var lbl_cutscene_target: Label = $UI/CutsceneSampling/BarTop/HBoxTop/VBoxInfo/LblCutsceneTarget
@onready var lbl_cutscene_time: Label = $UI/CutsceneSampling/BarTop/HBoxTop/LblCutsceneTime
@onready var badge_1: Label = $UI/CutsceneSampling/BarBottom/HBoxBottom/VBoxSteps/HBoxBadges/Badge1
@onready var badge_2: Label = $UI/CutsceneSampling/BarBottom/HBoxBottom/VBoxSteps/HBoxBadges/Badge2
@onready var badge_3: Label = $UI/CutsceneSampling/BarBottom/HBoxBottom/VBoxSteps/HBoxBadges/Badge3
@onready var bar_coring: ProgressBar = $UI/CutsceneSampling/BarBottom/HBoxBottom/VBoxSteps/BarCoring
@onready var lbl_coring_status: Label = $UI/CutsceneSampling/BarBottom/HBoxBottom/VBoxSteps/LblCoringStatus
@onready var btn_skip_cutscene: Button = $UI/CutsceneSampling/BarBottom/HBoxBottom/BtnSkipCutscene
@onready var reticle_target: Label = $UI/CutsceneSampling/CenterHUD/ReticleTarget

var _is_paused: bool = false
var _craft_preview_builder: SpacecraftPreview
var _thruster_plume_mesh: MeshInstance3D

var _current_cam_mode: CameraMode = CameraMode.VISTA
var _free_cam_distance: float = 3.8
var _free_cam_rot_y: float = 0.0
var _free_cam_rot_x: float = -0.15
var _free_cam_target: Vector3 = Vector3.ZERO
var _is_dragging_free_orbit: bool = false
var _is_dragging_free_pan: bool = false
var _free_drag_prev_pos: Vector2 = Vector2.ZERO

var _is_intro_playing: bool = true
var _intro_elapsed: float = 0.0
const INTRO_DURATION: float = 2.8

# Surface Sampling Cutscene State
var _is_sampling_cutscene: bool = false
var _sampling_elapsed: float = 0.0
const SAMPLING_DURATION: float = 9.5
var _has_played_sample_cutscene: bool = false
var _sampling_rig: Node3D
var _laser_beam_mesh: MeshInstance3D
var _laser_impact_mesh: MeshInstance3D
var _borehole_mesh: MeshInstance3D
var _audio_laser_cooldown: float = 0.0
var _audio_drill_cooldown: float = 0.0
var _prev_cam_mode_before_cutscene: CameraMode = CameraMode.VISTA

func _gm() -> Node:
	return get_node_or_null("/root/GameManager")

func _mm() -> Node:
	return get_node_or_null("/root/MissionManager")

func _sm() -> Node:
	return get_node_or_null("/root/SceneManager")

func _am() -> Node:
	return get_node_or_null("/root/AudioManager")

func _ready() -> void:
	UITheme.style_button(btn_pause, false)
	UITheme.style_button(btn_1x, true)
	UITheme.style_button(btn_2x, false)
	UITheme.style_button(btn_4x, false)
	UITheme.style_button(btn_skip, false)

	# Subsystem progress bars
	UITheme.style_progress_bar(bar_bat, UITheme.COLOR_CAT_POWER)
	UITheme.style_progress_bar(bar_sig, UITheme.COLOR_CAT_COMMS)
	UITheme.style_progress_bar(bar_buf, UITheme.COLOR_CAT_DATA)
	UITheme.style_progress_bar(bar_prop, UITheme.COLOR_CAT_PROPULSION)

	# Camera switcher buttons
	UITheme.style_button(btn_cam_vista, true)
	UITheme.style_button(btn_cam_focus, false)
	UITheme.style_button(btn_cam_surface, false)
	UITheme.style_button(btn_cam_free, false)
	UITheme.style_button(btn_cam_sample, false)

	btn_cam_vista.pressed.connect(func(): _set_cam_mode(CameraMode.VISTA, btn_cam_vista))
	btn_cam_focus.pressed.connect(func(): _set_cam_mode(CameraMode.FOCUS, btn_cam_focus))
	btn_cam_surface.pressed.connect(func(): _set_cam_mode(CameraMode.SURFACE, btn_cam_surface))
	btn_cam_free.pressed.connect(func(): _set_cam_mode(CameraMode.FREE, btn_cam_free))
	btn_cam_sample.pressed.connect(func(): _start_sampling_cutscene())

	# Sampling cutscene UI styling
	UITheme.style_button(btn_skip_cutscene, true)
	UITheme.style_progress_bar(bar_coring, UITheme.COLOR_ACCENT_CYAN)
	btn_skip_cutscene.pressed.connect(_end_sampling_cutscene)
	cutscene_sampling.visible = false

	# Intro Banner
	panel_intro.add_theme_stylebox_override("panel", UITheme.create_panel_style(Color(0.04, 0.08, 0.16, 0.94), UITheme.COLOR_ACCENT_CYAN, 4))
	UITheme.style_button(btn_skip_intro, true)
	btn_skip_intro.pressed.connect(_end_intro)

	modal_decision.visible = false
	modal_decision.add_theme_stylebox_override("panel", UITheme.create_panel_style(Color(0.04, 0.08, 0.15, 0.98), UITheme.COLOR_ACCENT_GOLD, 6))

	btn_pause.pressed.connect(_on_pause_toggle)
	btn_1x.pressed.connect(func(): _set_speed(1.0, btn_1x))
	btn_2x.pressed.connect(func(): _set_speed(2.0, btn_2x))
	btn_4x.pressed.connect(func(): _set_speed(4.0, btn_4x))
	btn_skip.pressed.connect(_on_skip_pressed)

	sim_engine.phase_changed.connect(_on_phase_changed)
	sim_engine.telemetry_updated.connect(_on_telemetry_updated)
	sim_engine.event_occurred.connect(_on_event_occurred)
	sim_engine.decision_requested.connect(_on_decision_requested)
	sim_engine.simulation_finished.connect(_on_simulation_finished)

	_init_simulation()

func _init_simulation() -> void:
	var gm = _gm()
	var mm = _mm()

	var mission = gm.current_mission if gm != null else null
	var spacecraft = gm.current_spacecraft if gm != null else null

	if mission == null and mm != null:
		mission = mm.get_mission("earth_observation")
		if gm != null:
			gm.select_mission(mission)
	if spacecraft == null:
		spacecraft = SpacecraftConfig.new()

	if planet_node != null and mission != null:
		planet_node.set_mission_context(mission, spacecraft)

	if mission != null:
		lbl_mission_name.text = "FLIGHT TELEMETRY // " + mission.mission_name.to_upper()
		lbl_intro_title.text = "MISSIONFORGE // %s INITIATION" % mission.mission_name.to_upper()
		lbl_intro_sub.text = "DESTINATION: %s // FLIGHT SYSTEM NOMINAL" % mission.destination.to_upper()

	# Build spacecraft 3D mesh
	_craft_preview_builder = SpacecraftPreview.new()
	_craft_preview_builder.auto_rotate = false
	craft_node.add_child(_craft_preview_builder)
	_craft_preview_builder.rebuild_spacecraft(spacecraft)

	# Build thruster plume
	_setup_thruster_plume()

	# Launch engine
	sim_engine.start_simulation(spacecraft, mission)
	var am = _am()
	if am != null:
		am.play_launch()

func _setup_thruster_plume() -> void:
	_thruster_plume_mesh = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.24
	cone.height = 0.8
	_thruster_plume_mesh.mesh = cone
	var p_mat = StandardMaterial3D.new()
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.albedo_color = Color(0.12, 0.88, 1.0, 0.75) # Glowing ion/propellant blue
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_thruster_plume_mesh.material_override = p_mat
	_thruster_plume_mesh.position = Vector3(0.0, -0.65, 0.0)
	_thruster_plume_mesh.visible = false
	craft_node.add_child(_thruster_plume_mesh)

func _process(delta: float) -> void:
	# 1. Surface Sampling Cutscene Sequence
	if _is_sampling_cutscene:
		_update_sampling_cutscene(delta)
		return

	# 2. Skippable fly-in intro sequence
	if _is_intro_playing:
		_intro_elapsed += delta
		var t = clampf(_intro_elapsed / INTRO_DURATION, 0.0, 1.0)
		var ease_t = 1.0 - pow(1.0 - t, 3.0)
		var start_cam_pos = Vector3(4.5, 6.0, 9.0)
		var end_cam_pos = Vector3(1.2, 0.8, 4.2)
		cam_3d.position = start_cam_pos.lerp(end_cam_pos, ease_t)
		cam_3d.look_at(craft_pivot.position, Vector3.UP)
		if t >= 1.0:
			_end_intro()
		return

	# 3. Thruster plume animation during launch (phase 0) or descent (phase 2)
	var phase_idx = int(sim_engine.current_phase)
	var is_burning = (phase_idx == 0 or phase_idx == 2)
	if _thruster_plume_mesh != null:
		_thruster_plume_mesh.visible = is_burning
		if is_burning:
			var flicker = randf_range(0.85, 1.25)
			_thruster_plume_mesh.scale = Vector3(flicker, randf_range(0.9, 1.4), flicker)

	# 4. Dynamic camera updates
	_update_camera_mode(delta, phase_idx)

func _update_camera_mode(delta: float, phase_idx: int) -> void:
	var speed_mult = sim_engine.sim_speed

	match _current_cam_mode:
		CameraMode.VISTA:
			craft_pivot.rotate_y(0.22 * delta * speed_mult)
			var target_pos = Vector3(1.8, 1.2, 4.6)
			cam_3d.position = cam_3d.position.lerp(target_pos, delta * 4.0)
			cam_3d.look_at(craft_pivot.position * 0.7, Vector3.UP)

		CameraMode.FOCUS:
			craft_pivot.rotate_y(0.18 * delta * speed_mult)
			var target_pos = craft_pivot.position + Vector3(0.0, 0.35, 1.8)
			cam_3d.position = cam_3d.position.lerp(target_pos, delta * 6.0)
			cam_3d.look_at(craft_pivot.position, Vector3.UP)

		CameraMode.SURFACE:
			var target_pos = Vector3(0.2, 0.25, 2.2)
			cam_3d.position = cam_3d.position.lerp(target_pos, delta * 4.0)
			cam_3d.look_at(craft_pivot.position + Vector3(0, -0.2, 0), Vector3.UP)

		CameraMode.FREE:
			var rot_basis = Basis(Vector3.UP, _free_cam_rot_y) * Basis(Vector3.RIGHT, _free_cam_rot_x)
			var offset = rot_basis * Vector3(0, 0, _free_cam_distance)
			cam_3d.position = cam_3d.position.lerp(_free_cam_target + offset, delta * 8.0)
			cam_3d.look_at(_free_cam_target, Vector3.UP)

func _set_cam_mode(mode: CameraMode, active_btn: Button) -> void:
	_current_cam_mode = mode
	for b in [btn_cam_vista, btn_cam_focus, btn_cam_surface, btn_cam_free, btn_cam_sample]:
		UITheme.style_button(b, b == active_btn)

func _end_intro() -> void:
	_is_intro_playing = false
	if panel_intro != null:
		panel_intro.visible = false
	cam_3d.position = Vector3(1.2, 0.8, 4.2)
	cam_3d.look_at(craft_pivot.position, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if _is_sampling_cutscene and (event is InputEventKey or event is InputEventMouseButton):
		if event.is_pressed():
			_end_sampling_cutscene()
			return

	if _is_intro_playing and (event is InputEventKey or event is InputEventMouseButton):
		if event.is_pressed():
			_end_intro()
			return

	if _current_cam_mode != CameraMode.FREE:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging_free_orbit = event.pressed
			_free_drag_prev_pos = event.position
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging_free_pan = event.pressed
			_free_drag_prev_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_free_cam_distance = clamp(_free_cam_distance - 0.35, 1.2, 10.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_free_cam_distance = clamp(_free_cam_distance + 0.35, 1.2, 10.0)

	elif event is InputEventMouseMotion:
		var delta_pos = event.position - _free_drag_prev_pos
		_free_drag_prev_pos = event.position

		if _is_dragging_free_orbit:
			_free_cam_rot_y -= delta_pos.x * 0.007
			_free_cam_rot_x = clamp(_free_cam_rot_x - delta_pos.y * 0.007, -PI/2.4, PI/2.4)
		elif _is_dragging_free_pan:
			var right_vec = cam_3d.global_transform.basis.x
			var up_vec = cam_3d.global_transform.basis.y
			_free_cam_target -= (right_vec * delta_pos.x - up_vec * delta_pos.y) * 0.003

func _on_pause_toggle() -> void:
	_is_paused = not _is_paused
	if _is_paused:
		sim_engine.pause_simulation()
		btn_pause.text = "RESUME"
	else:
		sim_engine.resume_simulation()
		btn_pause.text = "PAUSE"

func _set_speed(speed: float, active_btn: Button) -> void:
	sim_engine.set_speed(speed)
	for b in [btn_1x, btn_2x, btn_4x]:
		UITheme.style_button(b, b == active_btn)

func _on_skip_pressed() -> void:
	if _is_sampling_cutscene:
		_end_sampling_cutscene()
	if modal_decision.visible:
		modal_decision.visible = false
	sim_engine.skip_to_end()

func _on_phase_changed(phase_idx: int, phase_name: String) -> void:
	lbl_phase.text = phase_name.to_upper()
	if planet_node != null:
		planet_node.set_phase(phase_idx)

	var am = _am()
	if am != null:
		am.play_telemetry()

	# If arriving at surface operations and vehicle has sampling hardware (drill):
	if phase_idx == 3: # SimPhase.OPERATIONS
		var gm = _gm()
		var sc = gm.current_spacecraft if gm != null else null
		if sc != null and (sc.has_component("inst_mars_drill") or sc.has_component("inst_lunar_drill")):
			btn_cam_sample.visible = true
			if not _has_played_sample_cutscene:
				_start_sampling_cutscene()

func _on_telemetry_updated(telemetry: Dictionary) -> void:
	bar_phase_progress.value = telemetry.get("progress", 0.0) * 100.0

	val_time.text = "Day %.1f / %.0f" % [
		telemetry.get("mission_elapsed_days", 0.0),
		sim_engine.total_mission_target_days
	]

	var alt = telemetry.get("altitude_km", 0.0)
	if alt > 10000.0:
		val_alt.text = "%.1fM km" % (alt / 1000000.0)
	else:
		val_alt.text = "%.1f km" % alt

	val_vel.text = "%.2f km/s" % telemetry.get("velocity_kms", 0.0)

	# 1. Power Bus & Battery Gauge
	var bat_pct = telemetry.get("battery_percent", 100.0)
	var bat_wh = telemetry.get("battery_wh", 1200.0)
	var net_w = telemetry.get("power_net_w", 0.0)
	if bar_bat != null:
		bar_bat.value = bat_pct
	if val_bat_flow != null:
		val_bat_flow.text = "%.0f%% (%.0f Wh | %+.0fW)" % [bat_pct, bat_wh, net_w]
		if bat_pct < 25.0:
			val_bat_flow.add_theme_color_override("font_color", UITheme.COLOR_DANGER)
		elif bat_pct < 60.0:
			val_bat_flow.add_theme_color_override("font_color", UITheme.COLOR_WARNING)
		else:
			val_bat_flow.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)

	# 2. DSN Signal Margin Gauge
	var sig_db = telemetry.get("signal_margin_db", 24.0)
	if bar_sig != null:
		bar_sig.value = clampf((sig_db / 30.0) * 100.0, 0.0, 100.0)
	if val_sig_flow != null:
		var sig_status = "HIGH MARGIN" if sig_db >= 15.0 else ("FAINT LINK" if sig_db >= 6.0 else "LINK MARGINAL")
		val_sig_flow.text = "+%.1f dB [%s]" % [sig_db, sig_status]

	# 3. Solid-State Storage Buffer Gauge
	var d_col = telemetry.get("data_collected", 0.0)
	var d_down = telemetry.get("data_downlinked", 0.0)
	var d_buf = telemetry.get("data_buffered", 0.0)
	var gm = _gm()
	var buf_cap_mb = 500.0
	if gm != null and gm.current_spacecraft != null:
		buf_cap_mb = max(50.0, gm.current_spacecraft.total_storage_capacity_gb * 1000.0)
	if bar_buf != null:
		bar_buf.value = clampf((d_buf / buf_cap_mb) * 100.0, 0.0, 100.0)
	if val_buf_flow != null:
		val_buf_flow.text = "%.0f / %.0f MB (%.0f%% Full)" % [d_buf, buf_cap_mb, (d_buf / buf_cap_mb) * 100.0]

	# 4. Propellant & Delta-V Gauge
	var prop_tot = 1.0
	var dv_avail = 0.0
	if gm != null and gm.current_spacecraft != null:
		prop_tot = max(1.0, gm.current_spacecraft.total_propellant_mass)
		dv_avail = gm.current_spacecraft.total_delta_v
	var phase_frac = clampf(float(sim_engine.current_phase) / 5.0, 0.0, 1.0)
	var prop_rem = prop_tot * (1.0 - phase_frac * 0.45)
	if bar_prop != null:
		bar_prop.value = (prop_rem / prop_tot) * 100.0
	if val_prop_flow != null:
		val_prop_flow.text = "%.0f / %.0f kg (Delta-V: %.0f m/s)" % [prop_rem, prop_tot, dv_avail * (prop_rem / prop_tot)]

func _on_event_occurred(ev: Dictionary) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var time_lbl = Label.new()
	time_lbl.text = "[D+%.1f]" % ev.get("day", 0.0)
	time_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	time_lbl.add_theme_font_size_override("font_size", 11)

	var sev = ev.get("severity", "info")
	var sev_lbl = Label.new()
	var am = _am()
	match sev:
		"critical":
			sev_lbl.text = "[CRIT]"
			sev_lbl.add_theme_color_override("font_color", UITheme.COLOR_DANGER)
			if am != null: am.play_error()
		"warning":
			sev_lbl.text = "[WARN]"
			sev_lbl.add_theme_color_override("font_color", UITheme.COLOR_WARNING)
			if am != null: am.play_warning()
		"success":
			sev_lbl.text = "[OK]"
			sev_lbl.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
		_:
			sev_lbl.text = "[INFO]"
			sev_lbl.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_CYAN)

	sev_lbl.add_theme_font_size_override("font_size", 11)

	var msg_lbl = Label.new()
	msg_lbl.text = "%s: %s" % [ev.get("title", ""), ev.get("message", "")]
	msg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WHITE)
	msg_lbl.add_theme_font_size_override("font_size", 11)

	row.add_child(time_lbl)
	row.add_child(sev_lbl)
	row.add_child(msg_lbl)
	list_events.add_child(row)

	# Auto-scroll to bottom of event log
	await get_tree().process_frame
	if scroll_events != null and scroll_events.get_v_scroll_bar() != null:
		scroll_events.scroll_vertical = int(scroll_events.get_v_scroll_bar().max_value)

func _on_decision_requested(dec_data: Dictionary) -> void:
	lbl_dec_header.text = dec_data.get("title", "FLIGHT DIRECTOR INTERVENTION")
	lbl_dec_context.text = dec_data.get("context", "")

	for child in vbox_options.get_children():
		child.queue_free()

	var options = dec_data.get("options", [])
	for i in range(options.size()):
		var opt = options[i]
		var opt_btn = Button.new()
		opt_btn.custom_minimum_size = Vector2(0, 52)
		opt_btn.text = "%s\n%s" % [opt.get("title", ""), opt.get("effect", "")]
		opt_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UITheme.style_button(opt_btn, i == 1)

		var idx = i
		opt_btn.pressed.connect(func():
			modal_decision.visible = false
			sim_engine.submit_decision(idx)
		)
		vbox_options.add_child(opt_btn)

	modal_decision.visible = true
	var am = _am()
	if am != null:
		am.play_warning()

func _on_simulation_finished(result: MissionResult) -> void:
	if _is_sampling_cutscene:
		_end_sampling_cutscene()
	modal_decision.visible = false
	var am = _am()
	if am != null:
		if result.mission_completed:
			am.play_success()
		else:
			am.play_error()

	# Transition to Mission Report after short delay
	await get_tree().create_timer(1.2).timeout
	var sm = _sm()
	if sm != null:
		sm.switch_to_scene("report")

# ==============================================================================
# SURFACE SAMPLE RETRIEVAL CUTSCENE SYSTEM
# ==============================================================================
var _laser_mesh: ImmediateMesh

func _setup_sampling_rig() -> void:
	if _sampling_rig != null:
		return
	_sampling_rig = Node3D.new()
	_sampling_rig.name = "SamplingRig"
	_sampling_rig.visible = false
	craft_pivot.add_child(_sampling_rig)

	var gm = _gm()
	var dest = gm.current_mission.destination if gm != null and gm.current_mission != null else "Mars"
	var is_mars = (dest == "Mars")

	# 1. Surface Bedrock Outcrop Slab beneath rover front equipment deck
	var bedrock = MeshInstance3D.new()
	var b_box = BoxMesh.new()
	b_box.size = Vector3(1.6, 0.18, 1.4)
	bedrock.mesh = b_box
	bedrock.position = Vector3(-0.25, -0.42, 0.95)

	var b_mat = StandardMaterial3D.new()
	if is_mars:
		b_mat.albedo_color = Color(0.74, 0.34, 0.18) # Martian hematite claystone
		b_mat.roughness = 0.92
	else:
		b_mat.albedo_color = Color(0.48, 0.50, 0.54) # Lunar highland regolith / PSR cold trap
		b_mat.roughness = 0.95
		b_mat.metallic = 0.08
	bedrock.material_override = b_mat
	_sampling_rig.add_child(bedrock)

	# 2. Concentric Target Ring on Bedrock
	var ring = MeshInstance3D.new()
	var r_cyl = CylinderMesh.new()
	r_cyl.top_radius = 0.09
	r_cyl.bottom_radius = 0.09
	r_cyl.height = 0.005
	ring.mesh = r_cyl
	ring.position = Vector3(-0.23, -0.325, 0.95)
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.2, 0.22, 0.26)
	r_mat.roughness = 0.9
	ring.material_override = r_mat
	_sampling_rig.add_child(ring)

	# 3. Borehole cylinder that deepens during percussive coring
	_borehole_mesh = MeshInstance3D.new()
	var hole = CylinderMesh.new()
	hole.top_radius = 0.024
	hole.bottom_radius = 0.024
	hole.height = 0.02
	_borehole_mesh.mesh = hole
	_borehole_mesh.position = Vector3(-0.23, -0.326, 0.95)
	var h_mat = StandardMaterial3D.new()
	h_mat.albedo_color = Color(0.08, 0.05, 0.04)
	_borehole_mesh.material_override = h_mat
	_sampling_rig.add_child(_borehole_mesh)

	# 4. ImmediateMesh Laser Beam from mast/turret head to rock target
	_laser_beam_mesh = MeshInstance3D.new()
	_laser_mesh = ImmediateMesh.new()
	_laser_beam_mesh.mesh = _laser_mesh
	var l_mat = StandardMaterial3D.new()
	l_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	l_mat.albedo_color = Color(1.0, 0.22, 0.28, 0.95) if is_mars else Color(0.1, 0.95, 1.0, 0.95)
	l_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_beam_mesh.material_override = l_mat
	_sampling_rig.add_child(_laser_beam_mesh)

	# 5. Laser Impact Glow Disk on Rock Surface
	_laser_impact_mesh = MeshInstance3D.new()
	var imp = SphereMesh.new()
	imp.radius = 0.035
	imp.height = 0.015
	_laser_impact_mesh.mesh = imp
	_laser_impact_mesh.position = Vector3(-0.23, -0.32, 0.95)
	var imp_mat = StandardMaterial3D.new()
	imp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	imp_mat.albedo_color = Color(1.0, 0.9, 0.5, 0.9)
	imp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_impact_mesh.material_override = imp_mat
	_laser_impact_mesh.visible = false
	_sampling_rig.add_child(_laser_impact_mesh)

func _start_sampling_cutscene() -> void:
	if _is_sampling_cutscene:
		return
	_setup_sampling_rig()
	if _sampling_rig != null:
		_sampling_rig.visible = true

	_prev_cam_mode_before_cutscene = _current_cam_mode
	_is_sampling_cutscene = true
	_sampling_elapsed = 0.0
	_has_played_sample_cutscene = true

	var gm = _gm()
	var dest = gm.current_mission.destination if gm != null and gm.current_mission != null else "Mars"
	var is_mars = (dest == "Mars")

	if is_mars:
		lbl_cutscene_title.text = "AUTONOMOUS MARS ROVER SAMPLE CACHING"
		lbl_cutscene_target.text = "TARGET: JEZERO CRATER DELTA // LACUSTRINE SEDIMENTARY BEDROCK"
		badge_1.text = "[1. CHEMCAM LASER ABLATION]"
		badge_2.text = "[2. PERCUSSIVE CORING]"
		badge_3.text = "[3. SAMPLE TUBE HERMETIC SEAL]"
	else:
		lbl_cutscene_title.text = "AUTONOMOUS LUNAR POLAR CORE EXTRACTION"
		lbl_cutscene_target.text = "TARGET: SHACKLETON CRATER // PERMANENTLY SHADOWED REGION (PSR)"
		badge_1.text = "[1. INFRARED THERMAL SCAN]"
		badge_2.text = "[2. CRYO REGOLITH CORING]"
		badge_3.text = "[3. VOLATILE CHAMBER SEAL]"

	cutscene_sampling.visible = true
	_set_speed(1.0, btn_1x)

	var am = _am()
	if am != null:
		am.play_telemetry()

func _update_sampling_cutscene(delta: float) -> void:
	_sampling_elapsed += delta
	var t = _sampling_elapsed

	var gm = _gm()
	var dest = gm.current_mission.destination if gm != null and gm.current_mission != null else "Mars"
	var is_mars = (dest == "Mars")

	# Animate REC indicator blink
	lbl_rec.modulate.a = 0.4 + 0.6 * abs(sin(t * 3.5))

	# Format simulated mission SOL / time
	var sol_sec = int(t * 12.0)
	lbl_cutscene_time.text = "SOL %d // T+00:%02d:%02d" % [42 if is_mars else 14, sol_sec / 60, sol_sec % 60]

	# Target contact coordinate on rock
	var rock_target = Vector3(-0.23, -0.32, 0.95)
	var laser_origin = Vector3(0.12, 0.44, 0.22) if is_mars else Vector3(-0.23, 0.25, 0.70)

	if t < 3.0:
		# ======================================================================
		# STAGE 1: LASER SPECTROSCOPY / TARGET SCAN (0.0s - 3.0s)
		# ======================================================================
		var st1_t = t / 3.0
		badge_1.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_CYAN)
		badge_2.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
		badge_3.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)

		# Camera sweeps low across bedrock toward the rover
		var cam_start = Vector3(-0.95, 0.45, 1.85)
		var cam_end = Vector3(-0.48, 0.32, 1.35)
		cam_3d.position = cam_start.lerp(cam_end, ease(st1_t, 0.5))
		cam_3d.look_at(Vector3(-0.23, -0.15, 0.92), Vector3.UP)

		# Pulsing laser beam
		var laser_flicker = sin(t * 24.0) > 0.0
		if _laser_mesh != null:
			_laser_mesh.clear_surfaces()
			if laser_flicker:
				_laser_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
				_laser_mesh.surface_add_vertex(laser_origin)
				_laser_mesh.surface_add_vertex(rock_target)
				_laser_mesh.surface_end()
		_laser_impact_mesh.visible = laser_flicker
		if laser_flicker:
			_laser_impact_mesh.scale = Vector3.ONE * randf_range(0.8, 1.6)

		# Laser audio pulse
		_audio_laser_cooldown -= delta
		if _audio_laser_cooldown <= 0.0:
			_audio_laser_cooldown = 0.26
			var am = _am()
			if am != null and am.has_method("play_laser"):
				am.play_laser()

		bar_coring.value = 0.0
		lbl_coring_status.text = "Laser Ablation: Vaporizing surface dust | Minerals: Fe/Mg smectite clays & carbonates"
		reticle_target.text = "[ + ]\nSPECTRAL TARGET ACQUIRED\nORGANIC BIOMARKER TARGET IDENTIFIED"

	elif t < 7.0:
		# ======================================================================
		# STAGE 2: PERCUSSIVE ROTARY CORING (3.0s - 7.0s)
		# ======================================================================
		var st2_t = (t - 3.0) / 4.0
		badge_1.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
		badge_2.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
		badge_3.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)

		if _laser_mesh != null:
			_laser_mesh.clear_surfaces()
		_laser_impact_mesh.visible = false

		# Macro close-up on drill turret and rock borehole
		var macro_cam = Vector3(-0.35, 0.18, 1.05)
		var cam_shake = Vector3(randf_range(-0.003, 0.003), randf_range(-0.004, 0.004), randf_range(-0.003, 0.003))
		cam_3d.position = macro_cam + cam_shake
		cam_3d.look_at(Vector3(-0.23, -0.32, 0.95), Vector3.UP)

		# Deepen borehole cylinder mesh
		var cur_depth_cm = lerpf(0.0, 12.4, st2_t)
		if _borehole_mesh != null:
			_borehole_mesh.scale.y = 1.0 + st2_t * 3.5

		# Vibrate the drill arm turret
		var drill_wrapper = _craft_preview_builder.get_component_node("inst_mars_drill") if _craft_preview_builder else null
		if drill_wrapper == null and _craft_preview_builder:
			drill_wrapper = _craft_preview_builder.get_component_node("inst_lunar_drill")
		if drill_wrapper != null:
			drill_wrapper.position.y = 0.445 + randf_range(-0.004, 0.004)

		# Coring progress
		bar_coring.value = st2_t * 100.0
		lbl_coring_status.text = "Coring depth: %.1f cm / 15.0 cm | Rate: 2,400 BPM | Bit Temp: %.0f°C" % [
			cur_depth_cm, 35.0 + st2_t * 18.0
		]
		reticle_target.text = "[ + ]\nPERCUSSIVE CORING IN PROGRESS\nDEPTH: %.1f CM // ROTARY TORQUE: 42 NM" % cur_depth_cm

		# Drill motor audio pulse
		_audio_drill_cooldown -= delta
		if _audio_drill_cooldown <= 0.0:
			_audio_drill_cooldown = 0.22
			var am = _am()
			if am != null and am.has_method("play_drill"):
				am.play_drill()

	elif t < SAMPLING_DURATION:
		# ======================================================================
		# STAGE 3: HERMETIC TUBE CACHE & SEAL (7.0s - 9.5s)
		# ======================================================================
		var st3_t = (t - 7.0) / 2.5
		badge_1.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
		badge_2.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
		badge_3.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_CYAN)

		if _laser_mesh != null:
			_laser_mesh.clear_surfaces()

		# Reset arm vibration
		var drill_wrapper = _craft_preview_builder.get_component_node("inst_mars_drill") if _craft_preview_builder else null
		if drill_wrapper == null and _craft_preview_builder:
			drill_wrapper = _craft_preview_builder.get_component_node("inst_lunar_drill")
		if drill_wrapper != null:
			drill_wrapper.position.y = 0.445

		# Elevation camera pulling back to show rover with sample secured
		var cam_end = Vector3(-0.55, 0.48, 1.25)
		cam_3d.position = cam_end
		cam_3d.look_at(Vector3(-0.25, 0.15, 0.7), Vector3.UP)

		# Seal flash ring on carousel
		_laser_impact_mesh.visible = (st3_t < 0.4)
		_laser_impact_mesh.position = Vector3(-0.25, 0.42, 0.52)
		var am = _am()
		if st3_t < 0.1 and am != null and am.has_method("play_seal"):
			am.play_seal()

		bar_coring.value = 100.0
		lbl_coring_status.text = "Hermetic Titanium Seal: 100% Locked | Sample cached in carousel slot #01"
		reticle_target.text = "[ OK ]\nSAMPLE CORE HERMETICALLY SEALED\nCACHED FOR MARS SAMPLE RETURN // +35 MB ARCHIVED"

	else:
		_end_sampling_cutscene()

func _end_sampling_cutscene() -> void:
	if not _is_sampling_cutscene:
		return
	_is_sampling_cutscene = false
	cutscene_sampling.visible = false
	if _sampling_rig != null:
		_sampling_rig.visible = false

	# Reset arm position if vibrating
	if _craft_preview_builder != null:
		var drill_wrapper = _craft_preview_builder.get_component_node("inst_mars_drill")
		if drill_wrapper == null:
			drill_wrapper = _craft_preview_builder.get_component_node("inst_lunar_drill")
		if drill_wrapper != null:
			drill_wrapper.position.y = 0.445

	# Add bonus science return to telemetry buffer
	sim_engine.data_collected_mb += 35.0
	sim_engine.data_buffered_mb = min(sim_engine.storage_capacity_mb, sim_engine.data_buffered_mb + 35.0)

	var gm = _gm()
	var dest = gm.current_mission.destination if gm != null and gm.current_mission != null else "Mars"
	var sample_name = "Pristine 12cm Jezero delta siltstone core" if dest == "Mars" else "Cryogenic Shackleton PSR water-ice core"
	var container_name = "titanium sample tube #01" if dest == "Mars" else "cryo volatile chamber #01"

	var ev = MissionEvents.create_event(
		sim_engine.mission_elapsed_days,
		SimulationEngine.PHASE_NAMES[sim_engine.current_phase],
		"Physical Sample Cached",
		"%s hermetically sealed in %s! (+35 MB science buffered)." % [sample_name, container_name],
		"success"
	)
	sim_engine.events_log.append(ev)
	sim_engine.emit_signal("event_occurred", ev)

	var am = _am()
	if am != null:
		am.play_success()

	_set_cam_mode(_prev_cam_mode_before_cutscene, btn_cam_surface)

