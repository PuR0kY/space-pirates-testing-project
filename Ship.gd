class_name Ship
extends Node3D

@export var thrust_force: float = 120.0
@export var rotation_speed: float = 0.003
@export var damping: float = 0.9

var velocity: Vector3 = Vector3.ZERO
var thrust: float = 0.0

var pilot: Character = null
var original_parent: Node = null

@onready var pilot_cam: Camera3D = $PilotCam
@onready var hull_collision: CollisionShape3D = $CollisionShape3D
@onready var interior_root: Node3D = $InteriorRoot
@onready var pilot_seat: Node3D = $InteriorRoot/PilotSeat
@onready var seat: MeshInstance3D = $InteriorRoot/PilotSeat/Seat

# --- Input ---
func _input(event):
	if pilot == null:
		return
	
	if event is InputEventMouseMotion:
		# pitch (nahoru/dolů) kolem lokální osy X
		rotate_object_local(Vector3.RIGHT, -event.relative.y * rotation_speed)
		# roll (naklánění vlevo/vpravo) kolem lokální Z
		rotate_object_local(Vector3.FORWARD, -event.relative.x * rotation_speed)
		
	if Input.is_action_just_pressed("ui_accept"):
		_leave_pilot_seat()

# --- Physics ---
func _physics_process(delta: float) -> void:
	# pohyb lodi podle pilota
	if pilot != null:
		thrust = Input.get_action_strength("thrust_up") - Input.get_action_strength("thrust_down")
	else:
		thrust = 0.0

	var forward = -transform.basis.z
	velocity += forward * thrust * thrust_force * delta
	translate(velocity * delta)
	#velocity *= damping

# --- Seat management ---
func enter_pilot_seat(player: Character):
	pilot = player
	player.camera.current = false
	player.reparent(pilot_seat)
	player.global_transform = pilot_seat.global_transform
	player.state = Character.PlayerState.PILOTING
	player.active = false
	pilot_cam.current = true
	print("Player entered pilot seat: ", player.id)

func _leave_pilot_seat():
	if pilot == null:
		return
	
	var ex_pilot = pilot
	ex_pilot.camera.current = false
	ex_pilot.reparent(interior_root)
	ex_pilot.camera.current = true
	ex_pilot.global_transform.origin = pilot_seat.global_transform.origin
	ex_pilot.state = Character.PlayerState.ON_FOOT
	ex_pilot.active = true
	
	pilot_cam.current = false
	pilot = null
	print("Pilot left the seat")
	
func _on_hull_body_entered(body: Node3D) -> void:
	if body == pilot:
		return
	if body is Character and body.state == Character.PlayerState.ON_FOOT:
		# hráč vstoupil do interiéru
		if original_parent == null:
			original_parent = body.get_parent()
		body.reparent(interior_root)
		body.state = Character.PlayerState.ON_SHIP
		print("Player entered ship hull: ", body.id)


func _on_hull_body_exited(body: Node3D) -> void:
	if body == pilot:
		return
	if body is Character and body.state == Character.PlayerState.ON_SHIP:
		# hráč vystoupil z interiéru zpět do světa
		body.reparent(original_parent)
		body.state = Character.PlayerState.ON_FOOT
		print("Player left ship hull: ", body.id)
