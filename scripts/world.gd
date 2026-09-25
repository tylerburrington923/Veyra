extends Node3D

## Veyra world coordinator.
## Keeps the world seed authoritative and synchronizes deterministic generators.

@export var day_length_seconds: float = 600.0
@export var default_world_seed: int = 47291

var world_time: float = 0.0
var world_seed: int = 47291


func _ready() -> void:
	world_seed = default_world_seed

	if GameManager:
		world_seed = GameManager.world_seed

	_apply_seed_to_generators()
	print("Veyra world initialized. Seed: ", world_seed)


func _process(delta: float) -> void:
	if day_length_seconds <= 0.0:
		return

	world_time = fmod(world_time + delta, day_length_seconds)


func _apply_seed_to_generators() -> void:
	var generator := get_node_or_null("WorldGenerator")
	if generator:
		generator.seed_value = world_seed

	var foliage := get_node_or_null("Foliage")
	if foliage:
		foliage.seed_value = world_seed

	var detail := get_node_or_null("WorldDetail")
	if detail:
		detail.seed_value = world_seed


func get_world_time() -> float:
	return world_time


func get_world_state() -> Dictionary:
	return {
		"seed": world_seed,
		"world_time": world_time,
		"version": 1
	}
