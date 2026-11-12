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

	btn_cam_vista.pressed.connect(func(): _set_cam_mode(CameraMode.VISTA, btn_cam_vista))
	btn_cam_focus.pressed.connect(func(): _set_cam_mode(CameraMode.FOCUS, btn_cam_focus))
	btn_cam_surface.pressed.connect(func(): _set_cam_mode(CameraMode.SURFACE, btn_cam_surface))
	btn_cam_free.pressed.connect(func(): _set_cam_mode(CameraMode.FREE, btn_cam_free))

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
	# 1. Skippable fly-in intro sequence
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

	# 2. Thruster plume animation during launch (phase 0) or descent (phase 2)
	var phase_idx = int(sim_engine.current_phase)
	var is_burning = (phase_idx == 0 or phase_idx == 2)
	if _thruster_plume_mesh != null:
		_thruster_plume_mesh.visible = is_burning
		if is_burning:
			var flicker = randf_range(0.85, 1.25)
			_thruster_plume_mesh.scale = Vector3(flicker, randf_range(0.9, 1.4), flicker)

	# 3. Dynamic camera updates
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
	for b in [btn_cam_vista, btn_cam_focus, btn_cam_surface, btn_cam_free]:
		UITheme.style_button(b, b == active_btn)

func _end_intro() -> void:
	_is_intro_playing = false
	if panel_intro != null:
		panel_intro.visible = false
	cam_3d.position = Vector3(1.2, 0.8, 4.2)
	cam_3d.look_at(craft_pivot.position, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
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
