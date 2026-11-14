extends Control

# SimulationScene
# Real-time 3D mission simulation and Mission Control telemetry interface.
# Coordinates deterministic simulation engine ticks, 3D trajectory visualization,
# live telemetry streaming, in-flight interactive decisions, and mission event feed.
# Features:
# - Visual telemetry gauges: Energy flow (DoD), Comms DSN margin, SSD buffer fill, Propellant reserve
# - 4 Camera Modes: Orbit Vista, Spacecraft Focus, Surface Operations, Free Orbit/Pan/Zoom Cam
# - Skippable cinematic approach intro sequence
# - Realistic Planetary Landing Cutscene (NASA Mars 2020 Sky Crane EDL / Lunar Soft Landing)
# - Realistic 5-Stage Surface Operations Cutscene (Mastcam recon, SuperCam laser ablation, 
#   5-joint robotic arm coring, sample caching & sealing, autonomous traverse)

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

# Cutscene UI
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
var _lbl_free_hint: Label
var _lbl_earth_cam_hud: Label

var _is_intro_playing: bool = true
var _intro_elapsed: float = 0.0
const INTRO_DURATION: float = 2.8

# Planetary Surface Terrain Environment
var _surface_env: SurfaceEnvironment

# Planetary Landing Cutscene State
var _is_landing_cutscene: bool = false
var _landing_elapsed: float = 0.0
const LANDING_DURATION: float = 7.5
var _has_played_landing_cutscene: bool = false
var _sky_crane_rig: Node3D
var _sky_crane_plumes: Array[MeshInstance3D] = []
var _bridle_cables_mesh: ImmediateMesh
var _bridle_mesh_inst: MeshInstance3D
var _landing_dust_cloud: MeshInstance3D

# Surface Sampling Cutscene State
var _is_sampling_cutscene: bool = false
var _sampling_elapsed: float = 0.0
const SAMPLING_DURATION: float = 16.0
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

	var dest = "Earth"
	var gm = _gm()
	if gm != null and gm.current_mission != null:
		dest = gm.current_mission.destination

	if dest == "Earth":
		btn_cam_surface.text = "EARTH CAM"
		btn_cam_surface.tooltip_text = "Onboard Satellite Optical Imager (Facing Earth)"
	else:
		btn_cam_surface.text = "SURFACE"
		btn_cam_surface.tooltip_text = "Surface Operations Camera"

	btn_cam_vista.pressed.connect(func(): _set_cam_mode(CameraMode.VISTA, btn_cam_vista))
	btn_cam_focus.pressed.connect(func(): _set_cam_mode(CameraMode.FOCUS, btn_cam_focus))
	btn_cam_surface.pressed.connect(func(): _set_cam_mode(CameraMode.SURFACE, btn_cam_surface))
	btn_cam_free.pressed.connect(func(): _set_cam_mode(CameraMode.FREE, btn_cam_free))
	btn_cam_sample.pressed.connect(func(): _start_sampling_cutscene())

	# Connect ViewportContainer direct GUI input for smooth, reliable free cam controls
	if has_node("ViewportContainer"):
		$ViewportContainer.gui_input.connect(_on_viewport_gui_input)

	# Free Cam On-screen HUD Instructions
	_lbl_free_hint = Label.new()
	_lbl_free_hint.name = "LblFreeHint"
	_lbl_free_hint.text = "[FREE CAM ACTIVE] LMB: Orbit | RMB / WASD: Pan | Wheel: Zoom | R: Reset Focus"
	_lbl_free_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_free_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_free_hint.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_CYAN)
	_lbl_free_hint.add_theme_font_size_override("font_size", 12)

	var free_hint_bg = StyleBoxFlat.new()
	free_hint_bg.bg_color = Color(0.02, 0.06, 0.12, 0.82)
	free_hint_bg.border_color = Color(0.0, 0.85, 1.0, 0.50)
	free_hint_bg.set_border_width_all(1)
	free_hint_bg.set_corner_radius_all(4)
	free_hint_bg.content_margin_left = 14.0
	free_hint_bg.content_margin_right = 14.0
	free_hint_bg.content_margin_top = 4.0
	free_hint_bg.content_margin_bottom = 4.0
	_lbl_free_hint.add_theme_stylebox_override("normal", free_hint_bg)

	_lbl_free_hint.anchor_left = 0.5
	_lbl_free_hint.anchor_right = 0.5
	_lbl_free_hint.anchor_top = 1.0
	_lbl_free_hint.anchor_bottom = 1.0
	_lbl_free_hint.offset_left = -320.0
	_lbl_free_hint.offset_right = 320.0
	_lbl_free_hint.offset_top = -102.0
	_lbl_free_hint.offset_bottom = -72.0
	_lbl_free_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_free_hint.visible = false
	$UI.add_child(_lbl_free_hint)

	# Earth Cam On-screen HUD Telemetry
	_lbl_earth_cam_hud = Label.new()
	_lbl_earth_cam_hud.name = "LblEarthCamHud"
	_lbl_earth_cam_hud.text = "[ONBOARD NADIR OPTICAL SENSOR // 705 KM SSO]\nGROUND TRACK: 98.2° INC | 9-BAND MULTISPECTRAL PUSHBROOM ACTIVE"
	_lbl_earth_cam_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_earth_cam_hud.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0, 0.9))
	_lbl_earth_cam_hud.add_theme_font_size_override("font_size", 12)
	_lbl_earth_cam_hud.anchor_left = 0.0
	_lbl_earth_cam_hud.anchor_right = 1.0
	_lbl_earth_cam_hud.anchor_top = 0.0
	_lbl_earth_cam_hud.anchor_bottom = 0.0
	_lbl_earth_cam_hud.offset_left = 0.0
	_lbl_earth_cam_hud.offset_right = 0.0
	_lbl_earth_cam_hud.offset_top = 74.0
	_lbl_earth_cam_hud.offset_bottom = 114.0
	_lbl_earth_cam_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_earth_cam_hud.visible = false
	$UI.add_child(_lbl_earth_cam_hud)

	# Sampling cutscene UI styling
	UITheme.style_button(btn_skip_cutscene, true)
	UITheme.style_progress_bar(bar_coring, UITheme.COLOR_ACCENT_CYAN)
	btn_skip_cutscene.pressed.connect(_on_skip_cutscene_pressed)
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

	# Build Planetary Surface Terrain Environment
	_surface_env = SurfaceEnvironment.new()
	_surface_env.name = "SurfaceEnvironment"
	$ViewportContainer/SubViewport.add_child(_surface_env)
	if mission != null:
		_surface_env.setup_surface(mission.destination)
	_surface_env.visible = false

	if mission != null:
		lbl_mission_name.text = "FLIGHT TELEMETRY // " + mission.mission_name.to_upper()
		lbl_intro_title.text = "MISSIONFORGE // %s INITIATION" % mission.mission_name.to_upper()
		lbl_intro_sub.text = "DESTINATION: %s // FLIGHT SYSTEM NOMINAL" % mission.destination.to_upper()

	# Build spacecraft 3D mesh
	_craft_preview_builder = SpacecraftPreview.new()
	_craft_preview_builder.auto_rotate = false
	craft_node.add_child(_craft_preview_builder)
	_craft_preview_builder.rebuild_spacecraft(spacecraft)

	# Initial position and scale on authentic NASA orbital trajectory ring
	var dest = mission.destination if mission != null else "Earth"
	var init_alt_ratio = 705.0 / 6371.0
	if dest == "Moon":
		init_alt_ratio = 100.0 / 1737.4
	elif dest == "Mars":
		init_alt_ratio = 255.0 / 3389.5
	var init_planet_r = planet_node.radius if planet_node != null else 3.5
	var init_target_dist = init_planet_r * (1.0 + init_alt_ratio)
	var init_p_pos = planet_node.position if planet_node != null else Vector3(0, -0.8, -4.5)
	var init_dir_from_planet = Vector3(0.0, 0.17503, 0.98456).normalized()
	craft_pivot.position = init_p_pos + init_dir_from_planet * init_target_dist
	craft_node.scale = Vector3(0.28, 0.28, 0.28)

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

