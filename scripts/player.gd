extends CharacterBody3D

## Veyra mobile-first third-person controller.
## Left side: dynamic movement joystick.
## Right side: camera look.
## Desktop: WASD + mouse.

@export_category("Movement")
@export var speed: float = 5.2
@export var acceleration: float = 22.0
@export var braking: float = 28.0
@export var gravity: float = 18.0
@export var jump_velocity: float = 7.0
@export var ground_snap_distance: float = 0.35
@export var max_floor_angle_degrees: float = 48.0
@export var safe_spawn_height: float = 12.0

@export_category("Look")
@export var mouse_sensitivity: float = 0.003
@export var touch_look_multiplier: float = 2.0
@export var min_pitch_degrees: float = -70.0
@export var max_pitch_degrees: float = 55.0

@export_category("Camera")
@export var camera_distance: float = 5.8
@export var camera_height: float = 3.1
@export var camera_fov: float = 70.0
@export var camera_far: float = 140.0

@export_category("Mobile Joystick")
@export var joystick_radius: float = 70.0
@export_range(0.0, 0.5, 0.01) var joystick_deadzone: float = 0.12
@export_range(0.1, 0.9, 0.01) var left_screen_ratio: float = 0.48

var look_pitch: float = deg_to_rad(-18.0)
var move_input: Vector2 = Vector2.ZERO
var jump_requested := false
var move_touch_id: int = -1
var look_touch_id: int = -1
var touch_start: Dictionary = {}

@onready var joystick_base: Control = get_node_or_null("MobileControls/JoystickBase") as Control
@onready var joystick_knob: Control = get_node_or_null("MobileControls/JoystickBase/JoystickKnob") as Control
@onready var interact_button: Button = get_node_or_null("MobileControls/InteractButton") as Button
@onready var jump_button: Button = get_node_or_null("MobileControls/JumpButton") as Button
@onready var camera: Camera3D = get_node_or_null("Camera3D") as Camera3D
@onready var debug_hud: Label = get_node_or_null("MobileControls/DebugHUD") as Label
@onready var left_leg: MeshInstance3D = get_node_or_null("LeftLeg") as MeshInstance3D
@onready var right_leg: MeshInstance3D = get_node_or_null("RightLeg") as MeshInstance3D
var walk_time: float = 0.0


func _ready() -> void:
	add_to_group("local_player")
	up_direction = Vector3.UP
	floor_snap_length = ground_snap_distance
	floor_max_angle = deg_to_rad(max_floor_angle_degrees)
	call_deferred("_stabilize_spawn")

	if interact_button and not interact_button.pressed.is_connected(_on_interact_pressed):
		interact_button.pressed.connect(_on_interact_pressed)
	if jump_button and not jump_button.pressed.is_connected(_on_jump_pressed):
		jump_button.pressed.connect(_on_jump_pressed)

	_configure_camera()
	_hide_joystick()


func _configure_camera() -> void:
	if not camera:
		return

	camera.current = true
	camera.fov = camera_fov
	camera.far = camera_far
	camera.position = Vector3(0.0, camera_height, camera_distance)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	look_pitch = camera.rotation.x
	camera.rotation.x = look_pitch


func _stabilize_spawn() -> void:
	var world_generator := get_parent().get_node_or_null("WorldGenerator")
	if world_generator and world_generator.has_method("is_generated") and world_generator.is_generated():
		var terrain_y: float = world_generator.get_height_at_world(global_position.x, global_position.z)
		if global_position.y < terrain_y + safe_spawn_height * 0.5:
			global_position.y = terrain_y + 2.0
		velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	var input_vector: Vector2 = move_input

	if input_vector.length_squared() < 0.0001:
		input_vector = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_back", "move_forward")
		)

	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	var direction := _camera_relative_direction(input_vector)

	if direction.length_squared() > 0.001:
		direction = direction.normalized()

		velocity.x = move_toward(
			velocity.x,
			direction.x * speed,
			acceleration * delta
		)
		velocity.z = move_toward(
			velocity.z,
			direction.z * speed,
			acceleration * delta
		)
	else:
		velocity.x = move_toward(velocity.x, 0.0, braking * delta)
		velocity.z = move_toward(velocity.z, 0.0, braking * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif jump_requested:
		velocity.y = jump_velocity
	else:
		velocity.y = 0.0

	jump_requested = false

	move_and_slide()
	_update_player_visuals(delta, direction)
	_update_debug_hud(input_vector)


func _update_player_visuals(delta: float, direction: Vector3) -> void:
	if direction.length_squared() > 0.001:
		var target_yaw := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, 10.0 * delta))
		walk_time += delta * 9.0
	else:
		walk_time = move_toward(walk_time, 0.0, delta * 8.0)
	if left_leg and right_leg:
		var swing := sin(walk_time) * 0.35 if direction.length_squared() > 0.001 else 0.0
		left_leg.rotation.x = swing
		right_leg.rotation.x = -swing


