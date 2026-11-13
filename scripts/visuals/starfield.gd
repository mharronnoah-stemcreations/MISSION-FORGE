class_name Starfield
extends Node3D

# Starfield
# High-performance procedural 3D celestial starfield for MissionForge.
# Generates 1,200 stars distributed across a deep-space sphere with authentic
# stellar classifications, varying magnitudes, and gentle celestial rotation.

@export var star_count: int = 1200
@export var radius_min: float = 40.0
@export var radius_max: float = 85.0
@export var drift_speed: float = 0.0025

var _multimesh_instance: MultiMeshInstance3D

func _ready() -> void:
	_build_starfield()

func _build_starfield() -> void:
	_multimesh_instance = MultiMeshInstance3D.new()
	_multimesh_instance.name = "StarsMultiMesh"
	add_child(_multimesh_instance)

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = star_count

	# Use lightweight low-poly 3D spheres for celestial points
	var s_mesh = SphereMesh.new()
	s_mesh.radius = 0.06
	s_mesh.height = 0.12
	s_mesh.radial_segments = 4
	s_mesh.rings = 2
	mm.mesh = s_mesh

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_multimesh_instance.material_override = mat

	var rng = RandomNumberGenerator.new()
	rng.seed = 42 # Deterministic distribution

	for i in range(star_count):
		# Uniform sphere distribution
		var theta = rng.randf() * TAU
		var phi = acos(rng.randf_range(-1.0, 1.0))
		var r = rng.randf_range(radius_min, radius_max)

		var pos = Vector3(
			sin(phi) * cos(theta),
			cos(phi),
			sin(phi) * sin(theta)
		) * r

		var roll = rng.randf()
		var star_scale: float
		var col: Color

		if roll < 0.65:
			# Faint background star (65%)
			star_scale = rng.randf_range(0.4, 0.8)
			var a = rng.randf_range(0.40, 0.75)
			if rng.randf() < 0.7:
				col = Color(0.85, 0.92, 1.0, a) # Pale blue-white
			else:
				col = Color(1.0, 0.95, 0.85, a) # Pale warm white
		elif roll < 0.92:
			# Medium bright navigation star (27%)
			star_scale = rng.randf_range(0.9, 1.8)
			var a = rng.randf_range(0.80, 0.98)
			var spec = rng.randf()
			if spec < 0.4:
				col = Color(0.75, 0.88, 1.0, a) # Class O/B Blue
			elif spec < 0.75:
				col = Color(1.0, 1.0, 1.0, a)    # Class A Pure White
			else:
				col = Color(1.0, 0.90, 0.72, a) # Class G Warm
		else:
			# Prominent bright beacon / red giant / supergiant (8%)
			star_scale = rng.randf_range(2.0, 3.4)
			var spec = rng.randf()
			if spec < 0.4:
				col = Color(0.65, 0.88, 1.0, 1.0) # Bright cyan-blue
			elif spec < 0.7:
				col = Color(1.0, 1.0, 1.0, 1.0)    # Brilliant white
			else:
				col = Color(1.0, 0.68, 0.42, 1.0) # Orange/Red Giant

		var basis = Basis().scaled(Vector3.ONE * star_scale)
		mm.set_instance_transform(i, Transform3D(basis, pos))
		mm.set_instance_color(i, col)

	_multimesh_instance.multimesh = mm

func _process(delta: float) -> void:
	rotate_y(drift_speed * delta)
