class_name Player extends CharacterBody3D



@export_category("Player Settings")
@export var Move_Speed : float = 1.5
@export var Sprint_Speed : float = 10.0

@export var PlayerInventory : Array[Dictionary] = []

var active: bool = true

enum PlayerState { ON_FOOT, DRIVING }
var state: PlayerState = PlayerState.ON_FOOT
var current_ship: Ship = null
var saved_camera: Camera3D


@export_category("Inputs")
# @export var UserInputForward : String = &"ui_up"
# @export var UserInputBackward : String = &"ui_down"
# @export var UserInputLeft : String = &"ui_left"
# @export var UserInputRight : String = &"ui_right"

@export var InputDictionary : Dictionary = {
	"Forward": "ui_up",
	"Backward": "ui_down",
	"Left": "ui_left",
	"Right": "ui_right",
	"Jump": "ui_accept",
	"Escape": "ui_cancel",
	"Sprint": "ui_accept",
	"Interact": "ui_accept"
}
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D

@export_category("Mouse Settings")
@export_range(0.09, 0.1) var Mouse_Sens : float = 0.09
@export_range(1.0, 50.0) var Mouse_Smooth : float = 50.0

@export_category("Camera Settings")
@export_subgroup("Tilt Settings")
@export_range(0.0, 1.0) var TiltThreshhold : float = 0.2

# Onready
@onready var head : Node3D = $Head
@onready var camera : Camera3D = $Head/Camera3D
@onready var ltilt : Marker3D = $Tilt/LTilt
@onready var rtilt : Marker3D = $Tilt/RTilt


# Vectors
var direction : Vector3 = Vector3.ZERO
var Camera_Inp : Vector2 = Vector2()
var Rot_Vel : Vector2 = Vector2()

# Private
var _speed : float = Move_Speed
var _isMouseCaptured : bool = true

const JUMP_VELOCITY : float = 4.5

func enter_ship(ship: Ship):
	state = PlayerState.DRIVING
	current_ship = ship
	active = false  # vypne pohyb a input pro chůzi

func exit_ship():
	state = PlayerState.ON_FOOT
	current_ship = null
	active = true


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ltilt.rotation.z = TiltThreshhold
	rtilt.rotation.z = -TiltThreshhold

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Camera_Inp = event.relative

func _process(delta: float) -> void:
	if state == PlayerState.DRIVING and Input.is_action_just_pressed("ship_exit"):
		if current_ship:
			current_ship.exit_pilot()
		return

	if state == PlayerState.ON_FOOT:
		# tvůj původní movement/camera code
		pass
	
	# Camera Lock
	if Input.is_action_just_pressed("Escape") and _isMouseCaptured:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_isMouseCaptured = false
	elif Input.is_action_just_pressed("Escape") and not _isMouseCaptured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_isMouseCaptured = true

	# Camera Smooth look
	Rot_Vel = Rot_Vel.lerp(Camera_Inp * Mouse_Sens, delta * Mouse_Smooth)
	head.rotate_x(-deg_to_rad(Rot_Vel.y))
	rotate_y(-deg_to_rad(Rot_Vel.x))
	head.rotation.x = clamp(head.rotation.x, -1.5, 1.5)
	Camera_Inp = Vector2.ZERO

	camera_tilt(delta)
	
func try_enter_ship(ship: Node):
	if state != PlayerState.ON_FOOT:
		return
	current_ship = ship
	state = PlayerState.DRIVING
	active = false  # vypne pohyb hráče
	collision_shape_3d.disabled = true
	visible = false

	# Přepni kameru
	saved_camera = camera
	camera.current = false
	ship.get_node("InteriorRoot/PilotSeat/PilotCam").current = true

func exit_ship():
	if state != PlayerState.DRIVING:
		return
	var ship_cam = current_ship.get_node("InteriorRoot/PilotSeat/PilotCam") as Camera3D
	ship_cam.current = false
	saved_camera.current = true

	visible = true
	collision_shape_3d.disabled = false
	active = true
	state = PlayerState.ON_FOOT
	current_ship = null


func _physics_process(delta: float) -> void:
	
	match state:
		PlayerState.ON_FOOT:
			_process_on_foot(delta)
		PlayerState.DRIVING:
			_process_driving(delta)

	if not active:
		collision_shape_3d.disabled = active
		return
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	#	Modified standard input for smooth movements.
	var input_dir : Vector2 = Input.get_vector("Left", "Right", "Forward", "Backward")
	direction = lerp(direction,(transform.basis * Vector3(input_dir.x,0,input_dir.y)).normalized(), delta * 7.0)
	_speed = lerp(_speed, Move_Speed, min(delta * 5.0, 1.0))
	Sprint()
	if direction:
		velocity.x = direction.x * _speed
		velocity.z = direction.z * _speed
	else:
		velocity.x = move_toward(velocity.x,0,_speed)
		velocity.z = move_toward(velocity.z,0,_speed)
	
	move_and_slide()
	
func _process_on_foot(delta: float) -> void:
	if not active: return
	
	# tvůj původní pohybový kód sem (gravity, jump, sprint, move_and_slide...)

	# interakce se sedadlem
	if Input.is_action_just_pressed("ui_use"):
		var space_state = get_world_3d().direct_space_state
		var from = camera.global_transform.origin
		var to = from + -camera.global_transform.basis.z * 2.0  # 2 metry před kamerou
		var hit = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
		if hit and hit.collider and hit.collider.has_method("request_enter_pilot"):
			hit.collider.request_enter_pilot(self)  # loď si tě sama zavolá

func _process_driving(delta: float) -> void:
	if Input.is_action_just_pressed("ship_exit"):
		exit_ship()
		return
	# ovládání lodě předej shipu
	if current_ship and current_ship.has_method("apply_pilot_input"):
		current_ship.apply_pilot_input(delta)


func Sprint() -> void:
	if Input.is_action_pressed("Sprint"):
		_speed = lerp(_speed, Sprint_Speed, 0.1)
	else:
		_speed = lerp(_speed, Move_Speed, 0.1)

func camera_tilt(delta: float) -> void:
	#	Camera Tilt
	if Input.is_action_pressed("Left") and Input.is_action_pressed("Right"):
		camera.rotation.z = lerp_angle(camera.rotation.z, 0 , min(delta * 5.0,1.0))
	elif Input.is_action_pressed("Left"):
		camera.rotation.z = lerp_angle(camera.rotation.z, ltilt.rotation.z , min(delta * 5.0,1.0))
	elif Input.is_action_pressed("Right"):
		camera.rotation.z = lerp_angle(camera.rotation.z, rtilt.rotation.z , min(delta * 5.0,1.0))
	else:
		camera.rotation.z = lerp_angle(camera.rotation.z, 0 , min(delta * 5.0,1.0))
