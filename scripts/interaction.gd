extends RayCast3D

@export var interact_distance: float = 4.0
@export var echo_force: float = 1.8

func _ready() -> void:
    target_position = Vector3(0, 0, -interact_distance)
    enabled = true

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
        try_interact()

func try_interact() -> void:
    force_raycast_update()
    if not is_colliding():
        print("Veyra interaction: nothing in range.")
        return

    var target: Node = get_collider() as Node
    var interactable: Node = _find_handler(target, "interact")
    if interactable:
        interactable.interact()
        print("Veyra interaction: interacted with ", interactable.name)
        return

    var physics_target: Node = _find_handler(target, "apply_force")
    if physics_target:
        var direction := -global_transform.basis.z
        physics_target.apply_force(direction, echo_force)
        print("Force transferred into ", physics_target.name)
        return

    print("Veyra interaction: hit ", target.name if target else "unknown", " but it has no interaction handler.")

func _find_handler(start: Node, method_name: String) -> Node:
    var current: Node = start
    var depth: int = 0
    while current and depth < 4:
        if current.has_method(method_name):
            return current
        current = current.get_parent()
        depth += 1
    return null