func _is_on_surface() -> bool:
	return _surface_env != null and _surface_env.visible

func _process(delta: float) -> void:
	# 1. Planetary Landing Cutscene Sequence
	if _is_landing_cutscene:
		_update_landing_cutscene(delta)
		return

	# 2. Surface Sampling Cutscene Sequence
	if _is_sampling_cutscene:
		_update_sampling_cutscene(delta)
		return

	# 3. Skippable fly-in intro sequence
	if _is_intro_playing:
		_intro_elapsed += delta
		var t = clampf(_intro_elapsed / INTRO_DURATION, 0.0, 1.0)
		var ease_t = 1.0 - pow(1.0 - t, 3.0)
		var start_cam_pos = craft_pivot.position + Vector3(3.5, 4.0, 6.5)
		var end_cam_pos = craft_pivot.position + Vector3(0.95, 0.65, 2.3)
		cam_3d.position = start_cam_pos.lerp(end_cam_pos, ease_t)
		cam_3d.look_at(craft_pivot.position, Vector3.UP)
		if t >= 1.0:
			_end_intro()
		return

	# 4. Thruster plume animation during launch (phase 0) or descent (phase 2)
	var phase_idx = int(sim_engine.current_phase)
	var is_burning = (phase_idx == 0 or (phase_idx == 2 and not _is_on_surface()))
	if _thruster_plume_mesh != null:
		_thruster_plume_mesh.visible = is_burning
		if is_burning:
			var flicker = randf_range(0.85, 1.25)
			_thruster_plume_mesh.scale = Vector3(flicker, randf_range(0.9, 1.4), flicker)

	# 5. Dynamic camera updates
	_update_camera_mode(delta, phase_idx)

func _update_camera_mode(delta: float, phase_idx: int) -> void:
	var speed_mult = sim_engine.sim_speed

	var destination = "Earth"
	var gm = _gm()
	if gm != null and gm.current_mission != null:
		destination = gm.current_mission.destination

	if _is_on_surface():
		# On planetary surface: rover/lander is 1:1 on the ground terrain
		craft_node.scale = craft_node.scale.lerp(Vector3(1.0, 1.0, 1.0), delta * 4.0)
		craft_node.rotation.x = 0.0
		craft_node.rotation.z = 0.0
		craft_pivot.rotation.x = 0.0
		craft_pivot.rotation.z = 0.0

		match _current_cam_mode:
			CameraMode.VISTA:
				var target_pos = craft_pivot.position + Vector3(3.2, 1.4, 4.6)
				cam_3d.position = cam_3d.position.lerp(target_pos, delta * 3.5)
				cam_3d.look_at(craft_pivot.position + Vector3(0.0, 0.25, 0.0), Vector3.UP)

			CameraMode.FOCUS:
				var target_pos = craft_pivot.position + Vector3(1.2, 0.7, 2.4)
				cam_3d.position = cam_3d.position.lerp(target_pos, delta * 5.0)
				cam_3d.look_at(craft_pivot.position + Vector3(0.0, 0.2, 0.0), Vector3.UP)

			CameraMode.SURFACE:
				var target_pos = craft_pivot.position + Vector3(-1.1, 0.16, 2.2)
				cam_3d.position = cam_3d.position.lerp(target_pos, delta * 4.0)
				cam_3d.look_at(craft_pivot.position + Vector3(0.0, 0.0, 0.2), Vector3.UP)

			CameraMode.FREE:
				_update_free_cam_keyboard(delta)
				var rot_basis = Basis(Vector3.UP, _free_cam_rot_y) * Basis(Vector3.RIGHT, _free_cam_rot_x)
				var offset = rot_basis * Vector3(0, 0, _free_cam_distance)
				cam_3d.position = cam_3d.position.lerp(_free_cam_target + offset, delta * 8.0)
				cam_3d.look_at(_free_cam_target, Vector3.UP)
	else:
		# In space (orbital phases around Earth, Moon, or Mars)
		# 1. Scale spacecraft to authentic NASA representation (shrunk relative to planet)
		var target_scale = Vector3(0.28, 0.28, 0.28)
		if _current_cam_mode == CameraMode.FOCUS:
			target_scale = Vector3(0.48, 0.48, 0.48)
		craft_node.scale = craft_node.scale.lerp(target_scale, delta * 4.0)

		# 2. Authentic NASA Orbital Altitude & Inclination
		# Earth: 705 km / 6371 km SSO (11.07% altitude, 10.5° visual inclination)
		# Moon: 100 km / 1737.4 km LLO (5.76% altitude, 0° polar)
		# Mars: 255 km / 3389.5 km MSO (7.52% altitude, -5° inclination)
		var alt_ratio = 705.0 / 6371.0
		var inc_deg = 10.5
		if destination == "Moon":
			alt_ratio = 100.0 / 1737.4
			inc_deg = 0.0
		elif destination == "Mars":
			alt_ratio = 255.0 / 3389.5
			inc_deg = -5.0

		var planet_r = 3.5
		if planet_node != null:
			planet_r = planet_node.radius
		var target_dist = planet_r * (1.0 + alt_ratio)
		var p_pos = planet_node.position if planet_node != null else Vector3(0, -0.8, -4.5)
		var dir_from_planet = Vector3(0.0, 0.17503, 0.98456).normalized()
		var target_craft_pos = p_pos + dir_from_planet * target_dist
		craft_pivot.position = craft_pivot.position.lerp(target_craft_pos, delta * 3.0)

		# 3. Nadir-Pointing Attitude (Satellite Camera aperture on -Y face locks to Earth / Planet center)
		# Tangent flight vector is strictly aligned with the orbital trajectory ring
		var to_planet = (p_pos - craft_pivot.position).normalized()
		var up_zenith = -to_planet
		var rad = deg_to_rad(inc_deg)
		var orbit_normal = Vector3(cos(rad), -sin(rad) * dir_from_planet.z, sin(rad) * dir_from_planet.y).normalized()
		var tangent_vel = orbit_normal.cross(dir_from_planet).normalized()
		var right_solar = up_zenith.cross(tangent_vel)
		var nadir_basis = Basis(right_solar, up_zenith, tangent_vel)

		# Authentic attitude control reaction-wheel minute stabilization jitter
		var jitter_pitch = sin(Time.get_ticks_msec() * 0.001) * 0.015
		var jitter_yaw = cos(Time.get_ticks_msec() * 0.0008) * 0.015
		nadir_basis = nadir_basis * Basis(Vector3.RIGHT, jitter_pitch) * Basis(Vector3.UP, jitter_yaw)
		craft_node.quaternion = craft_node.quaternion.slerp(nadir_basis.get_rotation_quaternion(), delta * 5.0)

		# 4. Camera Views in Orbit
		match _current_cam_mode:
			CameraMode.VISTA:
				var target_cam_pos = craft_pivot.position + Vector3(0.95, 0.65, 2.3)
				cam_3d.position = cam_3d.position.lerp(target_cam_pos, delta * 4.0)
				cam_3d.look_at(craft_pivot.position + craft_node.position * 0.5, Vector3.UP)

			CameraMode.FOCUS:
				var target_cam_pos = craft_pivot.position + Vector3(0.38, 0.28, 1.15)
				cam_3d.position = cam_3d.position.lerp(target_cam_pos, delta * 6.0)
				cam_3d.look_at(craft_pivot.position + craft_node.position, Vector3.UP)

			CameraMode.SURFACE:
				# Onboard Satellite Camera (Nadir view looking directly down at Earth)
				var cam_mount = craft_pivot.position + craft_node.position + craft_node.basis * Vector3(0.0, -0.26, 0.08)
				cam_3d.position = cam_3d.position.lerp(cam_mount, delta * 5.0)
				cam_3d.look_at(p_pos, Vector3.UP)

			CameraMode.FREE:
				_update_free_cam_keyboard(delta)
				var rot_basis = Basis(Vector3.UP, _free_cam_rot_y) * Basis(Vector3.RIGHT, _free_cam_rot_x)
				var offset = rot_basis * Vector3(0, 0, _free_cam_distance)
				cam_3d.position = cam_3d.position.lerp(_free_cam_target + offset, delta * 8.0)
				cam_3d.look_at(_free_cam_target, Vector3.UP)

