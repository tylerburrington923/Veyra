extends Node3D

## Deterministic placeholder terrain generator.
## The same seed will produce the same terrain on host and client.

@export var seed_value: int = 47291
@export var size := 60
@export var cell_size := 4.0
@export var height_scale := 2.5

func generate() -> void:
    var noise := FastNoiseLite.new()
    noise.seed = seed_value
    noise.frequency = 0.025

    for x in range(size):
        for z in range(size):
            var height := noise.get_noise_2d(x, z) * height_scale
            # Terrain visuals will replace this placeholder generator.
            # Keeping generation deterministic now gives Veyra a stable foundation.
