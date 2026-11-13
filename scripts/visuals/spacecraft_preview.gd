class_name SpacecraftPreview
extends Node3D

const StarfieldClass = preload("res://scripts/visuals/starfield.gd")

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

enum StructureType { SAT_BUS, DEEP_SPACE, ROVER }
var current_structure: StructureType = StructureType.SAT_BUS

var is_exploded_mode: bool = false
var explosion_factor: float = 0.0 # 0.0 = compact, 1.0 = exploded
var highlighted_comp_id: String = ""

var _root_node: Node3D
var _orbit_cam: Camera3D
var _cam_pivot: Node3D
var _cam_distance: float = 4.2
var _target_distance: float = 4.2
var _target_rot_y: float = 0.0
var _target_rot_x: float = -0.10
var _cam_target: Vector3 = Vector3(0, 0.05, 0)

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
	_orbit_cam.position = Vector3(0, 0.25, _cam_distance)
	var cam_dir = (_cam_target - _orbit_cam.position).normalized()
	if cam_dir.length_squared() > 0.001:
		_orbit_cam.transform = Transform3D().looking_at(cam_dir, Vector3.UP)
		_orbit_cam.position = Vector3(0, 0.25, _cam_distance)

	_root_node = Node3D.new()
	add_child(_root_node)

	var sf = StarfieldClass.new()
	sf.radius_min = 25.0
	sf.radius_max = 50.0
	add_child(sf)

	_setup_line_renderer()

	var gm = Engine.get_main_loop().root.get_node_or_null("GameManager") if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root else null
	if gm != null and gm.current_spacecraft != null:
		rebuild_spacecraft(gm.current_spacecraft)

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
	_orbit_cam.look_at(_cam_pivot.global_position, Vector3.UP)

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
	_target_distance = 4.2
	_target_rot_y = 0.0
	_target_rot_x = -0.10
	_cam_target = Vector3(0, 0.05, 0)
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
	if _root_node == null:
		_root_node = Node3D.new()
		add_child(_root_node)

	_component_nodes.clear()
	for c in _root_node.get_children():
		if c != _line_mesh_instance:
			c.queue_free()

	if spacecraft == null or spacecraft.selected_components.is_empty():
		current_structure = StructureType.SAT_BUS
		_build_fallback_bus()
		return

	# Determine current structure
	current_structure = StructureType.SAT_BUS
	for comp in spacecraft.selected_components:
		if comp.category == "Structure":
			if comp.id == "chassis_mars_rover" or comp.visual_type == "rover_chassis":
				current_structure = StructureType.ROVER
				break
			elif comp.id == "bus_deep_space" or comp.visual_type == "bus_heavy":
				current_structure = StructureType.DEEP_SPACE
				break
			elif comp.id == "bus_medium_sat" or comp.visual_type == "bus_medium":
				current_structure = StructureType.SAT_BUS
				break

	# 1. Primary Chassis/Bus
	match current_structure:
		StructureType.ROVER:
			_build_rover_chassis()
		StructureType.DEEP_SPACE:
			_build_deep_space_bus()
		_:
			_build_standard_sat_bus()

	# 2. Modular Components (Structure is already constructed as primary chassis)
	for comp in spacecraft.selected_components:
		if comp.category != "Structure":
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
	if comp.id == "prop_aux_tank" or comp.visual_type == "prop_tank":
		_build_aux_propellant_tank(comp.id)
		return
	if comp.id == "data_solid_state_recorder" or comp.visual_type == "data_box":
		_build_solid_state_recorder(comp.id)
		return

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
	cyl.top_radius = 0.54
	cyl.bottom_radius = 0.54
	cyl.height = 1.3
	cyl.radial_segments = 8 # Octagonal probe bus
	mi.mesh = cyl
	mi.rotation.x = PI / 2.0 # Aligned with Z flight axis
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.88, 0.92) # Titanium MLI
	mat.metallic = 0.94
	mat.roughness = 0.18
	mi.material_override = mat
	_root_node.add_child(mi)

	# Aft thrust adapter ring at z = -0.65
	var thrust_ring = MeshInstance3D.new()
	var t_cyl = CylinderMesh.new()
	t_cyl.top_radius = 0.48
	t_cyl.bottom_radius = 0.45
	t_cyl.height = 0.12
	thrust_ring.mesh = t_cyl
	thrust_ring.rotation.x = PI / 2.0
	thrust_ring.position = Vector3(0, 0, -0.65)
	var t_mat = StandardMaterial3D.new()
	t_mat.albedo_color = Color(0.3, 0.32, 0.35)
	t_mat.metallic = 0.9
	thrust_ring.material_override = t_mat
	_root_node.add_child(thrust_ring)

	# Forward payload adapter ring at z = +0.65
	var fwd_ring = MeshInstance3D.new()
	var f_cyl = CylinderMesh.new()
	f_cyl.top_radius = 0.46
	f_cyl.bottom_radius = 0.48
	f_cyl.height = 0.10
	fwd_ring.mesh = f_cyl
	fwd_ring.rotation.x = PI / 2.0
	fwd_ring.position = Vector3(0, 0, 0.65)
	fwd_ring.material_override = t_mat
	_root_node.add_child(fwd_ring)

	# Equipment mounting shelves on port and starboard
	for side in [-1.0, 1.0]:
		var shelf = MeshInstance3D.new()
		var s_box = BoxMesh.new()
		s_box.size = Vector3(0.04, 0.45, 0.65)
		shelf.mesh = s_box
		shelf.position = Vector3(side * 0.54, -0.1, -0.1)
		shelf.material_override = t_mat
		_root_node.add_child(shelf)