func _update_free_cam_keyboard(delta: float) -> void:
	var pan_speed = 3.5 * delta
	var right_vec = cam_3d.global_transform.basis.x
	var up_vec = cam_3d.global_transform.basis.y
	var fwd_vec = -cam_3d.global_transform.basis.z

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		_free_cam_target += fwd_vec * pan_speed
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		_free_cam_target -= fwd_vec * pan_speed
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		_free_cam_target -= right_vec * pan_speed
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		_free_cam_target += right_vec * pan_speed
	if Input.is_key_pressed(KEY_E):
		_free_cam_target += up_vec * pan_speed
	if Input.is_key_pressed(KEY_Q):
		_free_cam_target -= up_vec * pan_speed
	if Input.is_key_pressed(KEY_R):
		_free_cam_target = craft_pivot.position + craft_node.position

func _set_cam_mode(mode: CameraMode, active_btn: Button) -> void:
	if _is_intro_playing:
		_end_intro()

	_current_cam_mode = mode
	for b in [btn_cam_vista, btn_cam_focus, btn_cam_surface, btn_cam_free, btn_cam_sample]:
		UITheme.style_button(b, b == active_btn)

	if _lbl_free_hint != null:
		_lbl_free_hint.visible = (mode == CameraMode.FREE)

	var is_earth_cam = (mode == CameraMode.SURFACE and not _is_on_surface())
	if _lbl_earth_cam_hud != null:
		_lbl_earth_cam_hud.visible = is_earth_cam

	if mode == CameraMode.FREE:
		_free_cam_target = craft_pivot.position + craft_node.position
		var rel = cam_3d.position - _free_cam_target
		_free_cam_distance = clamp(rel.length(), 0.6, 12.0)
		_free_cam_rot_y = atan2(rel.x, max(0.0001, rel.z))
		_free_cam_rot_x = clamp(asin(clamp(rel.y / max(0.01, _free_cam_distance), -0.99, 0.99)), -PI/2.1, PI/2.1)

func _end_intro() -> void:
	if not _is_intro_playing:
		return
	_is_intro_playing = false
	if panel_intro != null:
		panel_intro.visible = false
	if _current_cam_mode != CameraMode.FREE:
		cam_3d.position = Vector3(1.2, 0.8, 4.2)
		cam_3d.look_at(craft_pivot.position, Vector3.UP)

func _on_skip_cutscene_pressed() -> void:
	if _is_landing_cutscene:
		_end_landing_cutscene()
	elif _is_sampling_cutscene:
		_end_sampling_cutscene()

