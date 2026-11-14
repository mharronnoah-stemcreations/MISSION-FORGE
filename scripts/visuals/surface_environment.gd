class_name SurfaceEnvironment
extends Node3D

# SurfaceEnvironment
# High-fidelity procedural planetary surface terrain system for MissionForge.
# Creates realistic landing ground environments for:
# 1. Mars (Ares Pathfinder / Jezero Crater Delta Fan):
#    - Oxidized hematite claystone & red regolith dunes
#    - Scattered basalt rocks, gravel fields, and delta sedimentary bedrock outcrop
#    - Distant Jezero Crater rim mesa hills and warm salmon/amber dust haze
#    - Parallel rocker-bogie wheel tread tracks
# 2. Moon (Artemis Prospector / Shackleton Crater Polar Rim):
#    - Basaltic titanium-rich gray regolith and micro-craters
#    - Jagged highland anorthosite ejecta boulders
#    - Stark 1.5° low-angle grazing polar sun with long dark shadows
#    - Pitch-black sky with starfield backdrop

var destination: String = "Mars"
var _ground_mesh: MeshInstance3D
var _bedrock_slab: MeshInstance3D
var _borehole_mesh: MeshInstance3D
var _target_ring: MeshInstance3D
var _wheel_tracks: Node3D
var _boulders_node: Node3D
var _horizon_node: Node3D
var _dust_cloud_mesh: MeshInstance3D

func setup_surface(dest: String) -> void:
	destination = dest
	for child in get_children():
		child.queue_free()

	_boulders_node = Node3D.new()
	_boulders_node.name = "Boulders"
	add_child(_boulders_node)

	_horizon_node = Node3D.new()
	_horizon_node.name = "HorizonRim"
	add_child(_horizon_node)

	_wheel_tracks = Node3D.new()
	_wheel_tracks.name = "WheelTracks"
	add_child(_wheel_tracks)

	var is_mars = (destination == "Mars")

	# 1. Vast Planetary Ground Plane (80m x 80m)
	_build_ground_terrain(is_mars)

	# 2. Sedimentary Bedrock Sampling Outcrop (in front of rover deck)
	_build_sampling_bedrock(is_mars)

	# 3. Scattered Natural Boulders and Rocks
	_build_scattered_rocks(is_mars)

	# 4. Distant Crater Rim Horizon Hills
	_build_crater_rim_horizon(is_mars)

	# 5. Wheel Tread Tracks in the Regolith
	_build_wheel_tracks(is_mars)

	# 6. Landing Blast Dust Ring
	_build_landing_dust_ring(is_mars)

# ==============================================================================
# GROUND TERRAIN
# ==============================================================================
func _build_ground_terrain(is_mars: bool) -> void:
	_ground_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(90.0, 90.0)
	plane.subdivide_width = 32
	plane.subdivide_depth = 32
	_ground_mesh.mesh = plane
	# Ground surface placed at Y = -0.33 (flush with bottom of 0.18m radius wheels)
	_ground_mesh.position = Vector3(0.0, -0.33, 0.0)

	var mat = StandardMaterial3D.new()
	if is_mars:
		mat.albedo_color = Color(0.76, 0.35, 0.18) # Martian Jezero hematite red-orange
		mat.roughness = 0.94
		mat.metallic = 0.04
		mat.rim_enabled = true
		mat.rim = 0.25
		mat.rim_tint = 0.6
	else:
		mat.albedo_color = Color(0.48, 0.50, 0.53) # Lunar titanium basalt regolith
		mat.roughness = 0.98
		mat.metallic = 0.06
		mat.rim_enabled = true
		mat.rim = 0.35
		mat.rim_tint = 0.2

	# Procedural granular noise texture for regolith grain
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_octaves = 3

	var noise_tex = NoiseTexture2D.new()
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.seamless = true
	noise_tex.noise = noise

	var grad = Gradient.new()
	if is_mars:
		grad.set_color(0, Color(0.68, 0.28, 0.14)) # Darker hollows / basalt sand
		grad.add_point(0.5, Color(0.78, 0.36, 0.18))
		grad.add_point(0.85, Color(0.88, 0.44, 0.24)) # Light dust dune crests
	else:
		grad.set_color(0, Color(0.38, 0.40, 0.42))
		grad.add_point(0.5, Color(0.48, 0.50, 0.53))
		grad.add_point(0.85, Color(0.62, 0.64, 0.68)) # Bright anorthosite ejecta
	noise_tex.color_ramp = grad
	mat.albedo_texture = noise_tex

	_ground_mesh.material_override = mat
	add_child(_ground_mesh)