func _build_rover_chassis() -> void:
	# Main body (Warm Electronics Box)
	var body = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(0.85, 0.42, 1.25)
	body.mesh = b_mesh
	body.position = Vector3(0, 0.22, 0)
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.92, 0.93, 0.95)
	body_mat.metallic = 0.4
	body_mat.roughness = 0.35
	body.material_override = body_mat
	_root_node.add_child(body)

	# Top deck equipment plate
	var deck = MeshInstance3D.new()
	var d_mesh = BoxMesh.new()
	d_mesh.size = Vector3(0.88, 0.03, 1.28)
	deck.mesh = d_mesh
	deck.position = Vector3(0, 0.435, 0)
	var d_mat = StandardMaterial3D.new()
	d_mat.albedo_color = Color(0.82, 0.84, 0.88)
	d_mat.metallic = 0.85
	d_mat.roughness = 0.25
	deck.material_override = d_mat
	_root_node.add_child(deck)

	# Front nose hazard/science bumper
	var bumper = MeshInstance3D.new()
	var bmp_mesh = BoxMesh.new()
	bmp_mesh.size = Vector3(0.65, 0.12, 0.14)
	bumper.mesh = bmp_mesh
	bumper.position = Vector3(0, 0.22, 0.67)
	bumper.material_override = d_mat
	_root_node.add_child(bumper)

	# 6 Rocker-Bogie Wheels
	var wheel_offsets = [
		Vector3(-0.62, -0.15, 0.52), Vector3(0.62, -0.15, 0.52),
		Vector3(-0.66, -0.15, 0.0), Vector3(0.66, -0.15, 0.0),
		Vector3(-0.62, -0.15, -0.52), Vector3(0.62, -0.15, -0.52)
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

	# Rocker-Bogie structural suspension struts
	var strut_mat = StandardMaterial3D.new()
	strut_mat.albedo_color = Color(0.35, 0.38, 0.42)
	strut_mat.metallic = 0.9
	strut_mat.roughness = 0.25

	for side in [-1.0, 1.0]:
		var pivot_pos = Vector3(side * 0.44, 0.20, 0.05)
		_create_suspension_strut(pivot_pos, Vector3(side * 0.58, -0.15, 0.52), strut_mat)
		var bogie_joint = Vector3(side * 0.52, 0.05, -0.25)
		_create_suspension_strut(pivot_pos, bogie_joint, strut_mat)
		_create_suspension_strut(bogie_joint, Vector3(side * 0.62, -0.15, 0.0), strut_mat)
		_create_suspension_strut(bogie_joint, Vector3(side * 0.58, -0.15, -0.52), strut_mat)

func _create_suspension_strut(from_pos: Vector3, to_pos: Vector3, mat: Material) -> void:
	var mount = Node3D.new()
	_root_node.add_child(mount)
	var dir = (to_pos - from_pos).normalized()
	if dir.length_squared() > 0.001:
		var up = Vector3.UP if abs(dir.y) < 0.99 else Vector3.FORWARD
		mount.transform = Transform3D().looking_at(dir, up)
	mount.position = from_pos
	var dist = from_pos.distance_to(to_pos)
	var strut = MeshInstance3D.new()
	var s_cyl = CylinderMesh.new()
	s_cyl.top_radius = 0.022
	s_cyl.bottom_radius = 0.022
	s_cyl.height = dist
	strut.mesh = s_cyl
	strut.position = Vector3(0.0, 0.0, -dist * 0.5)
	strut.rotation.x = PI / 2.0
	strut.material_override = mat
	mount.add_child(strut)

func _create_arm_tube(parent: Node3D, from_pos: Vector3, to_pos: Vector3, radius: float, mat: Material) -> void:
	var mount = Node3D.new()
	parent.add_child(mount)
	var dir = (to_pos - from_pos).normalized()
	if dir.length_squared() > 0.001:
		var up = Vector3.UP if abs(dir.y) < 0.99 else Vector3.FORWARD
		mount.transform = Transform3D().looking_at(dir, up)
	mount.position = from_pos
	var dist = from_pos.distance_to(to_pos)
	var tube = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = dist
	tube.mesh = cyl
	tube.position = Vector3(0.0, 0.0, -dist * 0.5)
	tube.rotation.x = PI / 2.0
	tube.material_override = mat
	mount.add_child(tube)

func _build_dual_solar_wings(comp_id: String) -> void:
	var compact_pos = Vector3.ZERO
	var exploded_offset = Vector3(0.0, 0.4, 0.0)
	var wing_y = 0.1
	var wing_x = 1.25
	var boom_x = 0.62
	var boom_len = 0.6

	if current_structure == StructureType.ROVER:
		compact_pos = Vector3(0.0, 0.42, -0.05)
		exploded_offset = Vector3(0.0, 0.6, 0.0)
		wing_y = 0.0
		wing_x = 1.15
		boom_x = 0.55
		boom_len = 0.5
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(0.0, 0.0, 0.0)
		exploded_offset = Vector3(0.0, 0.6, 0.0)
		wing_y = 0.0
		wing_x = 1.35
		boom_x = 0.68
		boom_len = 0.6

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)

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
		wing.position = Vector3(side * wing_x, wing_y, 0.0)
		wing.material_override = cell_mat
		wrapper.add_child(wing)

		var boom = MeshInstance3D.new()
		var b_cyl = CylinderMesh.new()
		b_cyl.top_radius = 0.025
		b_cyl.bottom_radius = 0.025
		b_cyl.height = boom_len
		boom.mesh = b_cyl
		boom.rotation.z = PI / 2.0
		boom.position = Vector3(side * boom_x, wing_y, 0.0)
		boom.material_override = boom_mat
		wrapper.add_child(boom)

