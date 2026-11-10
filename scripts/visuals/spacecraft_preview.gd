class_name SpacecraftPreview
extends Node3D

# SpacecraftPreview
# Dynamically constructs and updates a modular 3D spacecraft model
# representing the player's selected components in real-time.

@export var auto_rotate: bool = true
@export var rotate_speed: float = 0.4

var _root_node: Node3D
var _orbit_cam: Camera3D
var _cam_pivot: Node3D
var _cam_distance: float = 3.5
var _is_dragging: bool = false
var _drag_prev_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_cam_pivot = Node3D.new()
	add_child(_cam_pivot)

	_orbit_cam = Camera3D.new()
	_cam_pivot.add_child(_orbit_cam)
	_orbit_cam.position = Vector3(0, 0.8, _cam_distance)
	_orbit_cam.look_at(Vector3.ZERO, Vector3.UP)

	_root_node = Node3D.new()
	add_child(_root_node)

	# Initial build if spacecraft is set in GameManager
	if GameManager != null and GameManager.current_spacecraft != null:
		rebuild_spacecraft(GameManager.current_spacecraft)

func _process(delta: float) -> void:
	if auto_rotate and not _is_dragging:
		_cam_pivot.rotate_y(rotate_speed * delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			_drag_prev_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_distance = clamp(_cam_distance - 0.25, 1.5, 8.0)
			_orbit_cam.position.z = _cam_distance
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_distance = clamp(_cam_distance + 0.25, 1.5, 8.0)
			_orbit_cam.position.z = _cam_distance

	elif event is InputEventMouseMotion and _is_dragging:
		var delta_pos = event.position - _drag_prev_pos
		_drag_prev_pos = event.position
		_cam_pivot.rotate_y(-delta_pos.x * 0.008)
		_orbit_cam.rotation.x = clamp(_orbit_cam.rotation.x - delta_pos.y * 0.008, -PI/2.5, PI/2.5)

func rebuild_spacecraft(spacecraft: SpacecraftConfig) -> void:
	for c in _root_node.get_children():
		c.queue_free()

	if spacecraft == null or spacecraft.selected_components.is_empty():
		_build_fallback_bus()
		return

	# 1. Primary Chassis/Bus
	var is_rover = spacecraft.has_component("chassis_mars_rover")
	if is_rover:
		_build_rover_chassis()
	elif spacecraft.has_component("bus_deep_space"):
		_build_deep_space_bus()
	else:
		_build_standard_sat_bus()

	# 2. Components
	for comp in spacecraft.selected_components:
		match comp.visual_type:
			"solar_array_dual":
				_build_dual_solar_wings()
			"solar_panel_fixed":
				_build_fixed_solar_panels()
			"rtg_generator":
				_build_rtg_generator()
			"antenna_dish":
				_build_parabolic_dish()
			"antenna_horn":
				_build_horn_antenna()
			"antenna_omni":
				_build_omni_antenna()
			"camera_mast":
				_build_camera_mast()
			"sensor_imager":
				_build_imager_aperture()
			"radar_dish":
				_build_sar_radar_panel()
			"drill_arm", "robotic_arm_drill":
				_build_drill_arm()
			"seismometer":
				_build_seismometer()
			"thruster_main":
				_build_main_engine()
			"thruster_ion":
				_build_ion_engine()
			"thruster_rcs":
				_build_rcs_blocks()
			"landing_gear_lunar":
				_build_lunar_landing_gear()
			"heat_shield_aeroshell":
				_build_aeroshell_capsule()
			"skycrane_stage":
				_build_skycrane_stage()
			"battery_pack":
				_build_battery_pack()
			"avionics_computer":
				_build_avionics_box()

# --- Procedural Mesh Helpers ---

func _build_fallback_bus() -> void:
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.8, 0.8, 0.8)
	mi.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.7, 0.2) # Kapton Gold
	mat.metallic = 0.85
	mat.roughness = 0.2
	mi.material_override = mat
	_root_node.add_child(mi)