# ==============================================================================
# SAMPLING BEDROCK OUTCROP
# ==============================================================================
func _build_sampling_bedrock(is_mars: bool) -> void:
	_bedrock_slab = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(2.8, 0.24, 2.4)
	_bedrock_slab.mesh = box
	_bedrock_slab.position = Vector3(-0.25, -0.42, 0.95)

	var b_mat = StandardMaterial3D.new()
	if is_mars:
		b_mat.albedo_color = Color(0.72, 0.32, 0.16) # Jezero Delta lacustrine siltstone
		b_mat.roughness = 0.90
		b_mat.metallic = 0.05
	else:
		b_mat.albedo_color = Color(0.50, 0.52, 0.56)
		b_mat.roughness = 0.95
		b_mat.metallic = 0.10
	_bedrock_slab.material_override = b_mat
	add_child(_bedrock_slab)

	# Target concentric target ring
	_target_ring = MeshInstance3D.new()
	var ring_cyl = CylinderMesh.new()
	ring_cyl.top_radius = 0.11
	ring_cyl.bottom_radius = 0.11
	ring_cyl.height = 0.005
	_target_ring.mesh = ring_cyl
	_target_ring.position = Vector3(-0.23, -0.305, 0.95)
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.22, 0.24, 0.28)
	r_mat.roughness = 0.85
	_target_ring.material_override = r_mat
	add_child(_target_ring)

	# Borehole cylinder that deepens during coring
	_borehole_mesh = MeshInstance3D.new()
	var hole = CylinderMesh.new()
	hole.top_radius = 0.025
	hole.bottom_radius = 0.025
	hole.height = 0.02
	_borehole_mesh.mesh = hole
	_borehole_mesh.position = Vector3(-0.23, -0.306, 0.95)
	var h_mat = StandardMaterial3D.new()
	h_mat.albedo_color = Color(0.06, 0.04, 0.03)
	_borehole_mesh.material_override = h_mat
	add_child(_borehole_mesh)

# ==============================================================================
# SCATTERED NATURAL ROCKS & BOULDERS
# ==============================================================================
func _build_scattered_rocks(is_mars: bool) -> void:
	var rock_mat = StandardMaterial3D.new()
	if is_mars:
		rock_mat.albedo_color = Color(0.42, 0.22, 0.16) # Weathered Martian dark basalt
		rock_mat.roughness = 0.94
	else:
		rock_mat.albedo_color = Color(0.35, 0.36, 0.38) # Shock-melted lunar basalt
		rock_mat.roughness = 0.96

	var rock_positions = [
		Vector3(-2.8, -0.22, 1.8), Vector3(3.2, -0.20, 2.4),
		Vector3(-1.6, -0.24, -2.2), Vector3(2.4, -0.22, -1.8),
		Vector3(-4.5, -0.15, 0.5), Vector3(4.8, -0.14, 1.2),
		Vector3(-3.5, -0.18, -4.2), Vector3(3.8, -0.18, -3.8),
		Vector3(0.8, -0.26, 3.8), Vector3(-1.2, -0.25, 4.2),
		Vector3(-6.2, -0.05, 5.5), Vector3(7.4, -0.02, 6.2),
		Vector3(-8.5, 0.10, -6.0), Vector3(9.2, 0.12, -7.5),
		Vector3(-12.0, 0.25, 8.0), Vector3(14.5, 0.30, 9.2),
		Vector3(-15.0, 0.40, -12.0), Vector3(16.0, 0.35, -14.0),
		Vector3(1.8, -0.25, 1.4), Vector3(-2.2, -0.26, -0.8)
	]

	for i in range(rock_positions.size()):
		var pos = rock_positions[i]
		var rock = MeshInstance3D.new()
		var b = BoxMesh.new()
		var sx = randf_range(0.25, 0.75)
		var sy = randf_range(0.18, 0.55)
		var sz = randf_range(0.25, 0.80)
		b.size = Vector3(sx, sy, sz)
		rock.mesh = b
		rock.position = pos
		rock.rotation.y = randf_range(0.0, TAU)
		rock.rotation.x = randf_range(-0.15, 0.15)
		rock.material_override = rock_mat
		_boulders_node.add_child(rock)

