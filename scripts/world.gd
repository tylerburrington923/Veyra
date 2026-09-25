extends Node3D

@export var day_length_seconds := 600.0
var world_time := 0.0

func _ready() -> void:
    print("Veyra world initialized.")
    print("Networking foundation will be added before online gameplay.")

func _process(delta: float) -> void:
    world_time = fmod(world_time + delta, day_length_seconds)

func get_world_time() -> float:
    return world_time
