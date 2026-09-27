extends Node3D

## Deterministic presentation-only water foundation for Veyra.
var seed_value: int = 47291
var generated := false

func _ready() -> void:
    call_deferred("generate")

func configure(world_seed: int) -> void:
    seed_value = world_seed

func generate() -> void:
    if generated:
        return
    generated = true

func is_generated() -> bool:
    return generated