# ==============================================================================
# CRATER RIM HORIZON
# ==============================================================================
func _build_crater_rim_horizon(is_mars: bool) -> void:
	var rim_mat = StandardMaterial3D.new()
	if is_mars:
		rim_mat.albedo_color = Color(0.65, 0.28, 0.15) # Distant Jezero delta cliffs
		rim_mat.roughness = 0.98
	else:
		rim_mat.albedo_color = Color(0.30, 0.32, 0.35) # Shackleton crater rim ridge
		rim_mat.roughness = 0.98

	# Ring of 16 mountain / mesa peak ridges at ~40m distance
	var count = 16
	var radius_dist = 42.0
	for i in range(count):
		var angle = (float(i) / float(count)) * TAU
		var x = cos(angle) * radius_dist
		var z = sin(angle) * radius_dist
		var height = randf_range(5.0, 9.5)
		var width = randf_range(12.0, 18.0)

		var hill = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.8
		cyl.bottom_radius = width * 0.5
		cyl.height = height
		cyl.radial_segments = 12
		hill.mesh = cyl
		hill.position = Vector3(x, (height * 0.5) - 2.5, z)
		hill.rotation.y = angle + randf_range(-0.3, 0.3)
		hill.material_override = rim_mat
		_horizon_node.add_child(hill)

# ==============================================================================
# ROVER WHEEL TREAD TRACKS
# ==============================================================================
func _build_wheel_tracks(is_mars: bool) -> void:
	var track_mat = StandardMaterial3D.new()
	if is_mars:
		track_mat.albedo_color = Color(0.55, 0.22, 0.12, 0.85) # Compressed dark red soil
	else:
		track_mat.albedo_color = Color(0.32, 0.34, 0.36, 0.85)
	track_mat.roughness = 0.85
	track_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Left and Right tire tracks running back from rover wheels
	for offset_x in [-0.64, 0.64]:
		var track = MeshInstance3D.new()
		var plane = PlaneMesh.new()
		plane.size = Vector2(0.24, 6.0)
		track.mesh = plane
		track.position = Vector3(offset_x, -0.326, -3.0)
		track.material_override = track_mat
		_wheel_tracks.add_child(track)

# ==============================================================================
# LANDING BLAST DUST DISTURBANCE
# ==============================================================================
func _build_landing_dust_ring(is_mars: bool) -> void:
	var blast_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 2.4
	cyl.bottom_radius = 2.4
	cyl.height = 0.005
	blast_mesh.mesh = cyl
	blast_mesh.position = Vector3(0.0, -0.328, 0.0)

	var b_mat = StandardMaterial3D.new()
	if is_mars:
		b_mat.albedo_color = Color(0.60, 0.25, 0.14, 0.55) # Rocket plume swept regolith
	else:
		b_mat.albedo_color = Color(0.36, 0.38, 0.40, 0.55)
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blast_mesh.material_override = b_mat
	add_child(blast_mesh)

func get_borehole_mesh() -> MeshInstance3D:
	return _borehole_mesh

func get_bedrock_slab() -> MeshInstance3D:
	return _bedrock_slab
