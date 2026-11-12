extends Control

# SimulationScene
# Real-time 3D mission simulation and Mission Control telemetry interface.
# Coordinates deterministic simulation engine ticks, 3D trajectory visualization,
# live telemetry streaming, in-flight interactive decisions, and mission event feed.

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
@onready var val_bat: Label = $UI/PanelTelemetry/VBox/Grid/ValBat
@onready var val_sig: Label = $UI/PanelTelemetry/VBox/Grid/ValSig
@onready var val_data: Label = $UI/PanelTelemetry/VBox/Grid/ValData

# Event Log
@onready var list_events: VBoxContainer = $UI/PanelEvents/VBox/Scroll/ListEvents
@onready var scroll_events: ScrollContainer = $UI/PanelEvents/VBox/Scroll

# Sim controls
@onready var btn_pause: Button = $UI/PanelControls/HBox/BtnPause
@onready var btn_1x: Button = $UI/PanelControls/HBox/Btn1x
@onready var btn_2x: Button = $UI/PanelControls/HBox/Btn2x
@onready var btn_4x: Button = $UI/PanelControls/HBox/Btn4x
@onready var btn_skip: Button = $UI/PanelControls/HBox/BtnSkip

# Interactive Decision Modal
@onready var modal_decision: PanelContainer = $UI/ModalDecision
@onready var lbl_dec_header: Label = $UI/ModalDecision/VBox/LblDecHeader
@onready var lbl_dec_context: Label = $UI/ModalDecision/VBox/LblDecContext
@onready var vbox_options: VBoxContainer = $UI/ModalDecision/VBox/VBoxOptions

var _is_paused: bool = false
var _craft_preview_builder: SpacecraftPreview

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
		planet_node.planet_type = mission.destination
	if mission != null:
		lbl_mission_name.text = "FLIGHT TELEMETRY // " + mission.mission_name.to_upper()

	# Build spacecraft 3D mesh
	_craft_preview_builder = SpacecraftPreview.new()
	_craft_preview_builder.auto_rotate = false
	craft_node.add_child(_craft_preview_builder)
	_craft_preview_builder.rebuild_spacecraft(spacecraft)

	# Launch engine
	sim_engine.start_simulation(spacecraft, mission)
	var am = _am()
	if am != null:
		am.play_launch()

func _process(delta: float) -> void:
	# Subtle 3D dynamic camera and spacecraft motion based on phase
	var phase_idx = int(sim_engine.current_phase)
	var speed_mult = sim_engine.sim_speed

	match phase_idx:
		0: # Launch: craft rises upwards
			craft_pivot.position.y = lerpf(craft_pivot.position.y, 1.2, delta * 0.8 * speed_mult)
			craft_pivot.rotation.x = -PI / 8.0
			cam_3d.position = Vector3(0.0, craft_pivot.position.y + 0.3, 3.8)
		1: # Cruise: orbital flight around planet
			craft_pivot.rotate_y(0.35 * delta * speed_mult)
			craft_pivot.position.y = lerpf(craft_pivot.position.y, 0.0, delta)
			cam_3d.position = Vector3(1.2, 0.8, 4.2)
		2: # Arrival / Descent: craft angles down towards planet
			craft_pivot.rotation.x = lerpf(craft_pivot.rotation.x, PI / 6.0, delta * speed_mult)
			craft_pivot.position.z = lerpf(craft_pivot.position.z, -0.6, delta * 0.5 * speed_mult)
			cam_3d.position = Vector3(0.5, 0.5, 3.5)
		3: # Operations: surface / orbit survey
			craft_pivot.rotate_y(0.15 * delta * speed_mult)
			cam_3d.position = Vector3(-0.8, 0.4, 3.2)
		4, 5: # Downlink & Evaluation
			craft_pivot.rotate_y(0.08 * delta * speed_mult)
			cam_3d.position = Vector3(0.0, 0.6, 3.5)

	cam_3d.look_at(craft_pivot.position, Vector3.UP)

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
	
	var bat_pct = telemetry.get("battery_percent", 100.0)
	var bat_wh = telemetry.get("battery_wh", 1200.0)
	var net_w = telemetry.get("power_net_w", 0.0)
	val_bat.text = "%.0f%% (%.0f Wh | %+.0fW)" % [bat_pct, bat_wh, net_w]
	if bat_pct < 25.0:
		val_bat.add_theme_color_override("font_color", UITheme.COLOR_DANGER)
	elif bat_pct < 60.0:
		val_bat.add_theme_color_override("font_color", UITheme.COLOR_WARNING)
	else:
		val_bat.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)

	val_sig.text = "+%.1f dB" % telemetry.get("signal_margin_db", 20.0)

	var d_col = telemetry.get("data_collected", 0.0)
	var d_down = telemetry.get("data_downlinked", 0.0)
	var d_buf = telemetry.get("data_buffered", 0.0)
	val_data.text = "%.0f DL / %.0f Buf MB" % [d_down, d_buf]

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
