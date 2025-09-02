class_name Ship
extends CharacterBody3D

var pilot: Player = null
var players_ship_proxies: Dictionary = {}
var players_controlling_proxies: Dictionary = {}

@onready var pilot_cam: Camera3D = $PilotCam
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
@onready var hull_collision: CollisionShape3D = $CollisionShape3D

var thrust = 0.0
const THRUST_FORCE := 120.0
const ROT_SPEED := 0.8
const DAMPING := 0.9
@export var rotation_speed: float = 0.003

# --- Input ---
func _input(event):
	if pilot == null:
		return
	
	if event is InputEventMouseMotion:
		# pitch (nahoru/dolů) kolem LOKÁLNÍ osy X (nos lodi)
		rotate_object_local(Vector3.RIGHT, -event.relative.y * rotation_speed)

		# roll (naklánění vlevo/vpravo) kolem LOKÁLNÍ Z
		rotate_object_local(Vector3.FORWARD, -event.relative.x * rotation_speed)
		
	if Input.is_action_just_pressed("interact"):
		if pilot != null:
			_leave_pilot_seat()

# --- Physics ---
func _physics_process(delta: float) -> void:
	# pohyb lodi podle pilota
	if pilot != null:
		thrust = Input.get_action_strength("thrust_up") - Input.get_action_strength("thrust_down")
	var forward = -transform.basis.z
	velocity += forward * thrust * THRUST_FORCE * delta
	translate(velocity * delta)
	velocity *= DAMPING


# --- Hull detection ---
func _on_hull_body_entered(body: Node3D) -> void:
	if thrust > 0:
		return
	if body is Player and not players_ship_proxies.has((body as Player).id) and (body as Player).active:
		var duplicate := body.duplicate()
		add_child(duplicate)
		duplicate.visible = false
		print("Added proxy: " + str(body.id))
		players_ship_proxies[body.id] = duplicate
		_possess_copy(body)

func _on_hull_body_exited(body: Node3D) -> void:
	if thrust > 0:
		return
	if body is Player and players_ship_proxies.has((body as Player).id) and (body as Player).active:
		_posses_original_player(body)

		if get_children().has(body):
			remove_child(body)
			print("Removed proxy: " + str((body as Player).id))
			players_ship_proxies.erase((body as Player).id)

# --- PROXY MANAGMENT ---
# Posses a ship based copy(proxy) of player
func _possess_copy(player: Player) -> void:
	# Set player as inactive
	var p = player
	print("Copy possesed! Added player: " + str(player.id))
	players_controlling_proxies[p.id] = p
	player.camera.current = false
	player.visible = false
	player.active = false
	
	# create player's duplicate as child of ship
	var proxy = players_ship_proxies[p.id]
	proxy.state = 2 # WANDERING
	proxy.position = $InteriorRoot/PilotSeat.position
	proxy.camera.current = true
	proxy.visible = true
	proxy.active = true
	proxy.id = p.id
	
# Possesses original player's character
func _posses_original_player(proxy: Player) -> void:
	var player_char: Player = players_controlling_proxies[proxy.id]
	proxy.camera.current = false
	proxy.visible = false
	proxy.active = false
	
	player_char.camera.current = true
	player_char.visible = true
	player_char.active = true
	player_char.state = 0 # ON FOOT
	player_char.global_position = proxy.global_position
	print("Original player Possesed! Removed tracking of: " + str(proxy.id))
	players_controlling_proxies.erase(proxy.id)
	
	
func _leave_pilot_seat():
	var ex_pilot = pilot
	pilot = null
	_possess_copy(ex_pilot)
	
func enter_pilot_seat(player: Player):
	pilot = player
	player.state = 1 # PILOTING
	player.camera.current = false
	player.active = false
	
	pilot_cam.current = true