func _build_standard_sat_bus() -> void:
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.9, 0.9, 1.1)
	mi.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.75, 0.2) # Kapton Gold Foil
	mat.metallic = 0.9
	mat.roughness = 0.25
	mi.material_override = mat
	_root_node.add_child(mi)

func _build_deep_space_bus() -> void:
	var mi = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.6
	cyl.height = 1.2
	cyl.radial_segments = 8 # Octagonal probe bus
	mi.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.88, 0.9) # Titanium / Silver MLI
	mat.metallic = 0.92
	mat.roughness = 0.18
	mi.material_override = mat
	_root_node.add_child(mi)

func _build_rover_chassis() -> void:
	# Main body
	var body = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(0.9, 0.45, 1.3)
	body.mesh = b_mesh
	body.position = Vector3(0, 0.2, 0)
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.95, 0.95, 0.95)
	body_mat.metallic = 0.3
	body_mat.roughness = 0.4
	body.material_override = body_mat
	_root_node.add_child(body)

	# 6 Rocker-Bogie Wheels
	var wheel_offsets = [
		Vector3(-0.6, -0.15, 0.5), Vector3(0.6, -0.15, 0.5),
		Vector3(-0.65, -0.15, 0.0), Vector3(0.65, -0.15, 0.0),
		Vector3(-0.6, -0.15, -0.5), Vector3(0.6, -0.15, -0.5)
	]
	var w_mat = StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.18, 0.18, 0.18)
	w_mat.metallic = 0.8
	w_mat.roughness = 0.5

	for pos in wheel_offsets:
		var wheel = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.18
		cyl.bottom_radius = 0.18
		cyl.height = 0.15
		wheel.mesh = cyl
		wheel.rotation.z = PI / 2.0
		wheel.position = pos
		wheel.material_override = w_mat
		_root_node.add_child(wheel)

func _build_dual_solar_wings() -> void:
	var wing_mat = StandardMaterial3D.new()
	wing_mat.albedo_color = Color(0.08, 0.18, 0.45) # Solar Cell Blue
	wing_mat.metallic = 0.6
	wing_mat.roughness = 0.15

	for side in [-1.0, 1.0]:
		var wing = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(1.2, 0.02, 0.5)
		wing.mesh = box
		wing.position = Vector3(side * 1.15, 0.1, 0.0)
		wing.material_override = wing_mat
		_root_node.add_child(wing)

		# Support boom
		var boom = MeshInstance3D.new()
		var b_cyl = CylinderMesh.new()
		b_cyl.top_radius = 0.03
		b_cyl.bottom_radius = 0.03
		b_cyl.height = 0.55
		boom.mesh = b_cyl
		boom.rotation.z = PI / 2.0
		boom.position = Vector3(side * 0.65, 0.1, 0.0)
		_root_node.add_child(boom)

func _build_fixed_solar_panels() -> void:
	var wing_mat = StandardMaterial3D.new()
	wing_mat.albedo_color = Color(0.06, 0.14, 0.38)
	wing_mat.metallic = 0.7
	wing_mat.roughness = 0.2

	for side in [-1.0, 1.0]:
		var panel = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.02, 0.7, 0.9)
		panel.mesh = box
		panel.position = Vector3(side * 0.47, 0.0, 0.0)
		panel.material_override = wing_mat
		_root_node.add_child(panel)

func _build_rtg_generator() -> void:
	var rtg = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.14
	cyl.bottom_radius = 0.14
	cyl.height = 0.5
	rtg.mesh = cyl
	rtg.position = Vector3(0.0, 0.15, -0.7)
	rtg.rotation.x = PI / 2.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.2)
	mat.roughness = 0.4
	mat.metallic = 0.8
	rtg.material_override = mat
	_root_node.add_child(rtg)

func _build_parabolic_dish() -> void:
	var dish = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.15
	sphere.radial_segments = 32
	dish.mesh = sphere
	dish.position = Vector3(0.0, 0.65, 0.1)
	dish.rotation.x = -PI / 3.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.93, 0.95)
	mat.metallic = 0.5
	mat.roughness = 0.25
	dish.material_override = mat
	_root_node.add_child(dish)