func _on_viewport_gui_input(event: InputEvent) -> void:
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
			_free_cam_distance = clamp(_free_cam_distance - 0.25, 0.6, 12.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_free_cam_distance = clamp(_free_cam_distance + 0.25, 0.6, 12.0)

	elif event is InputEventMouseMotion:
		var delta_pos = event.position - _free_drag_prev_pos
		_free_drag_prev_pos = event.position

		if _is_dragging_free_orbit:
			_free_cam_rot_y -= delta_pos.x * 0.006
			_free_cam_rot_x = clamp(_free_cam_rot_x - delta_pos.y * 0.006, -PI/2.1, PI/2.1)
		elif _is_dragging_free_pan:
			var right_vec = cam_3d.global_transform.basis.x
			var up_vec = cam_3d.global_transform.basis.y
			_free_cam_target -= (right_vec * delta_pos.x - up_vec * delta_pos.y) * 0.003

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		_is_dragging_free_orbit = false
		_is_dragging_free_pan = false

func _unhandled_input(event: InputEvent) -> void:
	if (_is_sampling_cutscene or _is_landing_cutscene) and (event is InputEventKey or event is InputEventMouseButton):
		if event.is_pressed():
			_on_skip_cutscene_pressed()
			return

	if _is_intro_playing and (event is InputEventKey or event is InputEventMouseButton):
		if event.is_pressed():
			_end_intro()
			return

	if _current_cam_mode == CameraMode.FREE:
		_on_viewport_gui_input(event)

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
	if _is_landing_cutscene:
		_end_landing_cutscene()
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

	var gm = _gm()
	var dest = gm.current_mission.destination if gm != null and gm.current_mission != null else "Mars"
	var is_surface_mission = (dest == "Mars" or dest == "Moon")

	# SimPhase.ARRIVAL (Phase 2): Entry, Descent & Landing onto planetary surface
	if phase_idx == 2 and is_surface_mission:
		if _surface_env != null:
			_surface_env.visible = true
		if planet_node != null:
			planet_node.visible = false
		if not _has_played_landing_cutscene:
			_start_landing_cutscene()

	# SimPhase.OPERATIONS (Phase 3): Planetary Surface Operations
	elif phase_idx == 3 and is_surface_mission:
		if _surface_env != null:
			_surface_env.visible = true
		if planet_node != null:
			planet_node.visible = false
		btn_cam_sample.visible = true
		btn_cam_sample.text = "OPS CUTSCENE"
		if not _has_played_sample_cutscene:
			_start_sampling_cutscene()

	elif phase_idx >= 4 and is_surface_mission:
		if _surface_env != null:
			_surface_env.visible = true
		if planet_node != null:
			planet_node.visible = false

func _on_telemetry_updated(telemetry: Dictionary) -> void:
	bar_phase_progress.value = telemetry.get("progress", 0.0) * 100.0

	val_time.text = "Day %.1f / %.0f" % [
		telemetry.get("mission_elapsed_days", 0.0),
		sim_engine.total_mission_target_days
	]

	var alt = telemetry.get("altitude_km", 0.0)
	var gm = _gm()
	var dest = gm.current_mission.destination if gm != null and gm.current_mission != null else "Earth"
	if alt > 10000.0:
		val_alt.text = "%.1fM km" % (alt / 1000000.0)
	elif alt >= 700.0 and dest == "Earth":
		val_alt.text = "705 km (11.1% R⊕)"
	elif alt >= 90.0 and dest == "Moon" and not _is_on_surface():
		val_alt.text = "100 km (5.8% R☾)"
	elif alt >= 200.0 and dest == "Mars" and not _is_on_surface():
		val_alt.text = "255 km (7.5% R♂)"
	elif _is_on_surface():
		val_alt.text = "0.0 km (Touchdown)"
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
	if _is_landing_cutscene:
		_end_landing_cutscene()
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
# PLANETARY LANDING CUTSCENE SYSTEM (SKY CRANE & POWERED DESCENT)
# ==============================================================================
func _setup_sky_crane_rig() -> void:
	if _sky_crane_rig != null:
		return
	_sky_crane_rig = Node3D.new()
	_sky_crane_rig.name = "SkyCraneRig"
	_sky_crane_rig.visible = false
	craft_pivot.add_child(_sky_crane_rig)

	# 1. Main Octagonal Descent Stage Chassis
	var body = MeshInstance3D.new()
	var b_box = BoxMesh.new()
	b_box.size = Vector3(1.3, 0.35, 1.3)
	body.mesh = b_box
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.82, 0.78, 0.68) # Gold-titanium MLI foil
	b_mat.metallic = 0.88
	b_mat.roughness = 0.28
	body.material_override = b_mat
	_sky_crane_rig.add_child(body)

	# Central fuel tank dome on Sky Crane top
	var tank = MeshInstance3D.new()
	var t_sph = SphereMesh.new()
	t_sph.radius = 0.38
	t_sph.height = 0.55
	tank.mesh = t_sph
	tank.position = Vector3(0.0, 0.16, 0.0)
	var t_mat = StandardMaterial3D.new()
	t_mat.albedo_color = Color(0.75, 0.76, 0.8)
	t_mat.metallic = 0.95
	tank.material_override = t_mat
	_sky_crane_rig.add_child(tank)

	# 2. 4 Canted Hydrazine Thrusters & Plumes on Outriggers
	var thruster_mat = StandardMaterial3D.new()
	thruster_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	thruster_mat.albedo_color = Color(1.0, 0.62, 0.12, 0.90)
	thruster_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var nozzle_offsets = [
		Vector3(-0.65, -0.12, -0.65),
		Vector3(0.65, -0.12, -0.65),
		Vector3(-0.65, -0.12, 0.65),
		Vector3(0.65, -0.12, 0.65)
	]

	_sky_crane_plumes.clear()
	for off in nozzle_offsets:
		var nozzle = MeshInstance3D.new()
		var n_cyl = CylinderMesh.new()
		n_cyl.top_radius = 0.035
		n_cyl.bottom_radius = 0.075
		n_cyl.height = 0.14
		nozzle.mesh = n_cyl
		nozzle.position = off
		var n_mat = StandardMaterial3D.new()
		n_mat.albedo_color = Color(0.22, 0.24, 0.28)
		nozzle.material_override = n_mat
		_sky_crane_rig.add_child(nozzle)

		var plume = MeshInstance3D.new()
		var p_cone = CylinderMesh.new()
		p_cone.top_radius = 0.02
		p_cone.bottom_radius = 0.18
		p_cone.height = 0.75
		plume.mesh = p_cone
		plume.position = off + Vector3(0, -0.42, 0)
		plume.material_override = thruster_mat
		_sky_crane_rig.add_child(plume)
		_sky_crane_plumes.append(plume)

	# 3. Bridle cables mesh
	_bridle_cables_mesh = ImmediateMesh.new()
	_bridle_mesh_inst = MeshInstance3D.new()
	_bridle_mesh_inst.mesh = _bridle_cables_mesh
	var c_mat = StandardMaterial3D.new()
	c_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	c_mat.albedo_color = Color(0.95, 0.95, 0.95, 0.92)
	_bridle_mesh_inst.material_override = c_mat
	craft_pivot.add_child(_bridle_mesh_inst)

	# 4. Ground Dust Cloud Mesh
	_landing_dust_cloud = MeshInstance3D.new()
	var d_cyl = CylinderMesh.new()
	d_cyl.top_radius = 1.4
	d_cyl.bottom_radius = 3.4
	d_cyl.height = 0.35
	_landing_dust_cloud.mesh = d_cyl
	_landing_dust_cloud.position = Vector3(0.0, -0.22, 0.0)
	var d_mat = StandardMaterial3D.new()
	d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	d_mat.albedo_color = Color(0.85, 0.45, 0.22, 0.38)
	d_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_landing_dust_cloud.material_override = d_mat
	_landing_dust_cloud.visible = false
	craft_pivot.add_child(_landing_dust_cloud)

