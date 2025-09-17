extends CharacterBody3D
class_name Player

var run_speed = 5.5
var speed = run_speed
var walk_speed = 3

var camera_inp := Vector2.ZERO
var active: bool = true

func interact(activate: bool) -> void:
	%Camera3D.current = activate
	active = activate


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	interact(true)

func _input(event: InputEvent) -> void:
	if not active:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_inp = event.relative * 0.5

func _walk_mode(delta: float) -> void:
	var dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	print(str(dir))
	var direction = (global_basis * Vector3(dir.x, 0, dir.y)).normalized()
	velocity.x = direction.x * 5.0
	velocity.z = direction.z * 5.0
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = 6.0

	move_and_slide()

func _physics_process(delta: float) -> void:
	if not active:
		return
	
	_walk_mode(delta)
	look_around()
	camera_inp = Vector2.ZERO
	
func look_around() -> void:
	rotate_y(-deg_to_rad(camera_inp.x)) # horizontální otočení tělem
