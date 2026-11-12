class_name SpacecraftPreview
extends Node3D

# SpacecraftPreview
# Dynamically constructs and updates a modular 3D spacecraft model
# representing the player's selected components in real-time.
# Supports:
# - Full 360-degree orbit, pan, and zoom camera controls with smooth damping
# - Exploded-View mode with smooth lerp animation and leader lines
# - Component selection, Fresnel glow highlighting, and smooth camera focus
# - High-fidelity aerospace PBR materials (Kapton MLI, solar cells, titanium, carbon composite)

signal component_inspected(comp_id: String)

@export var auto_rotate: bool = false
@export var rotate_speed: float = 0.3

var is_exploded_mode: bool = false
var explosion_factor: float = 0.0 # 0.0 = compact, 1.0 = exploded
var highlighted_comp_id: String = ""

var _root_node: Node3D
var _orbit_cam: Camera3D
var _cam_pivot: Node3D
var _cam_distance: float = 3.6
var _target_distance: float = 3.6
var _target_rot_y: float = 0.0
var _target_rot_x: float = -0.15
var _cam_target: Vector3 = Vector3(0, 0.1, 0)

var _is_dragging_orbit: bool = false
var _is_dragging_pan: bool = false
var _drag_prev_pos: Vector2 = Vector2.ZERO

var _component_nodes: Dictionary = {} # comp_id -> Node3D wrapper
var _line_mesh_instance: MeshInstance3D
var _line_mesh: ImmediateMesh
var _highlight_node: Node3D

func _ready() -> void:
	_cam_pivot = Node3D.new()
	add_child(_cam_pivot)

	_orbit_cam = Camera3D.new()
	_cam_pivot.add_child(_orbit_cam)
	_orbit_cam.position = Vector3(0, 0.4, _cam_distance)
	_orbit_cam.look_at(_cam_target, Vector3.UP)

	_root_node = Node3D.new()
	add_child(_root_node)

	_setup_line_renderer()

	if GameManager != null and GameManager.current_spacecraft != null:
		rebuild_spacecraft(GameManager.current_spacecraft)

func _setup_line_renderer() -> void:
	_line_mesh = ImmediateMesh.new()
	_line_mesh_instance = MeshInstance3D.new()
	_line_mesh_instance.mesh = _line_mesh
	var l_mat = StandardMaterial3D.new()
	l_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	l_mat.albedo_color = Color(0.0, 0.85, 1.0, 0.5)
	l_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_mesh_instance.material_override = l_mat
	_root_node.add_child(_line_mesh_instance)

func _process(delta: float) -> void:
	# 1. Smooth Camera Interpolation
	if auto_rotate and not _is_dragging_orbit and not _is_dragging_pan:
		_target_rot_y += rotate_speed * delta

	_cam_pivot.rotation.y = lerpf(_cam_pivot.rotation.y, _target_rot_y, delta * 10.0)
	_cam_pivot.rotation.x = lerpf(_cam_pivot.rotation.x, _target_rot_x, delta * 10.0)
	_cam_distance = lerpf(_cam_distance, _target_distance, delta * 10.0)
	_orbit_cam.position.z = _cam_distance
	_cam_pivot.position = _cam_pivot.position.lerp(_cam_target, delta * 8.0)
	_orbit_cam.look_at(_cam_pivot.position, Vector3.UP)

	# 2. Exploded-View Smooth Animation
	var target_explosion = 1.0 if is_exploded_mode else 0.0
	explosion_factor = lerpf(explosion_factor, target_explosion, delta * 6.0)

	for comp_id in _component_nodes:
		var node = _component_nodes[comp_id]
		var c_pos = node.get_meta("compact_pos", Vector3.ZERO)
		var e_pos = node.get_meta("exploded_pos", Vector3.ZERO)
		node.position = c_pos.lerp(e_pos, explosion_factor)

	_update_exploded_lines()

