class_name PlanetVisualizer
extends Node3D

# PlanetVisualizer
# High-fidelity procedural planetary visualization system for MissionForge.
# Creates distinct aerospace environments for NASA targets:
# 1. Earth (TerraPulse-1): 705 km Sun-synchronous orbit ring, sensor footprint swath cone, dynamic cloud & atmo layers.
# 2. Moon (Artemis Prospector): Shackleton Crater south-pole topography, harsh grazing polar sun (1.5°),
#    pitch-black 40K Permanently Shadowed Regions (PSRs), landing site beacons, and 4-wheel lunar micro-rover.
# 3. Mars (Ares Pathfinder): Jezero Crater hematite regolith, salmon/amber atmospheric dust haze, rock fields,
#    and 6-wheel rocker-bogie astrobiology rover.

@export var planet_type: String = "Earth": # "Earth", "Moon", "Mars"
	set(val):
		planet_type = val
		_rebuild_planet()

@export var radius: float = 3.5
@export var rotate_speed: float = 0.03

# Specialized visual layers
var _planet_mesh_instance: MeshInstance3D
var _clouds_mesh_instance: MeshInstance3D
var _atmosphere_mesh_instance: MeshInstance3D
var _orbit_ring_instance: MeshInstance3D
var _swath_cone_instance: MeshInstance3D
var _surface_terrain_node: Node3D
var _surface_rover_node: Node3D

var _current_phase: int = 0
var _has_rover: bool = false
var _has_lander: bool = false
var _swath_pulse: float = 0.0

func _ready() -> void:
	_rebuild_planet()

func set_mission_context(mission: MissionConfig, spacecraft: SpacecraftConfig) -> void:
	if mission != null:
		planet_type = mission.destination
	if spacecraft != null:
		_has_rover = spacecraft.has_component("micro_rover") or spacecraft.has_component("mars_rover_chassis")
		_has_lander = spacecraft.has_component("landing_legs") or spacecraft.has_component("sky_crane") or spacecraft.has_component("airbag_system")
	_rebuild_planet()

func set_phase(phase_idx: int) -> void:
	_current_phase = phase_idx
	_update_environment_for_phase()

func _process(delta: float) -> void:
	if _planet_mesh_instance != null:
		_planet_mesh_instance.rotate_y(rotate_speed * delta)
	if _clouds_mesh_instance != null:
		_clouds_mesh_instance.rotate_y(rotate_speed * 1.35 * delta)

	# Pulse Earth sensor ground swath cone
	if _swath_cone_instance != null and _swath_cone_instance.visible:
		_swath_pulse += delta * 2.0
		var alpha = 0.18 + sin(_swath_pulse) * 0.06
		var mat = _swath_cone_instance.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = alpha

func _rebuild_planet() -> void:
	for child in get_children():
		child.queue_free()

	_planet_mesh_instance = null
	_clouds_mesh_instance = null
	_atmosphere_mesh_instance = null
	_orbit_ring_instance = null
	_swath_cone_instance = null
	_surface_terrain_node = null
	_surface_rover_node = null

	_planet_mesh_instance = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	_planet_mesh_instance.mesh = sphere
	add_child(_planet_mesh_instance)

	match planet_type:
		"Earth":
			_setup_earth_environment(sphere)
		"Moon":
			_setup_moon_environment(sphere)
		"Mars":
			_setup_mars_environment(sphere)

	_update_environment_for_phase()

