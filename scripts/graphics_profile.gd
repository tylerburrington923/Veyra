extends Node

## Device-aware visual settings for Veyra.
## 4 GB RAM is the baseline. Higher tiers may opt into more distance/detail.

enum QualityTier { LOW, MEDIUM, HIGH }

var tier := QualityTier.LOW
var ram_mb := 4096

func _ready() -> void:
    _detect_device()
    apply()

func _detect_device() -> void:
    ram_mb = int(Performance.get_monitor(Performance.RENDER_TOTAL_MEM_USED))
    # The renderer cannot reliably expose physical RAM on every Android device.
    # Start conservatively; quality can be raised later from an options menu.
    tier = QualityTier.LOW

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
