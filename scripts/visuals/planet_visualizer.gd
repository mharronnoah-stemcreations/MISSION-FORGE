class_name PlanetVisualizer
extends Node3D

const StarfieldClass = preload("res://scripts/visuals/starfield.gd")

# PlanetVisualizer
# High-fidelity procedural planetary visualization system for MissionForge.
# Creates distinct aerospace environments for NASA targets:
# 1. Earth (TerraPulse-1): 705 km Sun-synchronous orbit ring, dynamic cloud & atmo layers.
# 2. Moon (Artemis Prospector): Shackleton Crater south-pole topography, harsh grazing polar sun,
#    basalt maria and highland regolith.
# 3. Mars (Ares Pathfinder): Jezero Crater hematite regolith, salmon/amber atmospheric dust haze,
#    and Planum Boreum polar ice cap.

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

var _current_phase: int = 0

func _ready() -> void:
	_rebuild_planet()

func set_mission_context(mission: MissionConfig, _spacecraft: SpacecraftConfig = null) -> void:
	if mission != null:
		planet_type = mission.destination
	_rebuild_planet()

func set_phase(phase_idx: int) -> void:
	_current_phase = phase_idx
	_update_environment_for_phase()

func _process(delta: float) -> void:
	if _planet_mesh_instance != null:
		_planet_mesh_instance.rotate_y(rotate_speed * delta)
	if _clouds_mesh_instance != null:
		_clouds_mesh_instance.rotate_y(rotate_speed * 1.35 * delta)

func _rebuild_planet() -> void:
	for child in get_children():
		child.queue_free()

	_planet_mesh_instance = null
	_clouds_mesh_instance = null
	_atmosphere_mesh_instance = null
	_orbit_ring_instance = null

	var sf = StarfieldClass.new()
	add_child(sf)

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
func _setup_earth_environment(_sphere: SphereMesh) -> void:
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

	# NASA Authentic 705 km Sun-Synchronous Orbit Trajectory Ring
	_setup_orbit_ring("Earth")

func _setup_orbit_ring(type: String) -> void:
	var ring_mesh = ImmediateMesh.new()
	_orbit_ring_instance = MeshInstance3D.new()
	_orbit_ring_instance.mesh = ring_mesh
	var ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# Reference unit direction from planet center to the satellite flight location
	var dir_sat = Vector3(0.0, 0.17503, 0.98456).normalized()
	var r_orb = radius * (1.0 + 705.0 / 6371.0)
	var inc_angle_deg = 10.5

	match type:
		"Earth":
			# NASA 705 km Sun-Synchronous Orbit (11.07% Earth radius altitude, 98.2° inclination)
			r_orb = radius * (1.0 + 705.0 / 6371.0)
			ring_mat.albedo_color = Color(0.0, 0.92, 1.0, 0.65)
			inc_angle_deg = 10.5
		"Moon":
			# NASA LRO 100 km Polar Mapping Orbit (5.76% Moon radius altitude, 90° inclination)
			r_orb = radius * (1.0 + 100.0 / 1737.4)
			ring_mat.albedo_color = Color(0.75, 0.92, 1.0, 0.55)
			inc_angle_deg = 0.0
		"Mars":
			# NASA MRO 255 km Science Orbit (7.52% Mars radius altitude, 93° inclination)
			r_orb = radius * (1.0 + 255.0 / 3389.5)
			ring_mat.albedo_color = Color(1.0, 0.68, 0.28, 0.65)
			inc_angle_deg = -5.0

	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_orbit_ring_instance.material_override = ring_mat

	# Construct exact orbital plane basis:
	# Orbit normal is orthogonal to dir_sat for any inclination angle
	var rad = deg_to_rad(inc_angle_deg)
	var orbit_normal = Vector3(cos(rad), -sin(rad) * dir_sat.z, sin(rad) * dir_sat.y).normalized()
	var tangent_vel = orbit_normal.cross(dir_sat).normalized()

	# vec_u coincides exactly with the satellite's position at angle 0!
	var vec_u = dir_sat * r_orb
	var vec_v = tangent_vel * r_orb

	ring_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var segments = 96
	for i in range(segments + 1):
		var angle = (float(i) / float(segments)) * TAU
		var pt = vec_u * cos(angle) + vec_v * sin(angle)
		ring_mesh.surface_add_vertex(pt)
	ring_mesh.surface_end()
	add_child(_orbit_ring_instance)

# ==============================================================================
# 2. ARTEMIS PROSPECTOR // LUNAR SOUTH-POLE
# ==============================================================================
func _setup_moon_environment(_sphere: SphereMesh) -> void:
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

	# NASA LRO 100 km Polar Mapping Orbit Trajectory Ring
	_setup_orbit_ring("Moon")

# ==============================================================================
# 3. ARES PATHFINDER // MARS JEZERO CRATER ENVIRONMENT
# ==============================================================================
func _setup_mars_environment(_sphere: SphereMesh) -> void:
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

	# NASA MRO 255 km Science Orbit Trajectory Ring
	_setup_orbit_ring("Mars")

# ==============================================================================
# PHASE-BASED ENVIRONMENT ADAPTATION
# ==============================================================================
func _update_environment_for_phase() -> void:
	if _orbit_ring_instance != null:
		if planet_type == "Earth":
			_orbit_ring_instance.visible = (_current_phase >= 1)
		else:
			# Visible during orbital survey (phase 1) prior to atmospheric entry / landing
			_orbit_ring_instance.visible = (_current_phase == 1)