func _update_debug_hud(input_vector: Vector2) -> void:
	if not debug_hud:
		return
	debug_hud.text = "MOVE: %.2f, %.2f | GROUND: %s" % [input_vector.x, input_vector.y, "YES" if is_on_floor() else "NO"]


func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector.length_squared() < 0.0001:
		return Vector3.ZERO

	var forward := -global_transform.basis.z

	if camera:
		forward = -camera.global_transform.basis.z

	forward.y = 0.0

	if forward.length_squared() < 0.0001:
		forward = Vector3(0.0, 0.0, -1.0)
	else:
		forward = forward.normalized()

	var right := forward.cross(Vector3.UP)

	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()

	return right * input_vector.x + forward * input_vector.y


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		jump_requested = true
	elif event is InputEventMouseMotion:
		# Ignore synthetic mouse events generated by touch emulation.
		if event.device == InputEvent.DEVICE_ID_MOUSE:
			_apply_look(event.relative)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if interact_button and interact_button.get_global_rect().has_point(event.position):
		return
	if jump_button and jump_button.get_global_rect().has_point(event.position):
		return

	if event.pressed and event.is_canceled():
		return

	if event.pressed:
		var screen_width := get_viewport().get_visible_rect().size.x

		if (
			event.position.x < screen_width * left_screen_ratio
			and move_touch_id == -1
		):
			move_touch_id = event.index
			touch_start[event.index] = event.position
			move_input = Vector2.ZERO
			_show_joystick(event.position)

		elif (
			event.position.x >= screen_width * left_screen_ratio
			and look_touch_id == -1
		):
			look_touch_id = event.index
			touch_start[event.index] = event.position
	else:
		_release_touch(event.index)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == move_touch_id:
		var origin: Vector2 = touch_start.get(event.index, event.position)
		var offset: Vector2 = event.position - origin

		move_input = _joystick_vector(offset)
		_update_joystick(event.position)

	elif event.index == look_touch_id:
		# screen_relative is not affected by content scaling.
		_apply_look(event.screen_relative * touch_look_multiplier)


func _release_touch(index: int) -> void:
	if index == move_touch_id:
		move_touch_id = -1
		move_input = Vector2.ZERO
		_hide_joystick()

	if index == look_touch_id:
		look_touch_id = -1

	touch_start.erase(index)


func _joystick_vector(offset: Vector2) -> Vector2:
	var distance := offset.length()

	if distance <= joystick_deadzone * joystick_radius:
		return Vector2.ZERO

	var clamped := offset.limit_length(joystick_radius)

	return Vector2(
		clamped.x / joystick_radius,
		-clamped.y / joystick_radius
	)


func _apply_look(delta: Vector2) -> void:
	rotate_y(-delta.x * mouse_sensitivity)

	look_pitch = clamp(
		look_pitch - delta.y * mouse_sensitivity,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)

	if camera:
		camera.rotation.x = look_pitch


func _show_joystick(pos: Vector2) -> void:
	if not joystick_base or not joystick_knob:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var base_size := joystick_base.size
	var half_size := base_size * 0.5
	var min_pos := half_size
	var max_pos := viewport_size - half_size

	var center := Vector2(
		clamp(pos.x, min_pos.x, max_pos.x),
		clamp(pos.y, min_pos.y, max_pos.y)
	)

	joystick_base.position = center - half_size
	joystick_base.visible = true

	joystick_knob.position = (base_size - joystick_knob.size) * 0.5
	joystick_knob.visible = true


func _update_joystick(pos: Vector2) -> void:
	if not joystick_base or not joystick_knob:
		return

	var base_center := joystick_base.position + joystick_base.size * 0.5
	var offset: Vector2 = (pos - base_center).limit_length(joystick_radius)
	var knob_center := joystick_base.size * 0.5 + offset

	joystick_knob.position = knob_center - joystick_knob.size * 0.5


func _hide_joystick() -> void:
	if joystick_base:
		joystick_base.visible = false

	if joystick_knob:
		joystick_knob.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		move_touch_id = -1
		look_touch_id = -1
		move_input = Vector2.ZERO
		touch_start.clear()
		_hide_joystick()


func add_resource(resource_type: String, amount: int) -> void:
	var inventory_node := get_node_or_null("Inventory")

	if inventory_node and inventory_node.has_method("add_resource"):
		inventory_node.add_resource(resource_type, amount)


func _on_jump_pressed() -> void:
	jump_requested = true


func _on_interact_pressed() -> void:
	var ray := get_node_or_null("Camera3D/InteractionRay")

	if ray and ray.has_method("try_interact"):
		ray.try_interact()