# ==============================================================================
# 1. TERRAPULSE-1 // EARTH OBSERVATION ENVIRONMENT
# ==============================================================================
func _setup_earth_environment(sphere: SphereMesh) -> void:
	# Ocean base material with specular gloss
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.32, 0.62)
	mat.roughness = 0.22
	mat.metallic = 0.08
	mat.rim_enabled = true
	mat.rim = 0.65
	mat.rim_tint = 0.5
	_planet_mesh_instance.material_override = mat

	# Procedural continents texture
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.015
	noise.fractal_octaves = 4

	var noise_tex = NoiseTexture2D.new()
	noise_tex.width = 512
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.noise = noise

	var grad = Gradient.new()
	grad.set_color(0, Color(0.06, 0.22, 0.48)) # Deep trench
	grad.add_point(0.46, Color(0.12, 0.42, 0.24)) # Coastal land
	grad.add_point(0.72, Color(0.42, 0.38, 0.20)) # Highland/Deserts
	grad.add_point(0.92, Color(0.92, 0.96, 1.0))  # Arctic/Antarctic ice sheets
	noise_tex.color_ramp = grad
	mat.albedo_texture = noise_tex

	# Rotating cloud deck
	_clouds_mesh_instance = MeshInstance3D.new()
	var cloud_sphere = SphereMesh.new()
	cloud_sphere.radius = radius * 1.016
	cloud_sphere.height = radius * 2.032
	cloud_sphere.radial_segments = 48
	cloud_sphere.rings = 24
	_clouds_mesh_instance.mesh = cloud_sphere

	var cloud_mat = StandardMaterial3D.new()
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.58)

	var cloud_noise = FastNoiseLite.new()
	cloud_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	cloud_noise.frequency = 0.022
	cloud_noise.fractal_octaves = 3
	var cloud_tex = NoiseTexture2D.new()
	cloud_tex.width = 512
	cloud_tex.height = 256
	cloud_tex.seamless = true
	cloud_tex.noise = cloud_noise

	var cloud_grad = Gradient.new()
	cloud_grad.set_color(0, Color(1, 1, 1, 0))
	cloud_grad.add_point(0.52, Color(1, 1, 1, 0))
	cloud_grad.add_point(0.76, Color(1, 1, 1, 0.72))
	cloud_tex.color_ramp = cloud_grad
	cloud_mat.albedo_texture = cloud_tex
	_clouds_mesh_instance.material_override = cloud_mat
	add_child(_clouds_mesh_instance)

	# Atmospheric Rayleigh scattering rim glow
	_atmosphere_mesh_instance = MeshInstance3D.new()
	var atmo_sphere = SphereMesh.new()
	atmo_sphere.radius = radius * 1.048
	atmo_sphere.height = radius * 2.096
	_atmosphere_mesh_instance.mesh = atmo_sphere
	var atmo_mat = StandardMaterial3D.new()
	atmo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	atmo_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	atmo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	atmo_mat.albedo_color = Color(0.18, 0.65, 1.0, 0.22)
	_atmosphere_mesh_instance.material_override = atmo_mat
	add_child(_atmosphere_mesh_instance)

	# 705 km Sun-Synchronous Orbit Trajectory Ring
	_setup_earth_orbit_ring()

	# Sensor ground swath imaging cone
	_setup_earth_swath_cone()

func _setup_earth_orbit_ring() -> void:
	var ring_mesh = ImmediateMesh.new()
	_orbit_ring_instance = MeshInstance3D.new()
	_orbit_ring_instance.mesh = ring_mesh
	var ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.0, 0.88, 1.0, 0.45)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_orbit_ring_instance.material_override = ring_mat

	ring_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var segments = 72
	var r_orb = radius + 0.95 # Orbit height above Earth
	for i in range(segments + 1):
		var angle = (float(i) / float(segments)) * TAU
		# Polar inclination (~98 degrees representation)
		var px = cos(angle) * r_orb
		var py = sin(angle) * r_orb * 0.95
		var pz = sin(angle) * r_orb * 0.32
		ring_mesh.surface_add_vertex(Vector3(px, py, pz))
	ring_mesh.surface_end()
	add_child(_orbit_ring_instance)

func _setup_earth_swath_cone() -> void:
	_swath_cone_instance = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.04
	cone.bottom_radius = 0.75
	cone.height = 1.3
	cone.radial_segments = 24
	_swath_cone_instance.mesh = cone

	var swath_mat = StandardMaterial3D.new()
	swath_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	swath_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	swath_mat.albedo_color = Color(0.0, 0.95, 0.65, 0.20)
	swath_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_swath_cone_instance.material_override = swath_mat
	_swath_cone_instance.position = Vector3(0.0, 0.2, 0.5)
	_swath_cone_instance.rotation.x = -PI / 3.2
	add_child(_swath_cone_instance)