func _build_fixed_solar_panels(comp_id: String) -> void:
	if current_structure == StructureType.ROVER:
		# On rover: fixed panels form a horizontal deck cover on top of the WEB
		var wrapper = _create_wrapper(comp_id, Vector3(0.0, 0.45, -0.05), Vector3(0.0, 0.5, 0.0))
		var panel = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.84, 0.02, 0.95)
		panel.mesh = box
		var wing_mat = StandardMaterial3D.new()
		wing_mat.albedo_color = Color(0.06, 0.14, 0.35)
		wing_mat.metallic = 0.88
		wing_mat.roughness = 0.15
		panel.material_override = wing_mat
		wrapper.add_child(panel)
		return

	var panel_x = 0.47
	if current_structure == StructureType.DEEP_SPACE:
		panel_x = 0.55

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
		panel.position = Vector3(side * panel_x, 0.0, 0.0)
		panel.material_override = wing_mat
		wrapper.add_child(panel)

func _build_rtg_generator(comp_id: String) -> void:
	var compact_pos = Vector3(0.0, 0.15, -0.68)
	var exploded_offset = Vector3(0.0, 0.2, -1.0)
	var tilt_x = PI / 2.0

	if current_structure == StructureType.ROVER:
		# On rover: aft tail boom tilted 20 degrees up
		compact_pos = Vector3(0.0, 0.32, -0.72)
		exploded_offset = Vector3(0.0, 0.35, -0.9)
		tilt_x = PI / 2.4
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(0.0, 0.15, -0.76)
		exploded_offset = Vector3(0.0, 0.25, -1.1)

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)

	# Mounting strut connecting to chassis
	var mount = MeshInstance3D.new()
	var m_cyl = CylinderMesh.new()
	m_cyl.top_radius = 0.03
	m_cyl.bottom_radius = 0.03
	m_cyl.height = 0.22
	mount.mesh = m_cyl
	mount.rotation.x = PI / 2.0
	mount.position = Vector3(0.0, 0.0, 0.15)
	var m_mat = StandardMaterial3D.new()
	m_mat.albedo_color = Color(0.4, 0.42, 0.45)
	m_mat.metallic = 0.9
	mount.material_override = m_mat
	wrapper.add_child(mount)

	var rtg = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.14
	cyl.bottom_radius = 0.14
	cyl.height = 0.52
	rtg.mesh = cyl
	rtg.rotation.x = tilt_x
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
	var compact_pos = Vector3(0.0, 0.58, 0.1)
	var exploded_offset = Vector3(0.0, 1.2, 0.3)
	var pedestal_height = 0.22

	if current_structure == StructureType.ROVER:
		# Gimballed HGA dish on rear-port deck
		compact_pos = Vector3(-0.25, 0.44, -0.32)
		exploded_offset = Vector3(-0.35, 1.1, -0.3)
		pedestal_height = 0.26
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(0.0, 0.65, 0.15)
		exploded_offset = Vector3(0.0, 1.3, 0.3)
		pedestal_height = 0.24

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)

	# Mounting pedestal connecting to structure
	var ped = MeshInstance3D.new()
	var p_cyl = CylinderMesh.new()
	p_cyl.top_radius = 0.035
	p_cyl.bottom_radius = 0.05
	p_cyl.height = pedestal_height
	ped.mesh = p_cyl
	ped.position = Vector3(0.0, pedestal_height * 0.5, 0.0)
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.45, 0.48, 0.52)
	p_mat.metallic = 0.9
	ped.material_override = p_mat
	wrapper.add_child(ped)

	# Reflector dish
	var dish = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.38
	sphere.height = 0.16
	sphere.radial_segments = 36
	dish.mesh = sphere
	dish.position = Vector3(0.0, pedestal_height, 0.0)
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
	feed.position = Vector3(0.0, pedestal_height + 0.15, 0.1)
	feed.rotation.x = -PI / 3.0
	var f_mat = StandardMaterial3D.new()
	f_mat.albedo_color = Color(0.85, 0.75, 0.2) # Gold feed
	f_mat.metallic = 0.95
	feed.material_override = f_mat
	wrapper.add_child(feed)

func _build_horn_antenna(comp_id: String) -> void:
	var compact_pos = Vector3(0.32, 0.50, 0.32)
	var exploded_offset = Vector3(0.8, 1.0, 0.8)

	if current_structure == StructureType.ROVER:
		compact_pos = Vector3(0.26, 0.44, -0.32)
		exploded_offset = Vector3(0.6, 1.0, -0.3)
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(0.38, 0.58, 0.32)

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)

	# Mount plate
	var mount = MeshInstance3D.new()
	var m_box = BoxMesh.new()
	m_box.size = Vector3(0.08, 0.02, 0.08)
	mount.mesh = m_box
	var m_mat = StandardMaterial3D.new()
	m_mat.albedo_color = Color(0.4, 0.42, 0.45)
	m_mat.metallic = 0.9
	mount.material_override = m_mat
	wrapper.add_child(mount)

	var horn = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.13
	cone.bottom_radius = 0.025
	cone.height = 0.32
	horn.mesh = cone
	horn.position = Vector3(0.0, 0.16, 0.0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.86, 0.88)
	mat.metallic = 0.92
	horn.material_override = mat
	wrapper.add_child(horn)

