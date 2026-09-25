extends RayCast3D

@export var interact_distance := 4.0
@export var echo_force := 1.8

func _ready() -> void:
    target_position = Vector3(0, 0, -interact_distance)
    enabled = true

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_E:
        try_interact()

func try_interact() -> void:
    force_raycast_update()
    if not is_colliding():
        print("Veyra interaction: nothing in range.")
        return

    var target := get_collider()
    if target and target.has_method("interact"):
        target.interact()
        print("Veyra interaction: interacted with ", target.name)
        return

    if target and target.has_method("apply_force"):
        var direction := -global_transform.basis.z
        target.apply_force(direction, echo_force)
        print("Force transferred into ", target.name)
        return

    if target and target.has_method("interact"):
        target.interact()
    else:
        print("Veyra: ", target.name if target else "unknown", " cannot be interacted with yet.")
