extends RigidBody3D
class_name PhysicsShip

@export var turn_speed := 2.0        # cílová úhlová rychlost (rad/s)
@export var thrust_force: float = 20.0     # síla dopředného tahu
@export var torque_force: float = 8.0      # točivý moment pro otáčení
@export var brake_factor: float = 0.98     # útlum rychlosti (simulace odporu)
@export var max_speed: float = 40.0        # maximální rychlost
@export var angular_accel: float = 8.0     # jak rychle dosahujeme cílové rychlosti
@export var angular_damping: float = 1.5   # dodatečné tlumení pro rychlé zastavení
@onready var camera: Camera3D = $Camera3D

var active: bool = false

func interact(activate: bool) -> void:
	camera.current = activate
	active = activate
	
func _ready() -> void:
	interact(false)
	

func _physics_process(delta: float) -> void:
	var input_dir := Vector3.ZERO

	if active:
		# Pohyb dopředu/dozadu
		if Input.is_action_pressed("move_forward"):
			input_dir.z -= 1.0
		if Input.is_action_pressed("move_backward"):
			input_dir.z += 1.0

		# Aplikuj dopřednou sílu
		if input_dir.z != 0.0:
			var forward := global_transform.basis.z
			var force := forward * thrust_force * input_dir.z
			if linear_velocity.length() < max_speed:
				apply_central_force(force)

		# Rotace (otáčení kolem osy Y)
		var input_turn := 0.0
		if Input.is_action_pressed("ui_left"):
			input_turn -= 1.0
		if Input.is_action_pressed("ui_right"):
			input_turn += 1.0
			
		# cílová úhlová rychlost (Y osa)
		var target_ang_y := input_turn * turn_speed
		var t: float = clamp(angular_accel * delta, 0.0, 1.0)
		var new_ang_y: float = lerp(angular_velocity.y, target_ang_y, t)
		
		 # aplikuj tlumení navíc když není vstup
		if input_turn == 0.0:
			# rychleji zastavíme
			new_ang_y = lerp(new_ang_y, 0.0, clamp(angular_damping * delta, 0.0, 1.0))

		angular_velocity.y = new_ang_y

		# volitelné: capnout max úhlovou rychlost
		var max_ang := 4.0
		angular_velocity.y = clamp(angular_velocity.y, -max_ang, max_ang)

	# Lehké tlumení, aby loď nezrychlovala do nekonečna
	linear_velocity *= 0.999
	angular_velocity *= 0.995
	
	print(str(global_position))
	print("rotation: " + str(global_rotation))
