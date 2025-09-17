extends Node3D
@onready var ship: PhysicsShip = $ship
@onready var player: Player = $Player

var active: bool = false

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Interact"):
		active = !active
		ship.interact(active)
		player.interact(!active)
		
func _physics_process(delta: float) -> void:
	if active:
		player.global_transform.origin = ship.global_transform.origin