# ==============================================================================
# 2. ARTEMIS PROSPECTOR // LUNAR SOUTH-POLE & SHACKLETON CRATER
# ==============================================================================
func _setup_moon_environment(sphere: SphereMesh) -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.68, 0.70, 0.72)
	mat.roughness = 0.95
	mat.metallic = 0.05
	mat.rim_enabled = true
	mat.rim = 0.35
	mat.rim_tint = 0.2
	_planet_mesh_instance.material_override = mat

	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.035
	noise.cellular_jitter = 0.8

	var noise_tex = NoiseTexture2D.new()
	noise_tex.width = 512
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.noise = noise

	var grad = Gradient.new()
	grad.set_color(0, Color(0.24, 0.25, 0.27)) # Basalt maria / crater shadows
	grad.add_point(0.45, Color(0.55, 0.56, 0.58)) # Highland regolith
	grad.add_point(0.85, Color(0.85, 0.86, 0.88)) # Fresh impact ejecta rays
	noise_tex.color_ramp = grad
	mat.albedo_texture = noise_tex

	# Build Shackleton Crater localized landing environment
	_build_shackleton_crater_environment()

func _build_shackleton_crater_environment() -> void:
	_surface_terrain_node = Node3D.new()
	_surface_terrain_node.position = Vector3(0.0, -1.2, 1.2)
	_surface_terrain_node.visible = false # Activated during descent/operations
	add_child(_surface_terrain_node)

	# Shackleton Crater Rim Terrain
	var terrain_mi = MeshInstance3D.new()
	var terrain_mesh = CylinderMesh.new()
	terrain_mesh.top_radius = 2.4
	terrain_mesh.bottom_radius = 2.8
	terrain_mesh.height = 0.6
	terrain_mesh.radial_segments = 32
	terrain_mi.mesh = terrain_mesh

	var t_mat = StandardMaterial3D.new()
	t_mat.albedo_color = Color(0.48, 0.49, 0.52)
	t_mat.roughness = 0.95
	terrain_mi.material_override = t_mat
	_surface_terrain_node.add_child(terrain_mi)

	# Deep 40K Permanently Shadowed Region (PSR) Crater Floor
	var psr_mi = MeshInstance3D.new()
	var psr_mesh = CylinderMesh.new()
	psr_mesh.top_radius = 1.3
	psr_mesh.bottom_radius = 1.1
	psr_mesh.height = 0.4
	psr_mi.mesh = psr_mesh
	psr_mi.position = Vector3(0.0, -0.25, 0.0)

	var psr_mat = StandardMaterial3D.new()
	psr_mat.albedo_color = Color(0.04, 0.04, 0.06) # Pitch-black cryogenic cold trap
	psr_mat.roughness = 1.0
	psr_mi.material_override = psr_mat
	_surface_terrain_node.add_child(psr_mi)

	# High-Rim Landing Beacon Marker
	var beacon = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(0.12, 0.5, 0.12)
	beacon.mesh = b_mesh
	beacon.position = Vector3(0.85, 0.4, 0.6)
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.0, 0.95, 1.0)
	b_mat.emission_enabled = true
	b_mat.emission = Color(0.0, 0.8, 1.0)
	b_mat.emission_energy_multiplier = 2.0
	beacon.material_override = b_mat
	_surface_terrain_node.add_child(beacon)

	# Deploy 4-Wheel Lunar Micro-Rover on illuminated crater rim
	_build_lunar_micro_rover()

func _build_lunar_micro_rover() -> void:
	_surface_rover_node = Node3D.new()
	_surface_rover_node.position = Vector3(0.65, 0.35, 0.8)
	_surface_terrain_node.add_child(_surface_rover_node)

	# Rover Gold Kapton Chassis
	var chassis_mi = MeshInstance3D.new()
	var ch_box = BoxMesh.new()
	ch_box.size = Vector3(0.28, 0.12, 0.36)
	chassis_mi.mesh = ch_box
	var ch_mat = StandardMaterial3D.new()
	ch_mat.albedo_color = Color(0.92, 0.72, 0.15) # Gold MLI
	ch_mat.metallic = 0.9
	ch_mat.roughness = 0.25
	chassis_mi.material_override = ch_mat
	_surface_rover_node.add_child(chassis_mi)

	# Top Solar Panel
	var panel_mi = MeshInstance3D.new()
	var p_box = BoxMesh.new()
	p_box.size = Vector3(0.26, 0.02, 0.32)
	panel_mi.mesh = p_box
	panel_mi.position = Vector3(0.0, 0.07, 0.0)
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.08, 0.12, 0.32) # Dark blue solar cell
	p_mat.metallic = 0.6
	p_mat.roughness = 0.2
	panel_mi.material_override = p_mat
	_surface_rover_node.add_child(panel_mi)

	# 4 Wire-Mesh Wheels
	var wheel_offsets = [
		Vector3(-0.16, -0.05, -0.14),
		Vector3(0.16, -0.05, -0.14),
		Vector3(-0.16, -0.05, 0.14),
		Vector3(0.16, -0.05, 0.14)
	]
	var w_mat = StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.3, 0.32, 0.35)
	w_mat.metallic = 0.8
	w_mat.roughness = 0.4

	for offset in wheel_offsets:
		var w_mi = MeshInstance3D.new()
		var w_cyl = CylinderMesh.new()
		w_cyl.top_radius = 0.06
		w_cyl.bottom_radius = 0.06
		w_cyl.height = 0.04
		w_mi.mesh = w_cyl
		w_mi.rotation.z = PI / 2.0
		w_mi.position = offset
		w_mi.material_override = w_mat
		_surface_rover_node.add_child(w_mi)