func _build_omni_antenna(comp_id: String) -> void:
	var compact_pos = Vector3(-0.35, 0.48, -0.35)
	var exploded_offset = Vector3(-0.8, 1.0, -0.8)

	if current_structure == StructureType.ROVER:
		compact_pos = Vector3(-0.32, 0.44, -0.48)
		exploded_offset = Vector3(-0.6, 1.0, -0.5)
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(-0.40, 0.58, -0.35)

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)

	# Base mount
	var mount = MeshInstance3D.new()
	var m_box = BoxMesh.new()
	m_box.size = Vector3(0.06, 0.02, 0.06)
	mount.mesh = m_box
	var m_mat = StandardMaterial3D.new()
	m_mat.albedo_color = Color(0.4, 0.42, 0.45)
	m_mat.metallic = 0.9
	mount.material_override = m_mat
	wrapper.add_child(mount)

	var omni = MeshInstance3D.new()
	var whip = CylinderMesh.new()
	whip.top_radius = 0.015
	whip.bottom_radius = 0.02
	whip.height = 0.65
	omni.mesh = whip
	omni.position = Vector3(0.0, 0.325, 0.0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.92, 0.92)
	mat.metallic = 0.95
	omni.material_override = mat
	wrapper.add_child(omni)

func _build_camera_mast(comp_id: String) -> void:
	var compact_pos = Vector3(0.20, 0.45, 0.35)
	var exploded_offset = Vector3(0.4, 1.2, 0.6)

	if current_structure == StructureType.ROVER:
		# Remote Sensing Mast (Mastcam / SuperCam) on front-starboard deck
		compact_pos = Vector3(0.24, 0.44, 0.35)
		exploded_offset = Vector3(0.4, 1.2, 0.5)
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(0.25, 0.54, 0.35)
		exploded_offset = Vector3(0.5, 1.2, 0.5)

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)

	# Base mount plate
	var base = MeshInstance3D.new()
	var b_box = BoxMesh.new()
	b_box.size = Vector3(0.12, 0.025, 0.12)
	base.mesh = b_box
	base.position = Vector3(0.0, 0.012, 0.0)
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.35, 0.38, 0.42)
	b_mat.metallic = 0.9
	base.material_override = b_mat
	wrapper.add_child(base)

	# Mast pole
	var mast = MeshInstance3D.new()
	var pole = CylinderMesh.new()
	pole.top_radius = 0.03
	pole.bottom_radius = 0.04
	pole.height = 0.72
	mast.mesh = pole
	mast.position = Vector3(0.0, 0.36, 0.0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.88, 0.9)
	mat.metallic = 0.85
	mast.material_override = mat
	wrapper.add_child(mast)

	# Mastcam sensor head
	var head = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.24, 0.13, 0.16)
	head.mesh = box
	head.position = Vector3(0.0, 0.72, 0.0)
	var h_mat = StandardMaterial3D.new()
	h_mat.albedo_color = Color(0.95, 0.75, 0.2) # Mastcam gold MLI
	h_mat.metallic = 0.9
	head.material_override = h_mat
	wrapper.add_child(head)

	# Dual stereo camera lenses
	for l_side in [-0.07, 0.07]:
		var lens = MeshInstance3D.new()
		var l_cyl = CylinderMesh.new()
		l_cyl.top_radius = 0.032
		l_cyl.bottom_radius = 0.032
		l_cyl.height = 0.05
		lens.mesh = l_cyl
		lens.rotation.x = PI / 2.0
		lens.position = Vector3(l_side, 0.72, 0.08)
		var l_mat = StandardMaterial3D.new()
		l_mat.albedo_color = Color(0.08, 0.08, 0.12)
		l_mat.metallic = 0.95
		l_mat.roughness = 0.1
		lens.material_override = l_mat
		wrapper.add_child(lens)

func _build_imager_aperture(comp_id: String) -> void:
	var compact_pos = Vector3(0.0, -0.48, 0.0)
	var exploded_offset = Vector3(0.0, -1.2, 0.0)
	var rot_x = 0.0

	if current_structure == StructureType.ROVER:
		# Front nose hazcam / science imager
		compact_pos = Vector3(-0.16, 0.25, 0.67)
		exploded_offset = Vector3(-0.3, 0.3, 1.2)
		rot_x = PI / 2.0 # Points forward
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(0.0, -0.56, 0.1)
		exploded_offset = Vector3(0.0, -1.3, 0.1)

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)

	# Mounting bracket
	var brk = MeshInstance3D.new()
	var b_box = BoxMesh.new()
	b_box.size = Vector3(0.18, 0.03, 0.18)
	brk.mesh = b_box
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.4, 0.42, 0.45)
	b_mat.metallic = 0.9
	brk.material_override = b_mat
	wrapper.add_child(brk)

	var imager = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.13
	cyl.bottom_radius = 0.13
	cyl.height = 0.32
	imager.mesh = cyl
	imager.position = Vector3(0.0, -0.16 if rot_x == 0.0 else 0.0, 0.16 if rot_x != 0.0 else 0.0)
	imager.rotation.x = rot_x
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.16)
	mat.metallic = 0.95
	mat.roughness = 0.15
	imager.material_override = mat
	wrapper.add_child(imager)

func _build_sar_radar_panel(comp_id: String) -> void:
	var compact_pos = Vector3(0.0, -0.52, 0.0)
	var exploded_offset = Vector3(0.0, -1.3, 0.0)

	if current_structure == StructureType.ROVER:
		# RIMFAX Ground-Penetrating Radar under rear chassis
		compact_pos = Vector3(0.0, 0.06, -0.50)
		exploded_offset = Vector3(0.0, -0.8, -0.8)
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(0.0, -0.62, 0.0)
		exploded_offset = Vector3(0.0, -1.4, 0.0)

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)

	# Mounting struts
	for side in [-0.35, 0.35]:
		var strut = MeshInstance3D.new()
		var s_cyl = CylinderMesh.new()
		s_cyl.top_radius = 0.02
		s_cyl.bottom_radius = 0.02
		s_cyl.height = 0.18
		strut.mesh = s_cyl
		strut.position = Vector3(side, 0.08, 0.0)
		var s_mat = StandardMaterial3D.new()
		s_mat.albedo_color = Color(0.4, 0.42, 0.45)
		s_mat.metallic = 0.9
		strut.material_override = s_mat
		wrapper.add_child(strut)

	var radar = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.7 if current_structure != StructureType.ROVER else 0.75, 0.025, 0.45)
	radar.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.85, 0.28) # Phased Array Gold
	mat.metallic = 0.9
	radar.material_override = mat
	wrapper.add_child(radar)