func _start_landing_cutscene() -> void:
	if _is_landing_cutscene or _is_sampling_cutscene:
		return

	craft_pivot.position = Vector3.ZERO
	craft_pivot.rotation = Vector3.ZERO
	craft_node.scale = Vector3(1.0, 1.0, 1.0)
	craft_node.rotation = Vector3.ZERO
	_prev_cam_mode_before_cutscene = _current_cam_mode
	_is_landing_cutscene = true
	_landing_elapsed = 0.0
	_has_played_landing_cutscene = true

	var gm = _gm()
	var dest = gm.current_mission.destination if gm != null and gm.current_mission != null else "Mars"
	var is_mars = (dest == "Mars")

	if is_mars:
		_setup_sky_crane_rig()
		if _sky_crane_rig != null:
			_sky_crane_rig.visible = true
			_sky_crane_rig.position = Vector3(0.0, 7.8, 0.0)
			_sky_crane_rig.rotation = Vector3.ZERO
		craft_node.position.y = 5.6
		lbl_cutscene_title.text = "AUTONOMOUS MARS EDL // SKY CRANE DESCENT"
		lbl_cutscene_target.text = "TARGET: JEZERO CRATER DELTA FAN // TERRAIN RELATIVE NAVIGATION (TRN)"
		badge_1.text = "[1. POWERED RETRO-DESCENT]"
		badge_2.text = "[2. SKY CRANE BRIDLE MANEUVER]"
		badge_3.text = "[3. TOUCHDOWN CONFIRMED]"
	else:
		craft_node.position.y = 5.2
		lbl_cutscene_title.text = "AUTONOMOUS LUNAR POLAR POWERED DESCENT"
		lbl_cutscene_target.text = "TARGET: SHACKLETON CRATER CONNECTING RIDGE // OPTICAL HAZARD AVOIDANCE"
		badge_1.text = "[1. POWERED BRAKING BURN]"
		badge_2.text = "[2. TERMINAL VERTICAL DESCENT]"
		badge_3.text = "[3. SOFT TOUCHDOWN CONFIRMED]"

	cutscene_sampling.visible = true
	_set_speed(1.0, btn_1x)

	var am = _am()
	if am != null and am.has_method("play_retro_rocket"):
		am.play_retro_rocket()

func _update_landing_cutscene(delta: float) -> void:
	_landing_elapsed += delta
	var t = _landing_elapsed

	var gm = _gm()
	var dest = gm.current_mission.destination if gm != null and gm.current_mission != null else "Mars"
	var is_mars = (dest == "Mars")

	# REC blink
	lbl_rec.modulate.a = 0.4 + 0.6 * abs(sin(t * 3.5))

	var sol_sec = int(t * 8.0)
	lbl_cutscene_time.text = "EDL T-%02d:%02d" % [max(0, 7 - int(t)), 60 - sol_sec % 60]

	if t < 2.8:
		# ======================================================================
		# STAGE 1: POWERED TERMINAL RETRO-DESCENT (0.0s - 2.8s)
		# ======================================================================
		var st1_t = t / 2.8
		badge_1.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_CYAN)
		badge_2.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
		badge_3.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)

		# Camera: dramatic ground-up perspective looking into the sky
		var cam_start = Vector3(2.8, 0.6, 4.4)
		var cam_end = Vector3(2.2, 0.45, 3.6)
		cam_3d.position = cam_start.lerp(cam_end, ease(st1_t, 0.5))
		cam_3d.look_at(Vector3(0.0, 2.8, 0.0), Vector3.UP)

		if is_mars and _sky_crane_rig != null:
			var sc_y = lerpf(8.2, 3.4, st1_t)
			var rover_y = lerpf(6.4, 1.2, st1_t)
			_sky_crane_rig.position = Vector3(0.0, sc_y, 0.0)
			craft_node.position.y = rover_y

			# Thruster plumes flicker
			for p in _sky_crane_plumes:
				var f = randf_range(0.85, 1.3)
				p.scale = Vector3(f, randf_range(1.0, 1.4), f)

			# Bridle cables
			if _bridle_cables_mesh != null:
				_bridle_cables_mesh.clear_surfaces()
				_bridle_cables_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
				for off in [Vector3(-0.4, 0.0, -0.4), Vector3(0.4, 0.0, -0.4), Vector3(0.0, 0.0, 0.5)]:
					_bridle_cables_mesh.surface_add_vertex(_sky_crane_rig.position + off)
					_bridle_cables_mesh.surface_add_vertex(craft_node.position + off * 0.6)
				_bridle_cables_mesh.surface_end()
		else:
			craft_node.position.y = lerpf(5.2, 1.0, st1_t)
			if _thruster_plume_mesh != null:
				_thruster_plume_mesh.visible = true

		if _landing_dust_cloud != null:
			_landing_dust_cloud.visible = true
			_landing_dust_cloud.scale = Vector3.ONE * (st1_t * 1.4)

		bar_coring.value = st1_t * 35.0
		lbl_coring_status.text = "Descent Rate: -1.8 m/s | Altitude: %.1f m | TRN Terrain Lock: 100%%" % [lerpf(18.0, 4.2, st1_t)]
		reticle_target.text = "[ + ] TACTICAL EDL // SKY CRANE TERMINAL DESCENT\nALTITUDE: %.1f M // VELOCITY: -1.8 M/S\nTERRAIN LOCK: JEZERO DELTA FAN" % [lerpf(18.0, 4.2, st1_t)]

	elif t < 5.4:
		# ======================================================================
		# STAGE 2: SKY CRANE BRIDLE LOWERING (2.8s - 5.4s)
		# ======================================================================
		var st2_t = (t - 2.8) / 2.6
		badge_1.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
		badge_2.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
		badge_3.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)

		# Camera: smooth 3/4 tracking view showing both Sky Crane & descending rover
		var cam_pos = Vector3(-2.6, 0.9, 3.4)
		cam_3d.position = cam_pos
		cam_3d.look_at(Vector3(0.0, 0.5, 0.0), Vector3.UP)

		if is_mars and _sky_crane_rig != null:
			_sky_crane_rig.position = Vector3(0.0, 3.4, 0.0)
			var rover_y = lerpf(1.2, 0.0, st2_t)
			craft_node.position.y = rover_y

			for p in _sky_crane_plumes:
				var f = randf_range(0.8, 1.2)
				p.scale = Vector3(f, randf_range(0.9, 1.25), f)

			if _bridle_cables_mesh != null:
				_bridle_cables_mesh.clear_surfaces()
				_bridle_cables_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
				for off in [Vector3(-0.4, 0.0, -0.4), Vector3(0.4, 0.0, -0.4), Vector3(0.0, 0.0, 0.5)]:
					_bridle_cables_mesh.surface_add_vertex(_sky_crane_rig.position + off)
					_bridle_cables_mesh.surface_add_vertex(craft_node.position + off * 0.6)
				_bridle_cables_mesh.surface_end()
		else:
			craft_node.position.y = lerpf(1.0, 0.0, st2_t)

		bar_coring.value = 35.0 + st2_t * 40.0
		lbl_coring_status.text = "Bridle Lowering: 3 Cords Spooling | Wheels Deploying | Soft Touchdown Imminent"
		reticle_target.text = "[ + ] TACTICAL EDL // SKY CRANE BRIDLE MANEUVER\nWHEEL MOBILITY SUSPENSION: DEPLOYED & LOCKED\nALTITUDE: %.1f M // SENSORS NOMINAL" % [lerpf(4.2, 0.2, st2_t)]

	elif t < LANDING_DURATION:
		# ======================================================================
		# STAGE 3: TOUCHDOWN, CABLE CUT & FLYAWAY (5.4s - 7.5s)
		# ======================================================================
		var st3_t = (t - 5.4) / 2.1
		badge_1.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
		badge_2.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
		badge_3.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_CYAN)

		craft_node.position.y = 0.0 # Solidly on the ground!

		if st3_t < 0.1:
			var am = _am()
			if am != null:
				if am.has_method("play_touchdown"): am.play_touchdown()
				if am.has_method("play_cable_cut"): am.play_cable_cut()

		# Cut cables
		if _bridle_cables_mesh != null:
			_bridle_cables_mesh.clear_surfaces()

		# Sky Crane banks away & rockets over the crater rim!
		if is_mars and _sky_crane_rig != null:
			var fly_dist = st3_t * st3_t
			_sky_crane_rig.position = Vector3(0.0, 3.4 + fly_dist * 26.0, -fly_dist * 55.0)
			_sky_crane_rig.rotation.x = -fly_dist * 0.75
			for p in _sky_crane_plumes:
				p.scale = Vector3(1.5, 2.2, 1.5)
		else:
			if _thruster_plume_mesh != null:
				_thruster_plume_mesh.visible = false

		if _landing_dust_cloud != null:
			_landing_dust_cloud.scale = Vector3.ONE * (1.4 + st3_t * 1.8)
			var mat = _landing_dust_cloud.material_override as StandardMaterial3D
			if mat != null:
				mat.albedo_color.a = max(0.0, 0.38 * (1.0 - st3_t))

		# Camera: Ground eye-level view watching the rover settled on Mars!
		var cam_pos = Vector3(-1.8, 0.35, 2.6)
		cam_3d.position = cam_pos
		cam_3d.look_at(Vector3(0.0, 0.15, 0.0), Vector3.UP)

		bar_coring.value = 100.0
		lbl_coring_status.text = "TOUCHDOWN CONFIRMED // SKY CRANE SEVERED & FLOWN AWAY // 6 WHEELS ON SOIL"
		reticle_target.text = "[ TOUCHDOWN CONFIRMED ] MARS 2020 SKY CRANE COMPLETE\nALL 6 WHEELS FIRMLY ON JEZERO DELTA REGOLITH\nWELCOME TO PLANET MARS // MISSION NOMINAL"

	else:
		_end_landing_cutscene()