func _build_horn_antenna() -> void:
	var horn = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.12
	cone.bottom_radius = 0.02
	cone.height = 0.3
	horn.mesh = cone
	horn.position = Vector3(0.3, 0.58, 0.3)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.7, 0.75)
	mat.metallic = 0.8
	horn.material_override = mat
	_root_node.add_child(horn)

func _build_omni_antenna() -> void:
	var omni = MeshInstance3D.new()
	var whip = CylinderMesh.new()
	whip.top_radius = 0.015
	whip.bottom_radius = 0.02
	whip.height = 0.6
	omni.mesh = whip
	omni.position = Vector3(-0.35, 0.7, -0.35)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.9)
	mat.metallic = 0.9
	omni.material_override = mat
	_root_node.add_child(omni)

func _build_camera_mast() -> void:
	var mast = MeshInstance3D.new()
	var pole = CylinderMesh.new()
	pole.top_radius = 0.03
	pole.bottom_radius = 0.04
	pole.height = 0.7
	mast.mesh = pole
	mast.position = Vector3(0.2, 0.65, 0.35)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.85)
	mast.material_override = mat
	_root_node.add_child(mast)

	# Camera head
	var head = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.22, 0.12, 0.15)
	head.mesh = box
	head.position = Vector3(0.2, 1.0, 0.35)
	_root_node.add_child(head)

func _build_imager_aperture() -> void:
	var imager = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 0.3
	imager.mesh = cyl
	imager.position = Vector3(0.0, -0.5, 0.0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.15)
	mat.metallic = 0.9
	imager.material_override = mat
	_root_node.add_child(imager)

func _build_sar_radar_panel() -> void:
	var radar = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.6, 0.02, 0.4)
	radar.mesh = box
	radar.position = Vector3(0.0, -0.55, 0.0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.85, 0.3)
	mat.metallic = 0.8
	radar.material_override = mat
	_root_node.add_child(radar)

func _build_drill_arm() -> void:
	var arm = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.035
	cyl.height = 0.55
	arm.mesh = cyl
	arm.position = Vector3(0.35, 0.0, 0.75)
	arm.rotation.x = PI / 4.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.4)
	mat.metallic = 0.9
	arm.material_override = mat
	_root_node.add_child(arm)

func _build_seismometer() -> void:
	var dome = MeshInstance3D.new()
	var sp = SphereMesh.new()
	sp.radius = 0.12
	sp.height = 0.12
	dome.mesh = sp
	dome.position = Vector3(-0.35, 0.3, 0.4)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.6, 0.1)
	dome.material_override = mat
	_root_node.add_child(dome)

func _build_main_engine() -> void:
	var eng = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.08
	cone.bottom_radius = 0.22
	cone.height = 0.4
	eng.mesh = cone
	eng.position = Vector3(0.0, 0.0, -0.65)
	eng.rotation.x = PI / 2.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.22, 0.15) # Niobium rocket nozzle
	mat.metallic = 0.95
	mat.roughness = 0.3
	eng.material_override = mat
	_root_node.add_child(eng)

func _build_ion_engine() -> void:
	var eng = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.16
	cyl.height = 0.25
	eng.mesh = cyl
	eng.position = Vector3(0.0, 0.0, -0.65)
	eng.rotation.x = PI / 2.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.8, 1.0) # Glowing Xenon blue
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.7, 1.0)
	mat.emission_energy_multiplier = 2.0
	eng.material_override = mat
	_root_node.add_child(eng)

func _build_rcs_blocks() -> void:
	var corners = [
		Vector3(-0.48, 0.4, 0.48), Vector3(0.48, 0.4, 0.48),
		Vector3(-0.48, 0.4, -0.48), Vector3(0.48, 0.4, -0.48)
	]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.7, 0.2)
	mat.metallic = 0.9

	for pos in corners:
		var rcs = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.08, 0.08, 0.08)
		rcs.mesh = box
		rcs.position = pos
		rcs.material_override = mat
		_root_node.add_child(rcs)

