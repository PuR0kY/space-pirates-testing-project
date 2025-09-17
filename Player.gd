class_name Character
extends CharacterBody3D

@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var camera: Camera3D = $Head/Camera3D
@onready var head: Node3D = $Head
@onready var ray_cast: RayCast3D = $Head/Camera3D/RayCast3D

enum PlayerState { ON_FOOT, PILOTING, ON_SHIP }

const SPEED := 5.0
const JUMP := 4.5

var id: int
var state: PlayerState = PlayerState.ON_FOOT
var mouse_sens := 0.1
var camera_inp := Vector2.ZERO
var active: bool = true

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	id = randi() % 20000

func _physics_process(delta: float) -> void:
	if not active:
		return

	match state:
		PlayerState.ON_FOOT:
			_walk_mode(delta)
		PlayerState.ON_SHIP:
			_ship_walk_mode(delta)
		PlayerState.PILOTING:
			# pohyb řídí Ship
			pass

func _input(event: InputEvent) -> void:
	if not active:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_inp = event.relative * mouse_sens

func _walk_mode(delta: float) -> void:
	var dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(dir.x, 0, dir.y)).normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP

	move_and_slide()

	# interakce: nastup do lodi
	if ray_cast.is_colliding() and Input.is_action_just_pressed("interact"):
		var body = ray_cast.get_collider()
		if body is Ship and body.pilot == null:
			body.enter_pilot_seat(self)

func _ship_walk_mode(delta: float) -> void:
	# směrový vektor podle otočení hráče (rotate_y myší)
	var forward = global_transform.basis.z
	var right = global_transform.basis.x
	var dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (dir.x * right + dir.y * forward).normalized()
	
	# pohyb relativně k interiéru lodi
	global_position += direction * SPEED * delta
	
	# skok uvnitř lodi – čistě posun nahoru
	if Input.is_action_just_pressed("ui_accept"):
		global_position.y += JUMP * delta
		
		# interakce: nastup do lodi
	if ray_cast.is_colliding() and Input.is_action_just_pressed("interact"):
		var body = ray_cast.get_collider()
		if body is Ship and body.pilot == null:
			body.enter_pilot_seat(self)

func look_around() -> void:
	rotate_y(-deg_to_rad(camera_inp.x)) # horizontální otočení tělem
	head.rotate_x(-deg_to_rad(camera_inp.y)) # vertikální otočení hlavou
	head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)

func _process(delta: float) -> void:
	if not active:
		return
	look_around()
	camera_inp = Vector2.ZERO
