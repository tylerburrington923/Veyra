extends RayCast3D

@export var interact_distance: float = 4.0
@export var echo_force: float = 1.8
@export var collision_mask_value: int = 0x7FFFFFFF

var target_label: Label
var last_target_name: String = ""
var last_target_type: String = "NONE"
var last_handler_name: String = ""

func _ready() -> void:
    target_position = Vector3(0, 0, -interact_distance)
    collision_mask = collision_mask_value
    collide_with_bodies = true
    collide_with_areas = true
    enabled = true
    target_label = get_node_or_null("../../MobileControls/TargetHUD") as Label
    _update_target_debug()

func _physics_process(_delta: float) -> void:
    _update_target_debug()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
        try_interact()

func try_interact() -> void:
    force_raycast_update()
    if not is_colliding():
        print("Veyra interaction: nothing in range.")
        _set_target_state("NONE", "", "")
        return

    var target: Node = get_collider() as Node
    var interactable: Node = _find_handler(target, "interact")
    if interactable:
        interactable.interact()
        print("Veyra interaction: interacted with ", interactable.name)
        _set_target_state(_classify_target(interactable), interactable.name, "interact()")
        return

    var physics_target: Node = _find_handler(target, "apply_force")
    if physics_target:
        var direction: Vector3 = -global_transform.basis.z
        physics_target.apply_force(direction, echo_force)
        print("Force transferred into ", physics_target.name)
        _set_target_state("PHYSICS", physics_target.name, "apply_force()")
        return

    var target_name: String = target.name if target else "unknown"
    var target_type: String = _classify_target(target)
    print("Veyra interaction: hit ", target_name, " but it has no interaction handler.")
    _set_target_state(target_type, target_name, "NONE")

func _update_target_debug() -> void:
    if not is_colliding():
        _set_target_state("NONE", "", "")
        return

    var target: Node = get_collider() as Node
    if not target:
        _set_target_state("UNKNOWN", "", "")
        return

    var interactable: Node = _find_handler(target, "interact")
    if interactable:
        _set_target_state(_classify_target(interactable), interactable.name, "interact()")
        return

    var physics_target: Node = _find_handler(target, "apply_force")
    if physics_target:
        _set_target_state("PHYSICS", physics_target.name, "apply_force()")
        return

    _set_target_state(_classify_target(target), target.name, "NONE")

func _set_target_state(target_type: String, target_name: String, handler: String) -> void:
    last_target_type = target_type
    last_target_name = target_name
    last_handler_name = handler
    if target_label:
        var distance_text: String = "--"
        if is_colliding():
            distance_text = "%.2f" % global_position.distance_to(get_collision_point())
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
