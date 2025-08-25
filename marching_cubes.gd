extends Node3D
class_name MarchingCubes

@export var width: int = 10
@export var height: int = 10
@export var resolution: float = 1.0
@export var height_threshold: float = 0.5
@export var visualize_noise: bool = false
@export var use_3d_noise: bool = false
@export var noise_scale: float = 1.0
@export var noise: FastNoiseLite

var heights := {}
var vertices: Array = []
var triangles: Array = []

var mesh: ArrayMesh

func _ready() -> void:
	var start_time = Time.get_ticks_msec()
	set_heights()
	march_cubes()
	set_mesh()

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.3, 0.1) # červená
	mat.metallic = 0.6
	mat.roughness = 0.0
	mesh_instance.material_override = mat
	add_child(mesh_instance)
	
	var end_time = Time.get_ticks_msec()
	print("Generování trvalo: ", end_time - start_time, " ms")


func set_heights():
	for x in range(width + 1):
		for y in range(height + 1):
			for z in range(width + 1):
				var pos = Vector3(x, y, z)
				heights[pos] = compute_height(x, y, z)


func get_height(pos: Vector3) -> float:
	return heights.get(pos, 0.0)
	

func compute_height(x: int, y: int, z: int) -> float:
	if use_3d_noise:
		# FastNoise vrací -1 až 1, přeškálujeme do 0..1
		return (noise.get_noise_3d(float(x)/width*noise_scale, float(y)/height*noise_scale, float(z)/width*noise_scale) + 1.0) / 2.0
	else:
		var current_height = height * ((noise.get_noise_2d(x * noise_scale, z * noise_scale) + 1.0)/2.0)
		var dist_to_surface = 0.0
		if y <= current_height - 0.5:
			dist_to_surface = 0.0
		elif y > current_height + 0.5:
			dist_to_surface = 1.0
		elif y > current_height:
			dist_to_surface = y - current_height
		else:
			dist_to_surface = current_height - y
		return dist_to_surface


func march_cubes() -> void:
	vertices.clear()
	triangles.clear()

	for x in range(width):
		for y in range(height):
			for z in range(width):
				var cube_corners = []
				for i in range(8):
					var corner = Vector3(x, y, z) + MarchingTable.corners[i]
					# zajistíme integer indexy
					var corner_pos = Vector3(int(corner.x), int(corner.y), int(corner.z))
					cube_corners.append(get_height(corner_pos))
				var config_index = get_configuration_index(cube_corners)
				if config_index != 0 and config_index != 255:
					march_cube(Vector3(x, y, z), cube_corners, config_index)


func march_cube(position: Vector3, cube_corners: Array, config_index: int) -> void:
	var edge_index = 0
	for t in range(5):
		for v in range(3):
			var tri_val = MarchingTable.triangles[config_index][edge_index]
			if tri_val == -1:
				return
			var edge_start = position + MarchingTable.edges[tri_val][0]
			var edge_end = position + MarchingTable.edges[tri_val][1]
			var vertex = (edge_start + edge_end) / 2.0
			vertices.append(vertex)
			triangles.append(vertices.size() - 1)
			edge_index += 1


func get_configuration_index(cube_corners: Array) -> int:
	var config_index = 0
	for i in range(8):
		if cube_corners[i] < height_threshold:
			config_index |= 1 << i
	return config_index


func set_mesh() -> void:
	var arr_mesh = ArrayMesh.new()
	var arr = []
	arr.resize(ArrayMesh.ARRAY_MAX)
	arr[ArrayMesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arr[ArrayMesh.ARRAY_INDEX] = PackedInt32Array(triangles)
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh = arr_mesh