func _end_landing_cutscene() -> void:
	if not _is_landing_cutscene:
		return
	_is_landing_cutscene = false
	cutscene_sampling.visible = false
	craft_node.position.y = 0.0
	craft_pivot.position = Vector3.ZERO
	craft_pivot.rotation = Vector3.ZERO

	if _sky_crane_rig != null:
		_sky_crane_rig.visible = false
	if _landing_dust_cloud != null:
		_landing_dust_cloud.visible = false
	if _bridle_cables_mesh != null:
		_bridle_cables_mesh.clear_surfaces()

	var gm = _gm()
	var dest = gm.current_mission.destination if gm != null and gm.current_mission != null else "Mars"
	var site = "Jezero Crater Delta Fan" if dest == "Mars" else "Shackleton Crater Connecting Ridge"

	var ev = MissionEvents.create_event(
		sim_engine.mission_elapsed_days,
		SimulationEngine.PHASE_NAMES[sim_engine.current_phase],
		"Planetary Touchdown Confirmed",
		"Soft landing executed successfully onto the surface terrain of %s! Flight systems 100%% nominal." % site,
		"success"
	)
	sim_engine.events_log.append(ev)
	sim_engine.emit_signal("event_occurred", ev)

	var am = _am()
	if am != null:
		am.play_success()

	_set_cam_mode(CameraMode.SURFACE, btn_cam_surface)

# ==============================================================================
# SURFACE SAMPLE RETRIEVAL CUTSCENE SYSTEM (PERSEVERANCE / CURIOSITY OPERATIONS)
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

	# 1. ImmediateMesh Laser Beam from mast/turret head to rock target
	_laser_beam_mesh = MeshInstance3D.new()
	_laser_mesh = ImmediateMesh.new()
	_laser_beam_mesh.mesh = _laser_mesh
	var l_mat = StandardMaterial3D.new()
	l_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	l_mat.albedo_color = Color(1.0, 0.22, 0.28, 0.95) if is_mars else Color(0.1, 0.95, 1.0, 0.95)
	l_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_beam_mesh.material_override = l_mat
	_sampling_rig.add_child(_laser_beam_mesh)

	# 2. Laser Impact Glow Disk on Rock Surface
	_laser_impact_mesh = MeshInstance3D.new()
	var imp = SphereMesh.new()
	imp.radius = 0.045
	imp.height = 0.018
	_laser_impact_mesh.mesh = imp
	_laser_impact_mesh.position = Vector3(-0.23, -0.30, 0.95)
	var imp_mat = StandardMaterial3D.new()
	imp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	imp_mat.albedo_color = Color(1.0, 0.9, 0.5, 0.9)
	imp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_impact_mesh.material_override = imp_mat
	_laser_impact_mesh.visible = false
	_sampling_rig.add_child(_laser_impact_mesh)

	if _surface_env != null:
		_borehole_mesh = _surface_env.get_borehole_mesh()

