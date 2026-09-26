extends RayCast3D

## Interaction ray uses a dedicated target collision layer so terrain cannot
## occlude low resources, rocks, minerals, or other interactable objects.

const INTERACTION_LAYER := 2

@export var interact_distance: float = 6.0
@export var echo_force: float = 1.8

var target_label: Label
var interact_button: Button
var last_target_name: String = ""
var last_target_type: String = "NONE"
var last_handler_name: String = ""
var last_collision_point: Vector3 = Vector3.ZERO

func _ready() -> void:
    target_position = Vector3(0, 0, -interact_distance)
    collision_mask = 1 << (INTERACTION_LAYER - 1)
    collide_with_bodies = true
    collide_with_areas = true
    enabled = true
    target_label = get_node_or_null("../../MobileControls/TargetHUD") as Label
    interact_button = get_node_or_null("../../MobileControls/InteractButton") as Button
    _update_target_debug()

func _physics_process(_delta: float) -> void:
    _update_target_debug()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
        try_interact()

func _query_target() -> Dictionary:
    var viewport_camera := get_viewport().get_camera_3d()
    if not viewport_camera:
        return {}

    var origin: Vector3 = viewport_camera.global_position
    var direction: Vector3 = -viewport_camera.global_transform.basis.z.normalized()
    var endpoint: Vector3 = origin + direction * interact_distance

    var query := PhysicsRayQueryParameters3D.create(
        origin,
        endpoint,
        1 << (INTERACTION_LAYER - 1)
    )
    query.collide_with_bodies = true
    query.collide_with_areas = true

    var player := get_tree().get_first_node_in_group("local_player")
    if player is CollisionObject3D:
        query.exclude = [player.get_rid()]

    return get_world_3d().direct_space_state.intersect_ray(query)

func try_interact() -> void:
    var hit := _query_target()
    if hit.is_empty():
        print("Veyra interaction: nothing in range.")
        _set_target_state("NONE", "", "", Vector3.ZERO)
        return

    var target: Node = hit.get("collider") as Node
    var collision_point: Vector3 = hit.get("position", Vector3.ZERO)
    if not target:
        _set_target_state("UNKNOWN", "", "", collision_point)
        return

    var interactable: Node = _find_handler(target, "interact")
    if interactable:
        interactable.interact()
        print("Veyra interaction: interacted with ", interactable.name)
        _set_target_state(_classify_target(interactable), interactable.name, "interact()", collision_point)
        return

    var physics_target: Node = _find_handler(target, "apply_force")
    if physics_target:
        var viewport_camera := get_viewport().get_camera_3d()
        var direction := -viewport_camera.global_transform.basis.z.normalized() if viewport_camera else -global_transform.basis.z
        physics_target.apply_force(direction, echo_force)
        print("Force transferred into ", physics_target.name)
        _set_target_state("PHYSICS", physics_target.name, "apply_force()", collision_point)
        return

    _set_target_state(_classify_target(target), target.name, "NONE", collision_point)

func _update_target_debug() -> void:
    var hit := _query_target()
    if hit.is_empty():
        _set_target_state("NONE", "", "", Vector3.ZERO)
        return

    var target: Node = hit.get("collider") as Node
    var collision_point: Vector3 = hit.get("position", Vector3.ZERO)
    if not target:
        _set_target_state("UNKNOWN", "", "", collision_point)
        return

    var interactable: Node = _find_handler(target, "interact")
    if interactable:
        _set_target_state(_classify_target(interactable), interactable.name, "interact()", collision_point)
        return

    var physics_target: Node = _find_handler(target, "apply_force")
    if physics_target:
        _set_target_state("PHYSICS", physics_target.name, "apply_force()", collision_point)
        return

    _set_target_state(_classify_target(target), target.name, "NONE", collision_point)

func _set_target_state(target_type: String, target_name: String, handler: String, collision_point: Vector3) -> void:
    last_target_type = target_type
    last_target_name = target_name
    last_handler_name = handler
    last_collision_point = collision_point

    if interact_button:
        var actionable := handler != ""
        interact_button.disabled = not actionable
        interact_button.text = "PUSH" if handler == "apply_force()" else "USE"

    if target_label:
        var distance_text: String = "--"
        if target_type != "NONE":
            var camera := get_viewport().get_camera_3d()
            if camera:
                distance_text = "%.2f" % camera.global_position.distance_to(collision_point)
        target_label.text = "TARGET: %s\nNAME: %s\nDIST: %s\nHANDLER: %s" % [
            target_type,
            target_name if target_name != "" else "--",
            distance_text,
            handler if handler != "" else "--"
        ]

func _classify_target(node: Node) -> String:
    if not node:
        return "UNKNOWN"
    if node.is_in_group("resource_node") or node is VeyraResourceNode:
        return "RESOURCE"
    if node.name.to_lower().contains("terrain"):
        return "TERRAIN"
    if node.name.to_lower().contains("tree"):
        return "TREE"
    if node.name.to_lower().contains("rock"):
        return "ROCK"
    if node.name.to_lower().contains("mineral"):
        return "MINERAL"
    return "INTERACTABLE"

func _find_handler(start: Node, method_name: String) -> Node:
    var current: Node = start
    var depth: int = 0
    while current and depth < 8:
        if current.has_method(method_name):
            return current
        current = current.get_parent()
        depth += 1
    return null