# ==============================================================================
# 3. ARES PATHFINDER // MARS JEZERO CRATER & ASTROBIOLOGY ROVER
# ==============================================================================
func _setup_mars_environment(sphere: SphereMesh) -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.38, 0.18)
	mat.roughness = 0.85
	mat.metallic = 0.05
	mat.rim_enabled = true
	mat.rim = 0.5
	mat.rim_tint = 0.6
	_planet_mesh_instance.material_override = mat

	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 4

	var noise_tex = NoiseTexture2D.new()
	noise_tex.width = 512
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.noise = noise

	var grad = Gradient.new()
	grad.set_color(0, Color(0.42, 0.18, 0.10)) # Acidalia Planitia dark basalt
	grad.add_point(0.45, Color(0.80, 0.38, 0.18)) # Hematite iron oxide plains
	grad.add_point(0.80, Color(0.92, 0.52, 0.28)) # Tharsis dust dunes
	grad.add_point(0.95, Color(0.96, 0.94, 0.92)) # Planum Boreum ice cap
	noise_tex.color_ramp = grad
	mat.albedo_texture = noise_tex

	# Hazy Martian salmon/amber dust atmosphere
	_atmosphere_mesh_instance = MeshInstance3D.new()
	var atmo_sphere = SphereMesh.new()
	atmo_sphere.radius = radius * 1.036
	atmo_sphere.height = radius * 2.072
	_atmosphere_mesh_instance.mesh = atmo_sphere
	var atmo_mat = StandardMaterial3D.new()
	atmo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	atmo_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	atmo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	atmo_mat.albedo_color = Color(0.95, 0.56, 0.36, 0.18)
	_atmosphere_mesh_instance.material_override = atmo_mat
	add_child(_atmosphere_mesh_instance)

	_build_jezero_crater_environment()

func _build_jezero_crater_environment() -> void:
	_surface_terrain_node = Node3D.new()
	_surface_terrain_node.position = Vector3(0.0, -1.2, 1.2)
	_surface_terrain_node.visible = false
	add_child(_surface_terrain_node)

	# Jezero Crater Clay/Carbonate Ancient Lakebed
	var terrain_mi = MeshInstance3D.new()
	var terrain_mesh = CylinderMesh.new()
	terrain_mesh.top_radius = 2.6
	terrain_mesh.bottom_radius = 3.0
	terrain_mesh.height = 0.5
	terrain_mesh.radial_segments = 32
	terrain_mi.mesh = terrain_mesh

	var t_mat = StandardMaterial3D.new()
	t_mat.albedo_color = Color(0.72, 0.32, 0.16)
	t_mat.roughness = 0.92
	terrain_mi.material_override = t_mat
	_surface_terrain_node.add_child(terrain_mi)

	# Scattered Jezero Basalt Boulders
	var rock_coords = [
		Vector3(-0.8, 0.28, -0.5),
		Vector3(1.1, 0.26, 0.3),
		Vector3(-0.4, 0.27, 0.9),
		Vector3(0.7, 0.27, -0.9)
	]
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.38, 0.24, 0.18)
	r_mat.roughness = 0.95

	for rc in rock_coords:
		var rock = MeshInstance3D.new()
		var r_box = BoxMesh.new()
		r_box.size = Vector3(0.18, 0.12, 0.16)
		rock.mesh = r_box
		rock.position = rc
		rock.material_override = r_mat
		_surface_terrain_node.add_child(rock)

	# Build 6-Wheel Rocker-Bogie Mars Exploration Rover
	_build_mars_rocker_bogie_rover()