func _build_lunar_landing_gear() -> void:
	var leg_mat = StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.9, 0.78, 0.22) # Apollo Gold foil MLI
	leg_mat.metallic = 0.92
	leg_mat.roughness = 0.25

	var pad_mat = StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.75, 0.78, 0.82) # Titanium / Inconel crushable pad
	pad_mat.metallic = 0.95
	pad_mat.roughness = 0.3

	var leg_angles = [PI / 4.0, 3.0 * PI / 4.0, 5.0 * PI / 4.0, 7.0 * PI / 4.0]
	for ang in leg_angles:
		var dir_x = cos(ang)
		var dir_z = sin(ang)

		# Upper chassis mounting bracket on body
		var start_pos = Vector3(dir_x * 0.44, -0.32, dir_z * 0.44)
		# Outer landing footpad position (splayed OUTWARD and DOWNWARD)
		var foot_pos = Vector3(dir_x * 0.95, -0.78, dir_z * 0.95)
		var dist = start_pos.distance_to(foot_pos)

		# Main landing gear strut (points directly from body outward-downward to footpad)
		var mount = Node3D.new()
		_root_node.add_child(mount)
		mount.position = start_pos
		mount.look_at(foot_pos, Vector3.UP)

		var strut = MeshInstance3D.new()
		var s_cyl = CylinderMesh.new()
		s_cyl.top_radius = 0.028
		s_cyl.bottom_radius = 0.028
		s_cyl.height = dist
		strut.mesh = s_cyl
		strut.position = Vector3(0.0, 0.0, -dist * 0.5)
		strut.rotation.x = PI / 2.0
		strut.material_override = leg_mat
		mount.add_child(strut)

		# Diagonal A-frame brace from lower bus
		var brace_start = Vector3(dir_x * 0.32, -0.48, dir_z * 0.32)
		var brace_mid = start_pos.lerp(foot_pos, 0.6)
		var brace_dist = brace_start.distance_to(brace_mid)

		var brace_mount = Node3D.new()
		_root_node.add_child(brace_mount)
		brace_mount.position = brace_start
		brace_mount.look_at(brace_mid, Vector3.UP)

		var brace_strut = MeshInstance3D.new()
		var b_cyl = CylinderMesh.new()
		b_cyl.top_radius = 0.016
		b_cyl.bottom_radius = 0.016
		b_cyl.height = brace_dist
		brace_strut.mesh = b_cyl
		brace_strut.position = Vector3(0.0, 0.0, -brace_dist * 0.5)
		brace_strut.rotation.x = PI / 2.0
		brace_strut.material_override = leg_mat
		brace_mount.add_child(brace_strut)

		# Wide Footpad at the base (flat on the lunar regolith ground)
		var pad = MeshInstance3D.new()
		var p_cyl = CylinderMesh.new()
		p_cyl.top_radius = 0.13
		p_cyl.bottom_radius = 0.15
		p_cyl.height = 0.025
		pad.mesh = p_cyl
		pad.position = foot_pos
		pad.material_override = pad_mat
		_root_node.add_child(pad)

func _build_aeroshell_capsule() -> void:
	var shield = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.8
	cone.bottom_radius = 0.05
	cone.height = 0.35
	shield.mesh = cone
	shield.position = Vector3(0.0, -0.4, 0.0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.15, 0.12) # Carbon PICA tile
	mat.roughness = 0.9
	shield.material_override = mat
	_root_node.add_child(shield)

func _build_skycrane_stage() -> void:
	var crane = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.1, 0.15, 1.1)
	crane.mesh = box
	crane.position = Vector3(0.0, 0.55, 0.0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.72, 0.75)
	mat.metallic = 0.85
	crane.material_override = mat
	_root_node.add_child(crane)

func _build_battery_pack() -> void:
	var bat = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.25, 0.25, 0.35)
	bat.mesh = box
	bat.position = Vector3(-0.35, -0.2, -0.2)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.45, 0.8) # Battery blue
	bat.material_override = mat
	_root_node.add_child(bat)

func _build_avionics_box() -> void:
	var avi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.28, 0.18, 0.28)
	avi.mesh = box
	avi.position = Vector3(0.3, -0.2, -0.2)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.35)
	avi.material_override = mat
	_root_node.add_child(avi)