func _build_drill_arm(comp_id: String) -> void:
	var compact_pos = Vector3(0.45, -0.12, 0.32)
	var exploded_offset = Vector3(0.8, -0.2, 0.8)

	if current_structure == StructureType.ROVER:
		# Front-port deck mounting anchored flush to rover equipment plate
		compact_pos = Vector3(-0.25, 0.445, 0.50)
		exploded_offset = Vector3(-0.7, 0.5, 0.8)
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(0.54, -0.12, 0.32)
		exploded_offset = Vector3(1.0, -0.2, 0.8)

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)

	# Common materials
	var struct_mat = StandardMaterial3D.new()
	struct_mat.albedo_color = Color(0.28, 0.30, 0.34) # Anodized aerospace titanium
	struct_mat.metallic = 0.92
	struct_mat.roughness = 0.25

	var joint_mat = StandardMaterial3D.new()
	joint_mat.albedo_color = Color(0.18, 0.19, 0.22) # High-torque graphite servo casing
	joint_mat.metallic = 0.85
	joint_mat.roughness = 0.35

	var gold_mat = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.92, 0.78, 0.22) # Gold MLI thermal foil
	gold_mat.metallic = 0.92
	gold_mat.roughness = 0.16

	var carbide_mat = StandardMaterial3D.new()
	carbide_mat.albedo_color = Color(0.92, 0.94, 0.97) # Polished tungsten carbide
	carbide_mat.metallic = 0.98
	carbide_mat.roughness = 0.12

	var steel_mat = StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.70, 0.73, 0.78) # Machined stainless steel
	steel_mat.metallic = 0.94
	steel_mat.roughness = 0.18

	if current_structure == StructureType.ROVER:
		# 1. Deck structural mounting flange bolted to top deck plate
		var flange = MeshInstance3D.new()
		var fl_box = BoxMesh.new()
		fl_box.size = Vector3(0.14, 0.018, 0.14)
		flange.mesh = fl_box
		flange.position = Vector3(0.0, 0.009, 0.0)
		flange.material_override = struct_mat
		wrapper.add_child(flange)

		# 2. Azimuth turret pedestal (yaw axis actuator)
		var pedestal = MeshInstance3D.new()
		var p_cyl = CylinderMesh.new()
		p_cyl.top_radius = 0.050
		p_cyl.bottom_radius = 0.056
		p_cyl.height = 0.075
		pedestal.mesh = p_cyl
		pedestal.position = Vector3(0.0, 0.055, 0.0)
		pedestal.material_override = joint_mat
		wrapper.add_child(pedestal)

		# 3. Shoulder pitch elevation joint
		var p_shoulder = Vector3(0.0, 0.11, 0.0)
		var shoulder = MeshInstance3D.new()
		var s_sph = SphereMesh.new()
		s_sph.radius = 0.046
		s_sph.height = 0.092
		shoulder.mesh = s_sph
		shoulder.position = p_shoulder
		shoulder.material_override = joint_mat
		wrapper.add_child(shoulder)

		# 4. Upper Arm (Bicep tube) extending forward & down
		var p_elbow = Vector3(0.02, 0.04, 0.28)
		_create_arm_tube(wrapper, p_shoulder, p_elbow, 0.026, struct_mat)

		# 5. Elbow pitch actuator
		var elbow = MeshInstance3D.new()
		var e_cyl = CylinderMesh.new()
		e_cyl.top_radius = 0.040
		e_cyl.bottom_radius = 0.040
		e_cyl.height = 0.075
		elbow.mesh = e_cyl
		elbow.position = p_elbow
		elbow.rotation.z = PI / 2.0
		elbow.material_override = joint_mat
		wrapper.add_child(elbow)

		# 6. Forearm tube extending down towards front sampling envelope
		var p_wrist = Vector3(0.02, -0.22, 0.46)
		_create_arm_tube(wrapper, p_elbow, p_wrist, 0.022, struct_mat)

		# 7. Wrist 2-axis gimbal joint
		var wrist = MeshInstance3D.new()
		var w_sph = SphereMesh.new()
		w_sph.radius = 0.038
		w_sph.height = 0.076
		wrist.mesh = w_sph
		wrist.position = p_wrist
		wrist.material_override = joint_mat
		wrapper.add_child(wrist)

		# 8. Percussive Coring Drill Turret Head
		var turret = Node3D.new()
		turret.position = Vector3(0.02, -0.26, 0.48)
		wrapper.add_child(turret)

		# Turret main gearbox (Gold MLI thermal insulation)
		var gearbox = MeshInstance3D.new()
		var g_box = BoxMesh.new()
		g_box.size = Vector3(0.12, 0.13, 0.13)
		gearbox.mesh = g_box
		gearbox.material_override = gold_mat
		turret.add_child(gearbox)

		# ChemCam / SuperCam LIBS laser pod & optics window
		var laser_tube = MeshInstance3D.new()
		var l_cyl = CylinderMesh.new()
		l_cyl.top_radius = 0.018
		l_cyl.bottom_radius = 0.018
		l_cyl.height = 0.06
		laser_tube.mesh = l_cyl
		laser_tube.rotation.x = PI / 4.0
		laser_tube.position = Vector3(0.0, 0.065, 0.05)
		laser_tube.material_override = steel_mat
		turret.add_child(laser_tube)

		var ruby_lens = MeshInstance3D.new()
		var r_cyl = CylinderMesh.new()
		r_cyl.top_radius = 0.014
		r_cyl.bottom_radius = 0.014
		r_cyl.height = 0.01
		ruby_lens.mesh = r_cyl
		ruby_lens.rotation.x = PI / 4.0
		ruby_lens.position = Vector3(0.0, 0.088, 0.072)
		var ruby_mat = StandardMaterial3D.new()
		ruby_mat.albedo_color = Color(0.95, 0.12, 0.18)
		ruby_mat.emission_enabled = true
		ruby_mat.emission = Color(0.85, 0.08, 0.12)
		ruby_lens.material_override = ruby_mat
		turret.add_child(ruby_lens)

		# Rotary-percussive drill chuck & motor spindle
		var chuck = MeshInstance3D.new()
		var c_cyl = CylinderMesh.new()
		c_cyl.top_radius = 0.032
		c_cyl.bottom_radius = 0.028
		c_cyl.height = 0.06
		chuck.mesh = c_cyl
		chuck.position = Vector3(0.0, -0.09, 0.0)
		chuck.material_override = steel_mat
		turret.add_child(chuck)

		# Hollow coring drill bit pointing downward
		var bit = MeshInstance3D.new()
		var b_cyl = CylinderMesh.new()
		b_cyl.top_radius = 0.013
		b_cyl.bottom_radius = 0.009
		b_cyl.height = 0.17
		bit.mesh = b_cyl
		bit.position = Vector3(0.0, -0.19, 0.0)
		bit.material_override = carbide_mat
		turret.add_child(bit)

		# Dual rock contact stabilizer tines
		for side in [-1.0, 1.0]:
			var tine = MeshInstance3D.new()
			var t_cyl = CylinderMesh.new()
			t_cyl.top_radius = 0.005
			t_cyl.bottom_radius = 0.005
			t_cyl.height = 0.15
			tine.mesh = t_cyl
			tine.position = Vector3(side * 0.036, -0.16, 0.0)
			tine.material_override = steel_mat
			turret.add_child(tine)

		# Sample caching tube carousel / transfer port
		var carousel = MeshInstance3D.new()
		var car_cyl = CylinderMesh.new()
		car_cyl.top_radius = 0.025
		car_cyl.bottom_radius = 0.025
		car_cyl.height = 0.06
		carousel.mesh = car_cyl
		carousel.rotation.z = PI / 2.0
		carousel.position = Vector3(0.068, 0.0, 0.0)
		carousel.material_override = steel_mat
		turret.add_child(carousel)
	else:
		# Spacecraft / Probe bus: side-hull mounting plate with deployable sampling arm
		var wall_bracket = MeshInstance3D.new()
		var brk_box = BoxMesh.new()
		brk_box.size = Vector3(0.02, 0.16, 0.16)
		wall_bracket.mesh = brk_box
		wall_bracket.position = Vector3(-0.01, 0.0, 0.0)
		wall_bracket.material_override = struct_mat
		wrapper.add_child(wall_bracket)

		var hinge = MeshInstance3D.new()
		var h_cyl = CylinderMesh.new()
		h_cyl.top_radius = 0.04
		h_cyl.bottom_radius = 0.04
		h_cyl.height = 0.08
		hinge.mesh = h_cyl
		hinge.position = Vector3(0.03, 0.0, 0.0)
		hinge.material_override = joint_mat
		wrapper.add_child(hinge)

		# Deployable sampling boom
		var p_end = Vector3(0.18, -0.22, 0.32)
		_create_arm_tube(wrapper, Vector3(0.03, 0.0, 0.0), p_end, 0.026, struct_mat)

		# Regolith coring & volatile sampling head
		var head = MeshInstance3D.new()
		var head_box = BoxMesh.new()
		head_box.size = Vector3(0.12, 0.12, 0.14)
		head.mesh = head_box
		head.position = p_end
		head.material_override = gold_mat
		wrapper.add_child(head)

		# Coring bit
		var drill_bit = MeshInstance3D.new()
		var d_cone = CylinderMesh.new()
		d_cone.top_radius = 0.008
		d_cone.bottom_radius = 0.025
		d_cone.height = 0.16
		drill_bit.mesh = d_cone
		drill_bit.position = p_end + Vector3(0.0, -0.12, 0.0)
		drill_bit.material_override = carbide_mat
		wrapper.add_child(drill_bit)

