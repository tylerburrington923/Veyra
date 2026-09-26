extends RayCast3D

## Camera-centered interaction selector.
## Direct camera hits are preferred. Fallback candidates are selected by
## screen-space relevance, distance, and line of sight so large world objects
## do not require the player to stand on an exact invisible interaction point.

const INTERACTION_LAYER := 2
const RAY_DISTANCE := 6.0
const MAX_TARGET_DISTANCE := 5.5
const MAX_SCREEN_RADIUS := 0.62
const MAX_HANDLER_DEPTH := 8

@export var interact_distance: float = MAX_TARGET_DISTANCE
@export var resonance_strength: float = 1.8
@export var target_update_interval: float = 0.08

var target_label: Label
var interact_button: Button
var last_target_name: String = ""
var last_target_type: String = "NONE"
var last_handler_name: String = ""
var last_collision_point: Vector3 = Vector3.ZERO
var _target_update_accumulator := 0.0

func _ready() -> void:
	interact_distance = MAX_TARGET_DISTANCE
	target_position = Vector3(0, 0, -RAY_DISTANCE)
	collision_mask = 1 << (INTERACTION_LAYER - 1)
	collide_with_bodies = true
	collide_with_areas = true
	enabled = true

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
	var camera := get_viewport().get_camera_3d()
	if not player or not camera:
		return {}

	# First choice: exactly what the camera is pointing at.
	force_raycast_update()
	if is_colliding():
		var ray_collider := get_collider() as Node
		var ray_handler := _find_handler(ray_collider, "interact")
		if not ray_handler:
			ray_handler = _find_handler(ray_collider, "resonate")
		if ray_handler:
			var point := _get_interaction_point(ray_handler, get_collision_point())
			if player.global_position.distance_to(point) <= MAX_TARGET_DISTANCE:
				return {
					"collider": ray_collider,
					"handler": ray_handler,
					"position": point,
					"distance": player.global_position.distance_to(point),
					"screen_score": 0.0
				}

	# Fallback: gather interactables around the player, but choose by where
	# they appear on screen instead of by raw world-space angle.
	var shape := SphereShape3D.new()
	shape.radius = MAX_TARGET_DISTANCE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, player.global_position)
	query.collision_mask = 1 << (INTERACTION_LAYER - 1)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]

	var hits := get_world_3d().direct_space_state.intersect_shape(query, 32)
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_center := viewport_size * 0.5
	var best := {}
	var best_score := INF
	var seen_handlers: Dictionary = {}

	for hit in hits:
		var collider := hit.get("collider") as Node
		if not collider:
			continue

		var handler := _find_handler(collider, "interact")
		if not handler:
			handler = _find_handler(collider, "resonate")
		if not handler or seen_handlers.has(handler.get_instance_id()):
			continue
		seen_handlers[handler.get_instance_id()] = true

		var point := _get_interaction_point(handler, Vector3.ZERO)
		var distance := player.global_position.distance_to(point)
		if distance <= 0.05 or distance > MAX_TARGET_DISTANCE:
			continue
		if camera.is_position_behind(point):
			continue

		var screen_position := camera.unproject_position(point)
		var screen_offset := screen_position.distance_to(screen_center)
		var normalized_screen_offset := screen_offset / maxf(1.0, viewport_size.y)
		if normalized_screen_offset > MAX_SCREEN_RADIUS:
			continue

		if not _has_line_of_sight(camera.global_position, point, player, handler):
			continue

		# Screen center dominates. Distance breaks ties without forcing
		# the player into an exact interaction position.
		var score := normalized_screen_offset * 8.0 + distance * 0.035
		if score < best_score:
			best_score = score
			best = {
				"collider": collider,
				"handler": handler,
				"position": point,
				"distance": distance,
				"screen_score": normalized_screen_offset
			}

	return best

func try_interact() -> void:
	var hit := _query_target()
	if hit.is_empty():
		_set_target_state("NONE", "", "", Vector3.ZERO)
		return

	var handler := hit.get("handler") as Node
	var collision_point: Vector3 = hit.get("position", Vector3.ZERO)
	if not handler:
		_set_target_state("UNKNOWN", "", "", collision_point)
		return

	if handler.has_method("interact"):
		handler.interact()
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
	var point: Vector3 = hit.get("position", Vector3.ZERO)
	if not handler:
		_set_target_state("UNKNOWN", "", "", point)
		return

	var action := "interact()" if handler.has_method("interact") else "resonate()" if handler.has_method("resonate") else ""
	_set_target_state(_classify_target(handler), handler.name, action, point)

func _set_target_state(target_type: String, target_name: String, handler: String, collision_point: Vector3) -> void:
	last_target_type = target_type
	last_target_name = target_name
	last_handler_name = handler
	last_collision_point = collision_point

	if interact_button:
		var actionable := handler != ""
		interact_button.disabled = not actionable
		interact_button.text = _get_action_label(target_type)

	if target_label:
		var has_target := target_type != "NONE" and handler != ""
		target_label.visible = has_target
		if has_target:
			var player := get_tree().get_first_node_in_group("local_player") as Node3D
			var distance_text := "--"
			if player:
				distance_text = "%.1f m" % player.global_position.distance_to(collision_point)
			target_label.text = "%s  •  %s\n%s" % [
				_get_action_label(target_type),
				target_name if target_name != "" else "Unknown",
				distance_text
			]
func _get_action_label(target_type: String) -> String:
	match target_type:
		"RESOURCE":
			return "GATHER"
		"ANOMALY":
			return "RESONATE"
		_:
			return "USE"

func _get_interaction_point(handler: Node, fallback: Vector3) -> Vector3:
	if handler.has_method("get_interaction_point"):
		return handler.get_interaction_point()
	if handler is Node3D:
		return (handler as Node3D).global_position + Vector3.UP * 0.6
	return fallback

func _has_line_of_sight(origin: Vector3, target: Vector3, player: Node3D, handler: Node) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1 | 2)
	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var blocker := result.get("collider") as Node
	return blocker == handler or _find_handler(blocker, "interact") == handler or _find_handler(blocker, "resonate") == handler

func _classify_target(node: Node) -> String:
	if not node:
		return "UNKNOWN"
	if node.is_in_group("resource_node"):
		return "RESOURCE"
	if node.is_in_group("anomaly"):
		return "ANOMALY"
	var lower := node.name.to_lower()
	if lower.contains("terrain"):
		return "TERRAIN"
	if lower.contains("tree"):
		return "TREE"
	if lower.contains("rock"):
		return "ROCK"
	if lower.contains("mineral"):
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
