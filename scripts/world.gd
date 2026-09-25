extends Node3D

@export var day_length_seconds := 600.0
var world_time := 0.0
var world_seed := 47291

func _ready() -> void:
    print("Veyra world initialized.")
    print("World seed: ", world_seed)

func _process(delta: float) -> void:
    world_time = fmod(world_time + delta, day_length_seconds)

func get_world_time() -> float:
    return world_time

func get_world_state() -> Dictionary:
    return {
        "seed": world_seed,
        "world_time": world_time,
        "version": 1
    }