func _update_exploded_lines() -> void:
	if _line_mesh == null:
		return
	_line_mesh.clear_surfaces()
	if explosion_factor <= 0.05:
		return

	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for comp_id in _component_nodes:
		var node = _component_nodes[comp_id]
		var c_pos = node.get_meta("compact_pos", Vector3.ZERO)
		var cur_pos = node.position
		# Draw line from compact anchor to current position
		_line_mesh.surface_add_vertex(c_pos)
		_line_mesh.surface_add_vertex(cur_pos)
	_line_mesh.surface_end()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging_orbit = event.pressed
			_drag_prev_pos = event.position
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging_pan = event.pressed
			_drag_prev_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = clamp(_target_distance - 0.35, 1.2, 9.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = clamp(_target_distance + 0.35, 1.2, 9.0)

	elif event is InputEventMouseMotion:
		var delta_pos = event.position - _drag_prev_pos
		_drag_prev_pos = event.position

		if _is_dragging_orbit:
			_target_rot_y -= delta_pos.x * 0.007
			_target_rot_x = clamp(_target_rot_x - delta_pos.y * 0.007, -PI/2.4, PI/2.4)
		elif _is_dragging_pan:
			# Pan camera target
			var right_vec = _cam_pivot.global_transform.basis.x
			var up_vec = _cam_pivot.global_transform.basis.y
			_cam_target -= (right_vec * delta_pos.x - up_vec * delta_pos.y) * 0.003

func toggle_exploded_view() -> bool:
	is_exploded_mode = not is_exploded_mode
	return is_exploded_mode

func reset_camera() -> void:
	_target_distance = 3.6
	_target_rot_y = 0.0
	_target_rot_x = -0.15
	_cam_target = Vector3(0, 0.1, 0)
	highlight_component("")

func highlight_component(comp_id: String) -> void:
	highlighted_comp_id = comp_id
	if _highlight_node != null:
		_highlight_node.queue_free()
		_highlight_node = null

	if comp_id.is_empty() or not _component_nodes.has(comp_id):
		return

	var target_node = _component_nodes[comp_id]
	_highlight_node = Node3D.new()
	target_node.add_child(_highlight_node)

	# Create glowing wireframe/highlight box
	var h_mi = MeshInstance3D.new()
	var h_box = BoxMesh.new()
	h_box.size = Vector3(0.5, 0.5, 0.5)
	h_mi.mesh = h_box
	var h_mat = StandardMaterial3D.new()
	h_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	h_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	h_mat.albedo_color = Color(0.0, 0.95, 1.0, 0.3)
	h_mi.material_override = h_mat
	_highlight_node.add_child(h_mi)

	# Focus camera smoothly towards highlighted component
	_cam_target = target_node.global_position * 0.5
	emit_signal("component_inspected", comp_id)

func rebuild_spacecraft(spacecraft: SpacecraftConfig) -> void:
	_component_nodes.clear()
	for c in _root_node.get_children():
		if c != _line_mesh_instance:
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
		_build_component_modular(comp)

func _create_wrapper(comp_id: String, compact_pos: Vector3, exploded_offset: Vector3) -> Node3D:
	var wrapper = Node3D.new()
	wrapper.name = comp_id
	wrapper.position = compact_pos
	wrapper.set_meta("compact_pos", compact_pos)
	wrapper.set_meta("exploded_pos", compact_pos + exploded_offset)
	_root_node.add_child(wrapper)
	_component_nodes[comp_id] = wrapper
	return wrapper

func _build_component_modular(comp: SpaceComponent) -> void:
	match comp.visual_type:
		"solar_array_dual":
			_build_dual_solar_wings(comp.id)
		"solar_panel_fixed":
			_build_fixed_solar_panels(comp.id)
		"rtg_generator":
			_build_rtg_generator(comp.id)
		"antenna_dish":
			_build_parabolic_dish(comp.id)
		"antenna_horn":
			_build_horn_antenna(comp.id)
		"antenna_omni":
			_build_omni_antenna(comp.id)
		"camera_mast":
			_build_camera_mast(comp.id)
		"sensor_imager":
			_build_imager_aperture(comp.id)
		"radar_dish":
			_build_sar_radar_panel(comp.id)
		"drill_arm", "robotic_arm_drill":
			_build_drill_arm(comp.id)
		"seismometer":
			_build_seismometer(comp.id)
		"thruster_main":
			_build_main_engine(comp.id)
		"thruster_ion":
			_build_ion_engine(comp.id)
		"thruster_rcs":
			_build_rcs_blocks(comp.id)
		"landing_gear_lunar":
			_build_lunar_landing_gear(comp.id)
		"heat_shield_aeroshell":
			_build_aeroshell_capsule(comp.id)
		"skycrane_stage":
			_build_skycrane_stage(comp.id)
		"battery_pack":
			_build_battery_pack(comp.id)
		"avionics_computer":
			_build_avionics_box(comp.id)
		"lunar_micro_rover":
			_build_lunar_micro_rover(comp.id)
		"prop_tank":
			_build_aux_propellant_tank(comp.id)

# --- Procedural Mesh & Materials Builders ---

func _build_fallback_bus() -> void:
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.8, 0.8, 0.8)
	mi.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.75, 0.2)
	mat.metallic = 0.85
	mat.roughness = 0.22
	mi.material_override = mat
	_root_node.add_child(mi)

