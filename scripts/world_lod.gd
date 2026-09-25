extends Node3D

## Lightweight distance-based visibility controller.
## Attach to decorative world objects, not gameplay-critical objects.

@export var visible_distance := 70.0

var target_camera: Camera3D

func _ready() -> void:
    target_camera = get_viewport().get_camera_3d()

func _process(_delta: float) -> void:
    if not is_instance_valid(target_camera):
        target_camera = get_viewport().get_camera_3d()
        return

    var distance := global_position.distance_to(target_camera.global_position)
    visible = distance <= visible_distance
