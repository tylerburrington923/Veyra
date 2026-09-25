extends Node

## Conservative visual profile for Android.
## Physical RAM is intentionally not inferred from render-memory counters.
## The profile stays at LOW until a real device benchmark justifies promotion.

enum QualityTier { LOW, MEDIUM, HIGH }

@export var tier := QualityTier.LOW

func apply() -> void:
    RenderingServer.set_default_clear_color(Color(0.035, 0.055, 0.08, 1))

func get_world_view_distance() -> float:
    match tier:
        QualityTier.HIGH:
            return 180.0
        QualityTier.MEDIUM:
            return 120.0
        _:
            return 80.0

func get_resource_count(base_count: int) -> int:
    match tier:
        QualityTier.HIGH:
            return base_count
        QualityTier.MEDIUM:
            return maxi(20, int(base_count * 0.75))
        _:
            return maxi(16, int(base_count * 0.5))