func _build_mars_rocker_bogie_rover() -> void:
	_surface_rover_node = Node3D.new()
	_surface_rover_node.position = Vector3(0.0, 0.35, 0.3)
	_surface_terrain_node.add_child(_surface_rover_node)

	# Warm Electronics Box (WEB) Chassis
	var chassis_mi = MeshInstance3D.new()
	var ch_box = BoxMesh.new()
	ch_box.size = Vector3(0.42, 0.18, 0.52)
	chassis_mi.mesh = ch_box
	var ch_mat = StandardMaterial3D.new()
	ch_mat.albedo_color = Color(0.85, 0.86, 0.88) # Thermal white paint
	ch_mat.metallic = 0.3
	ch_mat.roughness = 0.4
	chassis_mi.material_override = ch_mat
	_surface_rover_node.add_child(chassis_mi)

	# Remote Sensing Mast & Mastcam
	var mast_mi = MeshInstance3D.new()
	var m_cyl = CylinderMesh.new()
	m_cyl.top_radius = 0.025
	m_cyl.bottom_radius = 0.025
	m_cyl.height = 0.35
	mast_mi.mesh = m_cyl
	mast_mi.position = Vector3(0.12, 0.25, 0.18)
	var m_mat = StandardMaterial3D.new()
	m_mat.albedo_color = Color(0.2, 0.22, 0.25)
	mast_mi.material_override = m_mat
	_surface_rover_node.add_child(mast_mi)

	var head_mi = MeshInstance3D.new()
	var h_box = BoxMesh.new()
	h_box.size = Vector3(0.12, 0.06, 0.08)
	head_mi.mesh = h_box
	head_mi.position = Vector3(0.12, 0.44, 0.18)
	head_mi.material_override = m_mat
	_surface_rover_node.add_child(head_mi)

	# 6 Cleated Aluminum Wheels (Rocker-Bogie configuration)
	var wheel_offsets = [
		Vector3(-0.25, -0.06, -0.22), # Front Left
		Vector3(0.25, -0.06, -0.22),  # Front Right
		Vector3(-0.27, -0.06, 0.0),    # Mid Left
		Vector3(0.27, -0.06, 0.0),     # Mid Right
		Vector3(-0.25, -0.06, 0.22),  # Rear Left
		Vector3(0.25, -0.06, 0.22)   # Rear Right
	]
	var w_mat = StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.45, 0.47, 0.50)
	w_mat.metallic = 0.8
	w_mat.roughness = 0.3

	for offset in wheel_offsets:
		var w_mi = MeshInstance3D.new()
		var w_cyl = CylinderMesh.new()
		w_cyl.top_radius = 0.07
		w_cyl.bottom_radius = 0.07
		w_cyl.height = 0.05
		w_mi.mesh = w_cyl
		w_mi.rotation.z = PI / 2.0
		w_mi.position = offset
		w_mi.material_override = w_mat
		_surface_rover_node.add_child(w_mi)

# ==============================================================================
# PHASE-BASED ENVIRONMENT ADAPTATION
# ==============================================================================
func _update_environment_for_phase() -> void:
	# Phase 0: Launch / Ascent
	# Phase 1: Cruise / Injection
	# Phase 2: Arrival / Orbit Insertion / Descent
	# Phase 3: Operational Survey / Surface Operations
	# Phase 4: Data Downlink
	# Phase 5: Mission Evaluation

	if planet_type == "Earth":
		# Earth is always orbital: show orbit ring and swath cone during operations
		if _orbit_ring_instance != null:
			_orbit_ring_instance.visible = (_current_phase >= 1)
		if _swath_cone_instance != null:
			_swath_cone_instance.visible = (_current_phase == 3) # Operations phase
	else:
		# Moon or Mars: surface terrain and rovers activate during Descent (2) and Surface Ops (3, 4)
		var is_surface_phase = (_current_phase >= 2)
		if _surface_terrain_node != null:
			_surface_terrain_node.visible = is_surface_phase
		if _surface_rover_node != null:
			_surface_rover_node.visible = is_surface_phase and _has_rover