func _build_standard_sat_bus() -> void:
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.9, 0.9, 1.1)
	mi.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.76, 0.22) # Kapton Gold Foil
	mat.metallic = 0.88
	mat.roughness = 0.24
	mi.material_override = mat
	_root_node.add_child(mi)

	# Avionics radiator louvers (Silver)
	for side in [-1.0, 1.0]:
		var louver = MeshInstance3D.new()
		var l_box = BoxMesh.new()
		l_box.size = Vector3(0.02, 0.5, 0.6)
		louver.mesh = l_box
		louver.position = Vector3(side * 0.46, 0.0, 0.0)
		var l_mat = StandardMaterial3D.new()
		l_mat.albedo_color = Color(0.9, 0.92, 0.95)
		l_mat.metallic = 0.95
		l_mat.roughness = 0.15
		louver.material_override = l_mat
		_root_node.add_child(louver)

func _build_deep_space_bus() -> void:
	var mi = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.62
	cyl.bottom_radius = 0.62
	cyl.height = 1.25
	cyl.radial_segments = 8 # Octagonal probe bus
	mi.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.88, 0.92) # Titanium MLI
	mat.metallic = 0.94
	mat.roughness = 0.18
	mi.material_override = mat
	_root_node.add_child(mi)

func _build_rover_chassis() -> void:
	# Main body (Warm Electronics Box)
	var body = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(0.9, 0.45, 1.3)
	body.mesh = b_mesh
	body.position = Vector3(0, 0.2, 0)
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.92, 0.93, 0.95)
	body_mat.metallic = 0.4
	body_mat.roughness = 0.35
	body.material_override = body_mat
	_root_node.add_child(body)

	# 6 Rocker-Bogie Wheels
	var wheel_offsets = [
		Vector3(-0.6, -0.15, 0.5), Vector3(0.6, -0.15, 0.5),
		Vector3(-0.65, -0.15, 0.0), Vector3(0.65, -0.15, 0.0),
		Vector3(-0.6, -0.15, -0.5), Vector3(0.6, -0.15, -0.5)
	]
	var w_mat = StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.2, 0.22, 0.25)
	w_mat.metallic = 0.85
	w_mat.roughness = 0.35

	for pos in wheel_offsets:
		var wheel = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.18
		cyl.bottom_radius = 0.18
		cyl.height = 0.14
		wheel.mesh = cyl
		wheel.rotation.z = PI / 2.0
		wheel.position = pos
		wheel.material_override = w_mat
		_root_node.add_child(wheel)