func _build_seismometer(comp_id: String) -> void:
	var compact_pos = Vector3(-0.35, 0.46, 0.2)
	var exploded_offset = Vector3(-0.9, 0.4, 0.9)

	if current_structure == StructureType.ROVER:
		compact_pos = Vector3(-0.24, 0.44, 0.15)
		exploded_offset = Vector3(-0.7, 0.5, 0.5)
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(-0.38, 0.55, 0.2)
		exploded_offset = Vector3(-1.0, 0.5, 0.8)

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)

	# Leveling plate
	var plate = MeshInstance3D.new()
	var p_box = BoxMesh.new()
	p_box.size = Vector3(0.18, 0.02, 0.18)
	plate.mesh = p_box
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.35, 0.38, 0.42)
	p_mat.metallic = 0.9
	plate.material_override = p_mat
	wrapper.add_child(plate)

	var dome = MeshInstance3D.new()
	var sp = SphereMesh.new()
	sp.radius = 0.13
	sp.height = 0.13
	dome.mesh = sp
	dome.position = Vector3(0.0, 0.065, 0.0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.65, 0.15)
	mat.metallic = 0.8
	dome.material_override = mat
	wrapper.add_child(dome)

func _build_main_engine(comp_id: String) -> void:
	var compact_pos = Vector3(0.0, 0.0, -0.62)
	var exploded_offset = Vector3(0.0, 0.0, -1.5)

	if current_structure == StructureType.ROVER:
		compact_pos = Vector3(0.0, 0.22, -0.72)
		exploded_offset = Vector3(0.0, 0.2, -1.3)
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(0.0, 0.0, -0.72)
		exploded_offset = Vector3(0.0, 0.0, -1.6)

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)

	# Gimbal thrust ring connecting to bulkhead
	var ring = MeshInstance3D.new()
	var r_cyl = CylinderMesh.new()
	r_cyl.top_radius = 0.18
	r_cyl.bottom_radius = 0.18
	r_cyl.height = 0.06
	ring.mesh = r_cyl
	ring.rotation.x = PI / 2.0
	ring.position = Vector3(0.0, 0.0, 0.18)
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.4, 0.42, 0.45)
	r_mat.metallic = 0.95
	ring.material_override = r_mat
	wrapper.add_child(ring)

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
	var compact_pos = Vector3(0.0, 0.0, -0.62)
	var exploded_offset = Vector3(0.0, 0.0, -1.5)

	if current_structure == StructureType.ROVER:
		compact_pos = Vector3(0.0, 0.22, -0.72)
		exploded_offset = Vector3(0.0, 0.2, -1.3)
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(0.0, 0.0, -0.72)
		exploded_offset = Vector3(0.0, 0.0, -1.6)

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)

	var ring = MeshInstance3D.new()
	var r_cyl = CylinderMesh.new()
	r_cyl.top_radius = 0.18
	r_cyl.bottom_radius = 0.18
	r_cyl.height = 0.06
	ring.mesh = r_cyl
	ring.rotation.x = PI / 2.0
	ring.position = Vector3(0.0, 0.0, 0.14)
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.4, 0.42, 0.45)
	r_mat.metallic = 0.95
	ring.material_override = r_mat
	wrapper.add_child(ring)

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
		Vector3(-0.47, 0.38, 0.48), Vector3(0.47, 0.38, 0.48),
		Vector3(-0.47, 0.38, -0.48), Vector3(0.47, 0.38, -0.48)
	]

	if current_structure == StructureType.ROVER:
		corners = [
			Vector3(-0.44, 0.38, 0.58), Vector3(0.44, 0.38, 0.58),
			Vector3(-0.44, 0.38, -0.58), Vector3(0.44, 0.38, -0.58)
		]
	elif current_structure == StructureType.DEEP_SPACE:
		corners = [
			Vector3(-0.54, 0.38, 0.55), Vector3(0.54, 0.38, 0.55),
			Vector3(-0.54, 0.38, -0.55), Vector3(0.54, 0.38, -0.55)
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
	var leg_mat = StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.92, 0.80, 0.22)
	leg_mat.metallic = 0.94
	leg_mat.roughness = 0.22

	var r_start = 0.44
	var y_start = -0.32
	var r_foot = 0.95
	var y_foot = -0.78

	if current_structure == StructureType.DEEP_SPACE:
		r_start = 0.54
		y_start = -0.45
		r_foot = 1.10
		y_foot = -0.92
	elif current_structure == StructureType.ROVER:
		r_start = 0.46
		y_start = 0.05
		r_foot = 0.85
		y_foot = -0.28

	var wrapper = _create_wrapper(comp_id, Vector3.ZERO, Vector3(0.0, -1.3, 0.0))
	var leg_angles = [PI / 4.0, 3.0 * PI / 4.0, 5.0 * PI / 4.0, 7.0 * PI / 4.0]
	for ang in leg_angles:
		var dir_x = cos(ang)
		var dir_z = sin(ang)

		var start_pos = Vector3(dir_x * r_start, y_start, dir_z * r_start)
		var foot_pos = Vector3(dir_x * r_foot, y_foot, dir_z * r_foot)
		var dist = start_pos.distance_to(foot_pos)

		var mount = Node3D.new()
		wrapper.add_child(mount)
		var dir = (foot_pos - start_pos).normalized()
		if dir.length_squared() > 0.001:
			var up = Vector3.UP if abs(dir.y) < 0.99 else Vector3.FORWARD
			mount.transform = Transform3D().looking_at(dir, up)
		mount.position = start_pos

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
	var compact_pos = Vector3(0.0, -0.3, 0.0)
	var exploded_offset = Vector3(0.0, -1.6, 0.0)
	var bot_r = 1.05

	if current_structure == StructureType.ROVER:
		compact_pos = Vector3(0.0, 0.15, 0.0)
		bot_r = 1.15
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(0.0, -0.45, 0.0)
		bot_r = 1.15

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)
	var shield = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = bot_r
	cone.height = 0.45
	shield.mesh = cone
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.22, 0.25) # PICA Heat Shield Dark
	mat.roughness = 0.88
	shield.material_override = mat
	wrapper.add_child(shield)

