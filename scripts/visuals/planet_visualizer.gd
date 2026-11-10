class_name PlanetVisualizer
extends Node3D

# PlanetVisualizer
# Procedurally builds visually striking 3D planets (Earth, Moon, Mars)
# with atmospheric shading, cloud layers, and rotating planetary terminators.

@export var planet_type: String = "Earth": # "Earth", "Moon", "Mars"
	set(val):
		planet_type = val
		_rebuild_planet()

@export var radius: float = 2.0
@export var rotate_speed: float = 0.05

var _planet_mesh_instance: MeshInstance3D
var _clouds_mesh_instance: MeshInstance3D
var _atmosphere_mesh_instance: MeshInstance3D

func _ready() -> void:
	_rebuild_planet()

func _process(delta: float) -> void:
	if _planet_mesh_instance != null:
		_planet_mesh_instance.rotate_y(rotate_speed * delta)
	if _clouds_mesh_instance != null:
		_clouds_mesh_instance.rotate_y(rotate_speed * 1.35 * delta)

func _rebuild_planet() -> void:
	for child in get_children():
		child.queue_free()

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
			_setup_earth_materials(sphere)
		"Moon":
			_setup_moon_materials(sphere)
		"Mars":
			_setup_mars_materials(sphere)

func _setup_earth_materials(sphere: SphereMesh) -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.35, 0.65) # Deep ocean blue
	mat.roughness = 0.25
	mat.metallic = 0.1
	mat.rim_enabled = true
	mat.rim = 0.6
	mat.rim_tint = 0.5
	_planet_mesh_instance.material_override = mat

	# Add procedural continents using NoiseTexture2D
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.015
	noise.fractal_octaves = 4

	var noise_tex = NoiseTexture2D.new()
	noise_tex.width = 512
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.noise = noise
	
	# Gradient for oceans vs land
	var grad = Gradient.new()
	grad.set_color(0, Color(0.08, 0.25, 0.55)) # Ocean
	grad.add_point(0.48, Color(0.15, 0.45, 0.25)) # Coast/Grass
	grad.add_point(0.70, Color(0.45, 0.40, 0.22)) # Land/Mountain
	grad.add_point(0.92, Color(0.90, 0.95, 1.0))  # Polar snow
	noise_tex.color_ramp = grad
	mat.albedo_texture = noise_tex

	# Cloud layer
	_clouds_mesh_instance = MeshInstance3D.new()
	var cloud_sphere = SphereMesh.new()
	cloud_sphere.radius = radius * 1.018
	cloud_sphere.height = radius * 2.036
	cloud_sphere.radial_segments = 48
	cloud_sphere.rings = 24
	_clouds_mesh_instance.mesh = cloud_sphere

	var cloud_mat = StandardMaterial3D.new()
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	
	var cloud_noise = FastNoiseLite.new()
	cloud_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	cloud_noise.frequency = 0.02
	cloud_noise.fractal_octaves = 3
	var cloud_tex = NoiseTexture2D.new()
	cloud_tex.width = 512
	cloud_tex.height = 256
	cloud_tex.seamless = true
	cloud_tex.noise = cloud_noise
	
	var cloud_grad = Gradient.new()
	cloud_grad.set_color(0, Color(1, 1, 1, 0))
	cloud_grad.add_point(0.55, Color(1, 1, 1, 0))
	cloud_grad.add_point(0.75, Color(1, 1, 1, 0.7))
	cloud_tex.color_ramp = cloud_grad
	cloud_mat.albedo_texture = cloud_tex
	_clouds_mesh_instance.material_override = cloud_mat
	add_child(_clouds_mesh_instance)

	# Atmospheric cyan rim glow
	_atmosphere_mesh_instance = MeshInstance3D.new()
	var atmo_sphere = SphereMesh.new()
	atmo_sphere.radius = radius * 1.05
	atmo_sphere.height = radius * 2.10
	_atmosphere_mesh_instance.mesh = atmo_sphere
	var atmo_mat = StandardMaterial3D.new()
	atmo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	atmo_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	atmo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	atmo_mat.albedo_color = Color(0.2, 0.65, 1.0, 0.18)
	_atmosphere_mesh_instance.material_override = atmo_mat
	add_child(_atmosphere_mesh_instance)

func _setup_moon_materials(sphere: SphereMesh) -> void:
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
	grad.set_color(0, Color(0.28, 0.29, 0.31)) # Dark lunar basalt maria
	grad.add_point(0.45, Color(0.55, 0.56, 0.58)) # Highland regolith
	grad.add_point(0.85, Color(0.85, 0.86, 0.88)) # Fresh crater ejecta rays
	noise_tex.color_ramp = grad
	mat.albedo_texture = noise_tex

func _setup_mars_materials(sphere: SphereMesh) -> void:
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
	grad.set_color(0, Color(0.42, 0.18, 0.10)) # Dark basalt lowlands (Acidalia Planitia)
	grad.add_point(0.45, Color(0.80, 0.38, 0.18)) # Red hematite iron oxide plains
	grad.add_point(0.80, Color(0.92, 0.52, 0.28)) # Bright dust desert (Tharsis)
	grad.add_point(0.95, Color(0.96, 0.94, 0.92)) # Planum Boreum polar ice caps
	noise_tex.color_ramp = grad
	mat.albedo_texture = noise_tex

	# Hazy Martian orange/pink atmosphere
	_atmosphere_mesh_instance = MeshInstance3D.new()
	var atmo_sphere = SphereMesh.new()
	atmo_sphere.radius = radius * 1.035
	atmo_sphere.height = radius * 2.07
	_atmosphere_mesh_instance.mesh = atmo_sphere
	var atmo_mat = StandardMaterial3D.new()
	atmo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	atmo_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	atmo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	atmo_mat.albedo_color = Color(0.95, 0.55, 0.35, 0.14)
	_atmosphere_mesh_instance.material_override = atmo_mat
	add_child(_atmosphere_mesh_instance)