func _build_dual_solar_wings(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3.ZERO, Vector3(0.0, 0.4, 0.0))

	var cell_mat = StandardMaterial3D.new()
	cell_mat.albedo_color = Color(0.05, 0.12, 0.28) # Anti-reflection coated Silicon
	cell_mat.metallic = 0.92
	cell_mat.roughness = 0.12

	var boom_mat = StandardMaterial3D.new()
	boom_mat.albedo_color = Color(0.85, 0.75, 0.2) # Gold deployment hinge
	boom_mat.metallic = 0.9

	for side in [-1.0, 1.0]:
		var wing = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(1.3, 0.02, 0.52)
		wing.mesh = box
		wing.position = Vector3(side * 1.25, 0.1, 0.0)
		wing.material_override = cell_mat
		wrapper.add_child(wing)

		var boom = MeshInstance3D.new()
		var b_cyl = CylinderMesh.new()
		b_cyl.top_radius = 0.025
		b_cyl.bottom_radius = 0.025
		b_cyl.height = 0.6
		boom.mesh = b_cyl
		boom.rotation.z = PI / 2.0
		boom.position = Vector3(side * 0.62, 0.1, 0.0)
		boom.material_override = boom_mat
		wrapper.add_child(boom)

func _build_fixed_solar_panels(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3.ZERO, Vector3(0.0, 0.0, 0.8))
	var wing_mat = StandardMaterial3D.new()
	wing_mat.albedo_color = Color(0.06, 0.14, 0.35)
	wing_mat.metallic = 0.88
	wing_mat.roughness = 0.15

	for side in [-1.0, 1.0]:
		var panel = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.025, 0.75, 0.95)
		panel.mesh = box
		panel.position = Vector3(side * 0.47, 0.0, 0.0)
		panel.material_override = wing_mat
		wrapper.add_child(panel)

func _build_rtg_generator(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(0.0, 0.15, -0.7), Vector3(0.0, 0.2, -1.0))
	var rtg = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.14
	cyl.bottom_radius = 0.14
	cyl.height = 0.52
	rtg.mesh = cyl
	rtg.rotation.x = PI / 2.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.24, 0.26)
	mat.roughness = 0.35
	mat.metallic = 0.85
	rtg.material_override = mat
	wrapper.add_child(rtg)

	# Radial heat fins
	var fin_mat = StandardMaterial3D.new()
	fin_mat.albedo_color = Color(0.18, 0.18, 0.2)
	fin_mat.metallic = 0.9
	for i in range(6):
		var fin = MeshInstance3D.new()
		var f_box = BoxMesh.new()
		f_box.size = Vector3(0.38, 0.012, 0.48)
		fin.mesh = f_box
		fin.rotation.z = float(i) * PI / 3.0
		fin.material_override = fin_mat
		wrapper.add_child(fin)

func _build_parabolic_dish(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(0.0, 0.68, 0.1), Vector3(0.0, 1.2, 0.3))
	
	# Reflector dish
	var dish = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.38
	sphere.height = 0.16
	sphere.radial_segments = 36
	dish.mesh = sphere
	dish.rotation.x = -PI / 3.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.94, 0.95, 0.97)
	mat.metallic = 0.7
	mat.roughness = 0.2
	dish.material_override = mat
	wrapper.add_child(dish)

	# Feed horn subreflector
	var feed = MeshInstance3D.new()
	var f_cyl = CylinderMesh.new()
	f_cyl.top_radius = 0.02
	f_cyl.bottom_radius = 0.035
	f_cyl.height = 0.12
	feed.mesh = f_cyl
	feed.position = Vector3(0.0, 0.15, 0.1)
	feed.rotation.x = -PI / 3.0
	var f_mat = StandardMaterial3D.new()
	f_mat.albedo_color = Color(0.85, 0.75, 0.2) # Gold feed
	f_mat.metallic = 0.95
	feed.material_override = f_mat
	wrapper.add_child(feed)

func _build_horn_antenna(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(0.32, 0.60, 0.32), Vector3(0.8, 1.0, 0.8))
	var horn = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.13
	cone.bottom_radius = 0.025
	cone.height = 0.32
	horn.mesh = cone
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.86, 0.88)
	mat.metallic = 0.92
	horn.material_override = mat
	wrapper.add_child(horn)

func _build_omni_antenna(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(-0.35, 0.72, -0.35), Vector3(-0.8, 1.0, -0.8))
	var omni = MeshInstance3D.new()
	var whip = CylinderMesh.new()
	whip.top_radius = 0.015
	whip.bottom_radius = 0.02
	whip.height = 0.65
	omni.mesh = whip
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.92, 0.92)
	mat.metallic = 0.95
	omni.material_override = mat
	wrapper.add_child(omni)

