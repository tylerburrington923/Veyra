extends RayCast3D

## Proximity-based interaction target.
## The node remains attached to the camera for UI/input compatibility, but
## targeting is centered on the player instead of requiring a camera ray hit.

const INTERACTION_LAYER := 2
const PROXIMITY_RADIUS := 5.5
const MAX_HANDLER_DEPTH := 8

@export var interact_distance: float = PROXIMITY_RADIUS
@export var resonance_strength: float = 1.8
@export var target_update_interval: float = 0.1

var target_label: Label
var interact_button: Button
var last_target_name: String = ""
var last_target_type: String = "NONE"
var last_handler_name: String = ""
var last_collision_point: Vector3 = Vector3.ZERO
var _target_update_accumulator: float = 0.0
var _proximity_shape: SphereShape3D


func _ready() -> void:
    target_position = Vector3(0, 0, -interact_distance)
    collision_mask = 1 << (INTERACTION_LAYER - 1)
    collide_with_bodies = true
    collide_with_areas = true
    enabled = true

    _proximity_shape = SphereShape3D.new()
    _proximity_shape.radius = PROXIMITY_RADIUS

    target_label = get_node_or_null("../../MobileControls/TargetHUD") as Label
    interact_button = get_node_or_null("../../MobileControls/InteractButton") as Button
    _update_target_debug()


func _physics_process(delta: float) -> void:
    _target_update_accumulator += delta
    if _target_update_accumulator < target_update_interval:
        return
    _target_update_accumulator = 0.0
    _update_target_debug()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
        try_interact()


func _query_target() -> Dictionary:
    var player := get_tree().get_first_node_in_group("local_player") as Node3D
    if not player:
        return {}

    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = _proximity_shape
    query.transform = Transform3D(Basis.IDENTITY, player.global_position)
    query.collision_mask = 1 << (INTERACTION_LAYER - 1)
    query.collide_with_bodies = true
    query.collide_with_areas = true

    if player is CollisionObject3D:
        query.exclude = [player.get_rid()]

    var hits := get_world_3d().direct_space_state.intersect_shape(query, 24)
    var best := {}
    var best_distance := INF

    for hit in hits:
        var collider := hit.get("collider") as Node
        if not collider:
            continue

        var handler := _find_handler(collider, "interact")
        if not handler:
            handler = _find_handler(collider, "resonate")
        if not handler:
            continue

        var handler_position: Vector3 = player.global_position
        if handler is Node3D:
            handler_position = (handler as Node3D).global_position
        var distance: float = player.global_position.distance_to(handler_position)
        if distance < best_distance:
            best_distance = distance
            best = hit.duplicate(true)
            best["handler"] = handler
            best["distance"] = distance

    return best


func try_interact() -> void:
    var hit := _query_target()
    if hit.is_empty():
        print("Veyra interaction: nothing in proximity.")
        _set_target_state("NONE", "", "", Vector3.ZERO)
        return

    var target := hit.get("collider") as Node
    var handler := hit.get("handler") as Node
    var collision_point: Vector3 = Vector3.ZERO
    var raw_position: Variant = hit.get("position", null)
    if raw_position is Vector3:
        collision_point = raw_position
    elif handler is Node3D:
        collision_point = (handler as Node3D).global_position
    if not handler:
        _set_target_state("UNKNOWN", target.name if target else "", "", collision_point)
        return

    if handler.has_method("interact"):
        handler.interact()
        print("Veyra interaction: interacted with ", handler.name)
        _set_target_state(_classify_target(handler), handler.name, "interact()", collision_point)
        return

    if handler.has_method("resonate"):
        handler.resonate(resonance_strength)
        _set_target_state(_classify_target(handler), handler.name, "resonate()", collision_point)


func _update_target_debug() -> void:
    var hit := _query_target()
    if hit.is_empty():
        _set_target_state("NONE", "", "", Vector3.ZERO)
        return

    var handler := hit.get("handler") as Node
    var collision_point: Vector3 = Vector3.ZERO
    var raw_position: Variant = hit.get("position", null)
    if raw_position is Vector3:
        collision_point = raw_position
    elif handler is Node3D:
        collision_point = (handler as Node3D).global_position
    if not handler:
        _set_target_state("UNKNOWN", "", "", collision_point)
        return

    var action: String = ""
    if handler.has_method("interact"):
        action = "interact()"
    elif handler.has_method("resonate"):
        action = "resonate()"
    _set_target_state(_classify_target(handler), handler.name, action, collision_point)


func _set_target_state(target_type: String, target_name: String, handler: String, collision_point: Vector3) -> void:
    last_target_type = target_type
    last_target_name = target_name
    last_handler_name = handler
    last_collision_point = collision_point

    if interact_button:
        var actionable := handler != ""
        interact_button.disabled = not actionable
        interact_button.text = "GATHER" if target_type == "RESOURCE" else "USE"

    if target_label:
        var distance_text := "--"
        if target_type != "NONE":
            var player := get_tree().get_first_node_in_group("local_player") as Node3D
            if player and collision_point != Vector3.ZERO:
                distance_text = "%.2f" % player.global_position.distance_to(collision_point)
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
    var depth := 0
    while current and depth < MAX_HANDLER_DEPTH:
        if current.has_method(method_name):
            return current
        current = current.get_parent()
        depth += 1
    return null
