extends Node3D

@export var ground_color := Color(0.08, 0.12, 0.17, 1)
@export var accent_color := Color(0.15, 0.55, 1.0, 1)
@export_range(0, 3) var layout_style := 0


func _ready() -> void:
	_create_box(Vector3(32, 0.5, 24), Vector3(0, -0.35, -2), ground_color)
	match layout_style:
		0:
			_create_ring_of_columns(7, 7.5, 4.5)
		1:
			_create_steps()
		2:
			_create_arches()
		3:
			_create_floating_blocks()


func _process(delta: float) -> void:
	rotation.y += delta * 0.018


func _create_ring_of_columns(count: int, radius: float, height: float) -> void:
	for index in count:
		var angle := TAU * float(index) / float(count)
		var position := Vector3(sin(angle) * radius, height * 0.5, cos(angle) * radius - 2.0)
		_create_box(Vector3(0.7, height, 0.7), position, accent_color)


func _create_steps() -> void:
	for index in 7:
		var size := Vector3(4.5, 0.55, 2.4)
		var position := Vector3(-8.5 + index * 2.8, index * 0.38, -5.0 - index * 0.7)
		_create_box(size, position, accent_color.darkened(float(index) * 0.045))


func _create_arches() -> void:
	for side in [-1.0, 1.0]:
		_create_box(Vector3(0.8, 5.0, 0.8), Vector3(side * 5.0, 2.5, -4.0), accent_color)
	_create_box(Vector3(10.8, 0.8, 0.8), Vector3(0, 5.0, -4.0), accent_color)
	_create_box(Vector3(7.0, 0.35, 7.0), Vector3(0, 0.15, -4.0), accent_color.darkened(0.35))


func _create_floating_blocks() -> void:
	for index in 10:
		var angle := TAU * float(index) / 10.0
		var height := 1.2 + float(index % 4) * 1.1
		var position := Vector3(sin(angle) * 8.0, height, cos(angle) * 6.0 - 3.0)
		_create_box(Vector3(1.4, 0.35, 1.4), position, accent_color.lightened(float(index % 3) * 0.08))


func _create_box(size: Vector3, position: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.58
	material.metallic = 0.18
	material.emission_enabled = true
	material.emission = color.darkened(0.72)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = position
	add_child(mesh_instance)