func _build_camera_mast(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(0.2, 0.65, 0.35), Vector3(0.4, 1.2, 0.6))
	var mast = MeshInstance3D.new()
	var pole = CylinderMesh.new()
	pole.top_radius = 0.03
	pole.bottom_radius = 0.04
	pole.height = 0.72
	mast.mesh = pole
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.88, 0.9)
	mat.metallic = 0.85
	mast.material_override = mat
	wrapper.add_child(mast)

	var head = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.24, 0.13, 0.16)
	head.mesh = box
	head.position = Vector3(0.0, 0.38, 0.0)
	var h_mat = StandardMaterial3D.new()
	h_mat.albedo_color = Color(0.95, 0.75, 0.2) # Mastcam gold MLI
	h_mat.metallic = 0.9
	head.material_override = h_mat
	wrapper.add_child(head)

func _build_imager_aperture(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(0.0, -0.52, 0.0), Vector3(0.0, -1.2, 0.0))
	var imager = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.13
	cyl.bottom_radius = 0.13
	cyl.height = 0.32
	imager.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.16)
	mat.metallic = 0.95
	mat.roughness = 0.15
	imager.material_override = mat
	wrapper.add_child(imager)

func _build_sar_radar_panel(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(0.0, -0.58, 0.0), Vector3(0.0, -1.3, 0.0))
	var radar = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.7, 0.025, 0.45)
	radar.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.85, 0.28) # Phased Array Gold
	mat.metallic = 0.9
	radar.material_override = mat
	wrapper.add_child(radar)

func _build_drill_arm(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(0.35, 0.0, 0.75), Vector3(0.9, -0.2, 1.2))
	var arm = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.035
	cyl.height = 0.58
	arm.mesh = cyl
	arm.rotation.x = PI / 4.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.42, 0.45)
	mat.metallic = 0.92
	arm.material_override = mat
	wrapper.add_child(arm)

func _build_seismometer(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(-0.35, 0.3, 0.4), Vector3(-0.9, 0.4, 0.9))
	var dome = MeshInstance3D.new()
	var sp = SphereMesh.new()
	sp.radius = 0.13
	sp.height = 0.13
	dome.mesh = sp
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.65, 0.15)
	mat.metallic = 0.8
	dome.material_override = mat
	wrapper.add_child(dome)

func _build_main_engine(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(0.0, 0.0, -0.68), Vector3(0.0, 0.0, -1.5))
	var eng = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.08
	cone.bottom_radius = 0.24
	cone.height = 0.42
	eng.mesh = cone
	eng.rotation.x = PI / 2.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.24, 0.18) # Niobium rocket nozzle
	mat.metallic = 0.95
	mat.roughness = 0.3
	eng.material_override = mat
	wrapper.add_child(eng)

func _build_ion_engine(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(0.0, 0.0, -0.68), Vector3(0.0, 0.0, -1.5))
	var eng = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.17
	cyl.bottom_radius = 0.17
	cyl.height = 0.28
	eng.mesh = cyl
	eng.rotation.x = PI / 2.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.85, 1.0) # Glowing Xenon blue
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.75, 1.0)
	mat.emission_energy_multiplier = 2.5
	eng.material_override = mat
	wrapper.add_child(eng)

func _build_rcs_blocks(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3.ZERO, Vector3(0.0, 0.8, 0.0))
	var corners = [
		Vector3(-0.48, 0.4, 0.48), Vector3(0.48, 0.4, 0.48),
		Vector3(-0.48, 0.4, -0.48), Vector3(0.48, 0.4, -0.48)
	]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.75, 0.2)
	mat.metallic = 0.92

	for pos in corners:
		var rcs = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.09, 0.09, 0.09)
		rcs.mesh = box
		rcs.position = pos
		rcs.material_override = mat
		wrapper.add_child(rcs)