func _build_skycrane_stage(comp_id: String) -> void:
	var compact_pos = Vector3(0.0, 0.75, 0.0)
	var exploded_offset = Vector3(0.0, 1.5, 0.0)

	if current_structure == StructureType.ROVER:
		compact_pos = Vector3(0.0, 0.85, 0.0)
		exploded_offset = Vector3(0.0, 1.6, 0.0)

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)
	var crane = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.15, 0.16, 1.15)
	crane.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.74, 0.78)
	mat.metallic = 0.9
	crane.material_override = mat
	wrapper.add_child(crane)

	# 4 canted descent thruster nozzles on skycrane frame
	for c_pos in [Vector3(-0.5, -0.08, 0.5), Vector3(0.5, -0.08, 0.5), Vector3(-0.5, -0.08, -0.5), Vector3(0.5, -0.08, -0.5)]:
		var noz = MeshInstance3D.new()
		var n_cone = CylinderMesh.new()
		n_cone.top_radius = 0.03
		n_cone.bottom_radius = 0.08
		n_cone.height = 0.16
		noz.mesh = n_cone
		noz.position = c_pos
		var n_mat = StandardMaterial3D.new()
		n_mat.albedo_color = Color(0.3, 0.25, 0.2)
		n_mat.metallic = 0.95
		noz.material_override = n_mat
		wrapper.add_child(noz)

	# Descent bridle cables if rover
	if current_structure == StructureType.ROVER:
		var cable_mat = StandardMaterial3D.new()
		cable_mat.albedo_color = Color(0.85, 0.85, 0.85)
		cable_mat.metallic = 0.95
		for side_x in [-0.38, 0.38]:
			for side_z in [-0.42, 0.42]:
				var cable = MeshInstance3D.new()
				var c_cyl = CylinderMesh.new()
				c_cyl.top_radius = 0.008
				c_cyl.bottom_radius = 0.008
				c_cyl.height = 0.40
				cable.mesh = c_cyl
				cable.position = Vector3(side_x, -0.22, side_z)
				cable.material_override = cable_mat
				wrapper.add_child(cable)