func _start_sampling_cutscene() -> void:
	if _is_sampling_cutscene or _is_landing_cutscene:
		return

	# Align spacecraft/rover orientation forward so the cutscene is always centered & framed
	craft_pivot.position = Vector3.ZERO
	craft_pivot.rotation = Vector3.ZERO
	craft_node.scale = Vector3(1.0, 1.0, 1.0)
	craft_node.rotation = Vector3.ZERO

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
		lbl_cutscene_title.text = "AUTONOMOUS MARS ROVER SAMPLE CACHING // SOL 42"
		lbl_cutscene_target.text = "TARGET: JEZERO CRATER DELTA // LACUSTRINE SEDIMENTARY BEDROCK"
		badge_1.text = "[1. MASTCAM TARGET RECON]"
		badge_2.text = "[2. SUPERCAM LASER ABLATION]"
		badge_3.text = "[3. PERCUSSIVE CORING]"
	else:
		lbl_cutscene_title.text = "AUTONOMOUS LUNAR POLAR CORE EXTRACTION"
		lbl_cutscene_target.text = "TARGET: SHACKLETON CRATER // PERMANENTLY SHADOWED REGION (PSR)"
		badge_1.text = "[1. INFRARED THERMAL SCAN]"
		badge_2.text = "[2. CRYO REGOLITH CORING]"
		badge_3.text = "[3. VOLATILE CHAMBER SEAL]"

	cutscene_sampling.visible = true
	_set_speed(1.0, btn_1x)

	var am = _am()
	if am != null and am.has_method("play_servo"):
		am.play_servo()