func _build_lunar_landing_gear(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3.ZERO, Vector3(0.0, -1.3, 0.0))
	var leg_mat = StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.92, 0.80, 0.22)
	leg_mat.metallic = 0.94
	leg_mat.roughness = 0.22

	var leg_angles = [PI / 4.0, 3.0 * PI / 4.0, 5.0 * PI / 4.0, 7.0 * PI / 4.0]
	for ang in leg_angles:
		var dir_x = cos(ang)
		var dir_z = sin(ang)

		var start_pos = Vector3(dir_x * 0.44, -0.32, dir_z * 0.44)
		var foot_pos = Vector3(dir_x * 0.95, -0.78, dir_z * 0.95)
		var dist = start_pos.distance_to(foot_pos)

		var mount = Node3D.new()
		wrapper.add_child(mount)
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

		# Footpad
		var foot = MeshInstance3D.new()
		var f_cyl = CylinderMesh.new()
		f_cyl.top_radius = 0.08
		f_cyl.bottom_radius = 0.095
		f_cyl.height = 0.03
		foot.mesh = f_cyl
		foot.position = foot_pos
		foot.material_override = leg_mat
		wrapper.add_child(foot)

func _build_aeroshell_capsule(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(0.0, -0.3, 0.0), Vector3(0.0, -1.6, 0.0))
	var shield = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 1.05
	cone.height = 0.45
	shield.mesh = cone
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.22, 0.25) # PICA Heat Shield Dark
	mat.roughness = 0.88
	shield.material_override = mat
	wrapper.add_child(shield)

func _build_skycrane_stage(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(0.0, 0.55, 0.0), Vector3(0.0, 1.4, 0.0))
	var crane = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.15, 0.16, 1.15)
	crane.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.74, 0.78)
	mat.metallic = 0.9
	crane.material_override = mat
	wrapper.add_child(crane)

func _build_battery_pack(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(-0.35, -0.2, -0.2), Vector3(-1.0, -0.5, -0.6))
	var bat = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.26, 0.26, 0.36)
	bat.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.42, 0.85) # Battery Blue
	mat.metallic = 0.7
	mat.roughness = 0.2
	bat.material_override = mat
	wrapper.add_child(bat)

func _build_avionics_box(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(0.3, -0.2, -0.2), Vector3(0.9, -0.5, -0.6))
	var avi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.28, 0.18, 0.28)
	avi.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.34, 0.38)
	mat.metallic = 0.8
	avi.material_override = mat
	wrapper.add_child(avi)

func _build_lunar_micro_rover(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3(0.52, -0.15, 0.0), Vector3(1.4, -0.3, 0.0))
	var chassis = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.24, 0.10, 0.28)
	chassis.mesh = box
	var c_mat = StandardMaterial3D.new()
	c_mat.albedo_color = Color(0.88, 0.75, 0.2)
	c_mat.metallic = 0.85
	chassis.material_override = c_mat
	wrapper.add_child(chassis)

	var w_mat = StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.18, 0.18, 0.2)
	w_mat.metallic = 0.8
	var wheel_offsets = [
		Vector3(-0.13, -0.06, 0.11), Vector3(0.13, -0.06, 0.11),
		Vector3(-0.13, -0.06, -0.11), Vector3(0.13, -0.06, -0.11)
	]
	for w_pos in wheel_offsets:
		var wheel = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.045
		cyl.height = 0.03
		wheel.mesh = cyl
		wheel.rotation.z = PI / 2.0
		wheel.position = w_pos
		wheel.material_override = w_mat
		wrapper.add_child(wheel)

func _build_aux_propellant_tank(comp_id: String) -> void:
	var wrapper = _create_wrapper(comp_id, Vector3.ZERO, Vector3(0.0, 0.0, 1.3))
	var tank_mat = StandardMaterial3D.new()
	tank_mat.albedo_color = Color(0.78, 0.80, 0.84)
	tank_mat.metallic = 0.94
	tank_mat.roughness = 0.18

	for side in [-1.0, 1.0]:
		var tank = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.18
		sphere.height = 0.42
		sphere.radial_segments = 24
		tank.mesh = sphere
		tank.position = Vector3(side * 0.48, 0.05, 0.25)
		tank.material_override = tank_mat
		wrapper.add_child(tank)