func _build_battery_pack(comp_id: String) -> void:
	var compact_pos = Vector3(-0.46, -0.15, -0.2)
	var exploded_offset = Vector3(-1.0, -0.5, -0.6)

	if current_structure == StructureType.ROVER:
		compact_pos = Vector3(-0.43, 0.22, -0.15)
		exploded_offset = Vector3(-0.8, 0.2, -0.5)
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(-0.55, -0.12, -0.2)
		exploded_offset = Vector3(-1.2, -0.4, -0.6)

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)
	var bat = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.18, 0.24, 0.34)
	bat.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.42, 0.85) # Battery Blue
	mat.metallic = 0.7
	mat.roughness = 0.2
	bat.material_override = mat
	wrapper.add_child(bat)

func _build_avionics_box(comp_id: String) -> void:
	var compact_pos = Vector3(0.46, -0.15, -0.2)
	var exploded_offset = Vector3(0.9, -0.5, -0.6)

	if current_structure == StructureType.ROVER:
		compact_pos = Vector3(0.43, 0.22, -0.15)
		exploded_offset = Vector3(0.8, 0.2, -0.5)
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(0.55, -0.12, -0.2)
		exploded_offset = Vector3(1.2, -0.4, -0.6)

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)
	var avi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.18, 0.22, 0.28)
	avi.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.34, 0.38)
	mat.metallic = 0.8
	avi.material_override = mat
	wrapper.add_child(avi)

func _build_solid_state_recorder(comp_id: String) -> void:
	var compact_pos = Vector3(0.46, -0.15, 0.15)
	var exploded_offset = Vector3(0.9, -0.5, 0.5)

	if current_structure == StructureType.ROVER:
		compact_pos = Vector3(0.43, 0.22, 0.15)
		exploded_offset = Vector3(0.8, 0.2, 0.5)
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(0.55, -0.12, 0.15)
		exploded_offset = Vector3(1.2, -0.4, 0.5)

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)
	var sdr = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.16, 0.18, 0.24)
	sdr.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.80, 0.55) # High-speed memory teal/green
	mat.metallic = 0.75
	mat.roughness = 0.25
	sdr.material_override = mat
	wrapper.add_child(sdr)

func _build_lunar_micro_rover(comp_id: String) -> void:
	var compact_pos = Vector3(0.52, -0.15, 0.0)
	var exploded_offset = Vector3(1.4, -0.3, 0.0)

	if current_structure == StructureType.ROVER:
		# Rear deployable micro-scout carrier on the rover deck
		compact_pos = Vector3(0.0, 0.44, -0.42)
		exploded_offset = Vector3(0.0, 0.8, -1.2)
	elif current_structure == StructureType.DEEP_SPACE:
		compact_pos = Vector3(0.60, -0.15, 0.0)
		exploded_offset = Vector3(1.5, -0.3, 0.0)

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)

	# Deploy ramp/bracket
	var ramp = MeshInstance3D.new()
	var r_box = BoxMesh.new()
	r_box.size = Vector3(0.28, 0.02, 0.32)
	ramp.mesh = r_box
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.35, 0.38, 0.42)
	r_mat.metallic = 0.9
	ramp.material_override = r_mat
	wrapper.add_child(ramp)

	var chassis = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.24, 0.10, 0.28)
	chassis.mesh = box
	chassis.position = Vector3(0.0, 0.08, 0.0)
	var c_mat = StandardMaterial3D.new()
	c_mat.albedo_color = Color(0.88, 0.75, 0.2)
	c_mat.metallic = 0.85
	chassis.material_override = c_mat
	wrapper.add_child(chassis)

	var w_mat = StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.18, 0.18, 0.2)
	w_mat.metallic = 0.8
	var wheel_offsets = [
		Vector3(-0.13, 0.02, 0.11), Vector3(0.13, 0.02, 0.11),
		Vector3(-0.13, 0.02, -0.11), Vector3(0.13, 0.02, -0.11)
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
	var compact_pos = Vector3.ZERO
	var exploded_offset = Vector3(0.0, 0.0, 1.3)
	var tank_x = 0.48
	var tank_y = 0.05
	var tank_z = 0.25

	if current_structure == StructureType.ROVER:
		tank_x = 0.32
		tank_y = 0.44
		tank_z = -0.25
	elif current_structure == StructureType.DEEP_SPACE:
		tank_x = 0.56
		tank_y = 0.08
		tank_z = 0.0

	var wrapper = _create_wrapper(comp_id, compact_pos, exploded_offset)
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
		tank.position = Vector3(side * tank_x, tank_y, tank_z)
		tank.material_override = tank_mat
		wrapper.add_child(tank)