func _update_sampling_cutscene(delta: float) -> void:
	_sampling_elapsed += delta
	var t = _sampling_elapsed

	var gm = _gm()
	var dest = gm.current_mission.destination if gm != null and gm.current_mission != null else "Mars"
	var is_mars = (dest == "Mars")

	# Animate REC indicator blink
	lbl_rec.modulate.a = 0.4 + 0.6 * abs(sin(t * 3.5))

	var sol_sec = int(t * 12.0)
	lbl_cutscene_time.text = "SOL %d // T+00:%02d:%02d" % [42 if is_mars else 14, sol_sec / 60, sol_sec % 60]

	# Target contact coordinate on rock
	var rock_target = Vector3(-0.23, -0.30, 0.95)
	var laser_origin = Vector3(0.24, 0.80, 0.35) if is_mars else Vector3(-0.23, 0.25, 0.70)

	if t < 3.2:
		# ======================================================================
		# STAGE 1: MASTCAM-Z / SUPERCAM TARGET RECONNAISSANCE (0.0s - 3.2s)
		# ======================================================================
		var st1_t = t / 3.2
		badge_1.text = "[1. MASTCAM TARGET RECON]"
		badge_2.text = "[2. SUPERCAM LASER ABLATION]"
		badge_3.text = "[3. PERCUSSIVE CORING]"
		badge_1.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_CYAN)
		badge_2.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
		badge_3.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)

		# Camera: Dynamic wide 3/4 perspective framing rover and target bedrock
		var cam_start = Vector3(-2.8, 1.3, 3.6)
		var cam_end = Vector3(-2.0, 0.95, 2.6)
		cam_3d.position = cam_start.lerp(cam_end, ease(st1_t, 0.5))
		cam_3d.look_at(Vector3(-0.15, 0.15, 0.6), Vector3.UP)

		# Rotate Remote Sensing Mast head to scan the bedrock
		var mast_node = _craft_preview_builder.get_component_node("inst_mastcam_stereo") if _craft_preview_builder else null
		if mast_node == null and _craft_preview_builder:
			mast_node = _craft_preview_builder.get_component_node("inst_mastcam_z")
		if mast_node != null:
			mast_node.rotation.y = sin(t * 2.5) * 0.42
			mast_node.rotation.x = -0.12

		bar_coring.value = st1_t * 20.0
		lbl_coring_status.text = "Mastcam-Z Stereo Scan: Multi-spectral imaging at 440nm & 670nm | Target locked"
		reticle_target.text = "[ + ] TACTICAL HUD // MASTCAM-Z TARGET RECON\nAZIMUTH: 042.4° // ELEVATION: -16.8° // DIST: 1.82 M\nTARGET: LACUSTRINE SEDIMENTARY BEDROCK (CLAYSTONE)"

	elif t < 6.5:
		# ======================================================================
		# STAGE 2: SUPERCAM LASER ABLATION (LIBS SPECTROSCOPY) (3.2s - 6.5s)
		# ======================================================================
		var st2_t = (t - 3.2) / 3.3
		badge_1.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
		badge_2.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_CYAN)
		badge_3.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)

		var cam_start = Vector3(-2.0, 0.95, 2.6)
		var cam_end = Vector3(-1.45, 0.65, 1.95)
		cam_3d.position = cam_start.lerp(cam_end, ease(st2_t, 0.5))
		cam_3d.look_at(Vector3(-0.23, -0.10, 0.92), Vector3.UP)

		# Pulsed optical laser beam
		var laser_flicker = sin(t * 28.0) > 0.0
		if _laser_mesh != null:
			_laser_mesh.clear_surfaces()
			if laser_flicker:
				_laser_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
				_laser_mesh.surface_add_vertex(laser_origin)
				_laser_mesh.surface_add_vertex(rock_target)
				_laser_mesh.surface_end()

		if _laser_impact_mesh != null:
			_laser_impact_mesh.visible = laser_flicker
			if laser_flicker:
				_laser_impact_mesh.scale = Vector3.ONE * randf_range(0.8, 1.8)

		# Laser audio pulse
		_audio_laser_cooldown -= delta
		if _audio_laser_cooldown <= 0.0:
			_audio_laser_cooldown = 0.22
			var am = _am()
			if am != null and am.has_method("play_laser"):
				am.play_laser()

		bar_coring.value = 20.0 + st2_t * 25.0
		lbl_coring_status.text = "SuperCam LIBS: 30 Hz optical pulses vaporizing dust | Minerals: Fe/Mg smectite & carbonates"
		reticle_target.text = "[ + ] TACTICAL HUD // SUPERCAM LASER ABLATION\n30 Hz PULSED LASER // SURFACE DUST VAPORIZED\nMINERALS: Fe-SMECTITE CLAY | Mg-CARBONATE | ORGANICS DETECTED"

	elif t < 10.0:
		# ======================================================================
		# STAGE 3: 5-JOINT ROBOTIC ARM CORING DRILL (6.5s - 10.0s)
		# ======================================================================
		var st3_t = (t - 6.5) / 3.5
		badge_1.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
		badge_2.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
		badge_3.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)

		if _laser_mesh != null:
			_laser_mesh.clear_surfaces()
		if _laser_impact_mesh != null:
			_laser_impact_mesh.visible = false

		# Profile perspective framing arm, coring turret, and bedrock
		var cam_pos = Vector3(-1.45, 0.65, 1.95)
		var cam_shake = Vector3(randf_range(-0.003, 0.003), randf_range(-0.003, 0.003), randf_range(-0.002, 0.002))
		cam_3d.position = cam_pos + cam_shake
		cam_3d.look_at(Vector3(-0.23, -0.10, 0.92), Vector3.UP)

		# Deepen borehole cylinder mesh
		var cur_depth_cm = lerpf(0.0, 12.0, st3_t)
		if _borehole_mesh != null:
			_borehole_mesh.scale.y = 1.0 + st3_t * 3.8

		# Vibrate the drill arm turret
		var drill_wrapper = _craft_preview_builder.get_component_node("inst_mars_drill") if _craft_preview_builder else null
		if drill_wrapper == null and _craft_preview_builder:
			drill_wrapper = _craft_preview_builder.get_component_node("inst_lunar_drill")
		if drill_wrapper != null:
			drill_wrapper.position.y = 0.445 + randf_range(-0.004, 0.004)

		# Drill motor audio pulse
		_audio_drill_cooldown -= delta
		if _audio_drill_cooldown <= 0.0:
			_audio_drill_cooldown = 0.20
			var am = _am()
			if am != null and am.has_method("play_drill"):
				am.play_drill()

		bar_coring.value = 45.0 + st3_t * 35.0
		lbl_coring_status.text = "Rotary-Percussive Coring: %.1f cm / 12.0 cm | Rate: 2,400 BPM | Bit Temp: %.0f°C" % [
			cur_depth_cm, 35.0 + st3_t * 22.0
		]
		reticle_target.text = "[ + ] TACTICAL HUD // ROTARY-PERCUSSIVE CORING\n2,400 BLOWS/MIN // CORING DEPTH: %.1f CM\nSTATUS: EXTRACTING ROCK CORE INTO TITANIUM TUBE #01" % cur_depth_cm

	elif t < 12.8:
		# ======================================================================
		# STAGE 4: ADAPTIVE CACHING HERMETIC SEALING (10.0s - 12.8s)
		# ======================================================================
		var st4_t = (t - 10.0) / 2.8
		badge_1.text = "[4. HERMETIC SEALING]"
		badge_2.text = "[5. AUTONOMOUS TRAVERSE]"
		badge_3.text = "[3. PERCUSSIVE CORING]"
		badge_3.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
		badge_1.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_CYAN)
		badge_2.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)

		# Reset arm vibration
		var drill_wrapper = _craft_preview_builder.get_component_node("inst_mars_drill") if _craft_preview_builder else null
		if drill_wrapper == null and _craft_preview_builder:
			drill_wrapper = _craft_preview_builder.get_component_node("inst_lunar_drill")
		if drill_wrapper != null:
			drill_wrapper.position.y = 0.445

		# Elevated 3/4 camera pulling back towards rover belly carousel
		var cam_pos = Vector3(-1.8, 1.15, 2.4)
		cam_3d.position = cam_pos
		cam_3d.look_at(Vector3(-0.15, 0.25, 0.6), Vector3.UP)

		# Flash seal ring on carousel
		if _laser_impact_mesh != null:
			_laser_impact_mesh.visible = (st4_t < 0.4)
			_laser_impact_mesh.position = Vector3(-0.25, 0.42, 0.52)

		var am = _am()
		if st4_t < 0.1 and am != null and am.has_method("play_seal"):
			am.play_seal()

		bar_coring.value = 80.0 + st4_t * 15.0
		lbl_coring_status.text = "Hermetic Titanium Expansion Seal: 100% Locked | Sample cached in carousel slot #01"
		reticle_target.text = "[ OK ] TACTICAL HUD // ADAPTIVE CACHING ASSEMBLY\nSAMPLE TUBE #01: HERMETICALLY SEALED\nCACHED IN BELLY CAROUSEL RACK // PRESERVED FOR RETURN"

	elif t < SAMPLING_DURATION:
		# ======================================================================
		# STAGE 5: AUTONOMOUS MOBILITY TRAVERSE ACROSS MARS (12.8s - 16.0s)
		# ======================================================================
		var st5_t = (t - 12.8) / 3.2
		badge_1.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
		badge_2.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_CYAN)

		if _laser_impact_mesh != null:
			_laser_impact_mesh.visible = false

		# Rover drives smoothly forward across Martian soil!
		craft_pivot.position.z += delta * 0.40

		# Camera: Sweeping cinematic dolly tracking alongside the moving rover with Jezero rim in view
		var cam_track_pos = craft_pivot.position + Vector3(2.6, 1.1, 2.8)
		cam_3d.position = cam_track_pos
		cam_3d.look_at(craft_pivot.position + Vector3(0.0, 0.25, 0.5), Vector3.UP)

		bar_coring.value = 95.0 + st5_t * 5.0
		lbl_coring_status.text = "Autonomous Traverse: 6 Cleated Aluminum Wheels Active | Speed: 0.12 km/h | Heading: 045°"
		reticle_target.text = "[ TRAVERSE ACTIVE ] AUTONOMOUS WAYPOINT NAVIGATION\nHEADING: 045° // SPEED: 0.12 KM/H // ALL 6 WHEELS NOMINAL\nPRIMARY SCIENCE TARGET REACHED // +35 MB TELEMETRY ARCHIVED"

	else:
		_end_sampling_cutscene()

func _end_sampling_cutscene() -> void:
	if not _is_sampling_cutscene:
		return
	_is_sampling_cutscene = false
	cutscene_sampling.visible = false
	if _sampling_rig != null:
		_sampling_rig.visible = false

	# Reset arm & mast position
	if _craft_preview_builder != null:
		var drill_wrapper = _craft_preview_builder.get_component_node("inst_mars_drill")
		if drill_wrapper == null:
			drill_wrapper = _craft_preview_builder.get_component_node("inst_lunar_drill")
		if drill_wrapper != null:
			drill_wrapper.position.y = 0.445

		var mast_node = _craft_preview_builder.get_component_node("inst_mastcam_stereo")
		if mast_node == null:
			mast_node = _craft_preview_builder.get_component_node("inst_mastcam_z")
		if mast_node != null:
			mast_node.rotation = Vector3.ZERO

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
		"%s hermetically sealed in %s! Rover traversed into delta fan (+35 MB science buffered)." % [sample_name, container_name],
		"success"
	)
	sim_engine.events_log.append(ev)
	sim_engine.emit_signal("event_occurred", ev)

	var am = _am()
	if am != null:
		am.play_success()

	_set_cam_mode(_prev_cam_mode_before_cutscene, btn_cam_surface)
