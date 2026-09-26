extends CharacterBody3D

## Veyra mobile-first first-person controller.
## Left side: dynamic movement joystick.
## Right side: camera look.
## Desktop: WASD + mouse.

@export_category("Movement")
@export var speed: float = 5.2
@export var acceleration: float = 22.0
@export var braking: float = 28.0
@export var gravity: float = 18.0
@export var jump_velocity: float = 7.0
@export var jump_forward_boost: float = 1.35
@export var ground_snap_distance: float = 0.35
@export var max_floor_angle_degrees: float = 48.0
@export var safe_spawn_height: float = 12.0

@export_category("Look")
@export var mouse_sensitivity: float = 0.003
@export var touch_look_multiplier: float = 2.0
@export var min_pitch_degrees: float = -70.0
@export var max_pitch_degrees: float = 55.0

@export_category("Camera")
@export var camera_distance: float = 0.0
@export var camera_height: float = 1.68
@export var camera_fov: float = 70.0
@export var camera_far: float = 140.0

@export_category("Mobile Joystick")
@export var joystick_radius: float = 70.0
@export_range(0.0, 0.5, 0.01) var joystick_deadzone: float = 0.12
@export_range(0.1, 0.9, 0.01) var left_screen_ratio: float = 0.48

var look_pitch: float = deg_to_rad(-8.0)
var target_yaw: float = 0.0
@export_range(0.0, 30.0, 0.5) var camera_yaw_smoothing: float = 18.0
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
@onready var left_arm: MeshInstance3D = get_node_or_null("LeftArm") as MeshInstance3D
@onready var right_arm: MeshInstance3D = get_node_or_null("RightArm") as MeshInstance3D
@onready var torso: MeshInstance3D = get_node_or_null("Torso") as MeshInstance3D
@onready var head: MeshInstance3D = get_node_or_null("Head") as MeshInstance3D
@onready var hair: MeshInstance3D = get_node_or_null("Hair") as MeshInstance3D
@onready var left_eye: MeshInstance3D = get_node_or_null("LeftEye") as MeshInstance3D
@onready var right_eye: MeshInstance3D = get_node_or_null("RightEye") as MeshInstance3D
@onready var left_hand: MeshInstance3D = get_node_or_null("LeftHand") as MeshInstance3D
@onready var right_hand: MeshInstance3D = get_node_or_null("RightHand") as MeshInstance3D
@onready var viewmodel_left_arm: MeshInstance3D = get_node_or_null("Camera3D/ViewModel/LeftArmFP") as MeshInstance3D
@onready var viewmodel_right_arm: MeshInstance3D = get_node_or_null("Camera3D/ViewModel/RightArmFP") as MeshInstance3D
@onready var viewmodel_left_hand: MeshInstance3D = get_node_or_null("Camera3D/ViewModel/LeftHandFP") as MeshInstance3D
@onready var viewmodel_right_hand: MeshInstance3D = get_node_or_null("Camera3D/ViewModel/RightHandFP") as MeshInstance3D
var walk_time: float = 0.0
var _debug_hud_accumulator: float = 0.0
signal tool_changed(tool_id: String, durability: float)

var selected_tool_id: String = "T00_HANDS"
var tool_durability: float = 100.0


func get_tool_id() -> String:
	return selected_tool_id

func set_tool(tool_id: String) -> bool:
	var next_tool := tool_id if tool_id != "" else "T00_HANDS"
	if next_tool != "T00_HANDS":
		var inventory := get_inventory()
		if next_tool not in VeyraItemCatalog.TOOL_IDS or not inventory or not inventory.has_item(next_tool):
			return false
	if next_tool == selected_tool_id:
		return true
	selected_tool_id = next_tool
	tool_durability = 100.0
	tool_changed.emit(selected_tool_id, tool_durability)
	_update_equipped_tool_visual()
	return true

func can_use_tool(durability_cost: float = 1.0) -> bool:
	return selected_tool_id == "T00_HANDS" or (tool_durability > 0.0 and durability_cost >= 0.0)

func use_tool(durability_cost: float = 1.0) -> bool:
	if not can_use_tool(durability_cost):
		return false
	if selected_tool_id != "T00_HANDS":
		tool_durability = maxf(0.0, tool_durability - maxf(0.0, durability_cost))
		if tool_durability <= 0.0:
			selected_tool_id = "T00_HANDS"
		tool_changed.emit(selected_tool_id, tool_durability)
		_update_equipped_tool_visual()
	return true

func get_save_state() -> Dictionary:
	return {
		"tool_id": selected_tool_id,
		"tool_durability": clampf(tool_durability, 0.0, 100.0)
	}

func load_save_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	var tool_id := str(state.get("tool_id", "T00_HANDS"))
	var inventory := get_inventory()
	if tool_id != "T00_HANDS" and (not inventory or not inventory.has_item(tool_id)):
		tool_id = "T00_HANDS"
	selected_tool_id = tool_id
	tool_durability = clampf(float(state.get("tool_durability", 100.0)), 0.0, 100.0)
	if selected_tool_id == "T00_HANDS":
		tool_durability = 100.0
	tool_changed.emit(selected_tool_id, tool_durability)
	_update_equipped_tool_visual()

func _update_equipped_tool_visual() -> void:
	var tool_visual := get_node_or_null("Camera3D/ViewModel/RightHandFP/EquippedTool") as Node3D
	if not tool_visual:
		return
	tool_visual.visible = selected_tool_id != "T00_HANDS"
	if not tool_visual.visible:
		return
	match selected_tool_id:
		"I01_STONE_AXE":
			tool_visual.rotation_degrees = Vector3(0, 0, -18)
			tool_visual.scale = Vector3.ONE
		"I02_STONE_PICK":
			tool_visual.rotation_degrees = Vector3(0, 0, 18)
			tool_visual.scale = Vector3.ONE
		_:
			tool_visual.visible = false

func get_inventory() -> VeyraInventory:
	return get_node_or_null("Inventory") as VeyraInventory

func add_resource(resource_type: String, amount: int) -> void:
	var inventory := get_inventory()
	if inventory:
		inventory.add_resource(resource_type, amount)


func _ready() -> void:
	add_to_group("local_player")
	# Give a brand-new save a tiny starter cache so the beta loop is testable
	# immediately. Loaded saves are left untouched.
	if GameManager and GameManager.get_loaded_save().is_empty():
		var starter_inventory := get_inventory()
		if starter_inventory:
			starter_inventory.add_resource("Wood", 3)
			starter_inventory.add_resource("Stone", 2)
	up_direction = Vector3.UP
	floor_snap_length = ground_snap_distance
	floor_max_angle = deg_to_rad(max_floor_angle_degrees)
	call_deferred("_stabilize_spawn")

	if interact_button and not interact_button.pressed.is_connected(_on_interact_pressed):
		interact_button.pressed.connect(_on_interact_pressed)
	if jump_button and not jump_button.pressed.is_connected(_on_jump_pressed):
		jump_button.pressed.connect(_on_jump_pressed)

	_configure_camera()
	_configure_first_person_view()
	_hide_joystick()
	_update_equipped_tool_visual()


func _configure_camera() -> void:
	if not camera:
		return

	camera.current = true
	camera.fov = camera_fov
	camera.far = camera_far
	camera.position = Vector3(0.0, camera_height, camera_distance)
	camera.rotation = Vector3(look_pitch, 0.0, 0.0)
	look_pitch = camera.rotation.x
	target_yaw = rotation.y


func _configure_first_person_view() -> void:
	# Keep the camera inside the player capsule but hide body geometry so it cannot occlude the world.
	for mesh in [head, hair, left_eye, right_eye, left_arm, right_arm, left_hand, right_hand]:
		if mesh:
			mesh.visible = false
	if torso:
		torso.visible = true
	if left_leg:
		left_leg.visible = true
	if right_leg:
		right_leg.visible = true
	for mesh in [viewmodel_left_arm, viewmodel_right_arm, viewmodel_left_hand, viewmodel_right_hand]:
		if mesh:
			mesh.visible = true

func _stabilize_spawn() -> void:
	var world_generator := get_parent().get_node_or_null("WorldGenerator")
	if world_generator and world_generator.has_method("is_generated") and world_generator.is_generated():
		var terrain_y: float = world_generator.get_height_at_world(global_position.x, global_position.z)
		global_position.y = maxf(global_position.y, terrain_y + 1.5)
		velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	_recover_from_fall()
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-camera_yaw_smoothing * delta))
	var input_vector: Vector2 = move_input

	if input_vector.length_squared() < 0.0001:
		input_vector = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_back", "move_forward")
		)

	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	var direction: Vector3 = _camera_relative_direction(input_vector)

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
		var jump_direction := direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO
		if jump_direction != Vector3.ZERO:
			velocity.x += jump_direction.x * jump_forward_boost
			velocity.z += jump_direction.z * jump_forward_boost
	else:
		velocity.y = 0.0

	jump_requested = false

	move_and_slide()
	_update_player_visuals(delta, direction)
	_debug_hud_accumulator += delta
	if _debug_hud_accumulator >= 0.25:
		_debug_hud_accumulator = 0.0
		_update_debug_hud(input_vector)


func _update_player_visuals(delta: float, direction: Vector3) -> void:
	var moving := direction.length_squared() > 0.001 and is_on_floor()
	if moving:
		walk_time += delta * 9.5
	else:
		walk_time = move_toward(walk_time, 0.0, delta * 7.0)

	var stride := sin(walk_time) if moving else 0.0
	var opposite_stride := -stride
	var lift := maxf(0.0, stride) * 0.035 if moving else 0.0
	var opposite_lift := maxf(0.0, opposite_stride) * 0.035 if moving else 0.0
	var arm_swing := stride * 0.18 if moving else 0.0

	if left_leg:
		left_leg.rotation.x = stride * 0.32
		left_leg.position.y = 0.48 + lift
	if right_leg:
		right_leg.rotation.x = opposite_stride * 0.32
		right_leg.position.y = 0.48 + opposite_lift

	if left_arm:
		left_arm.rotation.x = -arm_swing
	if right_arm:
		right_arm.rotation.x = arm_swing

	if torso:
		var target_y := 1.15 + (absf(stride) * 0.025 if moving else 0.0)
		torso.position.y = move_toward(torso.position.y, target_y, delta * 2.5)

func _update_debug_hud(input_vector: Vector2) -> void:
	if not debug_hud:
		return
	var world := get_parent()
	var lunar_text := "MOON: --"
	var seed_text := "SEED: --"
	if world and world.has_method("get_lunar_state"):
		var lunar: Dictionary = world.get_lunar_state()
		lunar_text = "MOON: %s" % str(lunar.get("phase_name", "--"))
		seed_text = "SEED: VE-%05d" % int(lunar.get("world_seed", 0))
	var tool_text := "HANDS"
	match selected_tool_id:
		"I01_STONE_AXE": tool_text = "AXE"
		"I02_STONE_PICK": tool_text = "PICK"
	debug_hud.text = "%s  •  %s  •  %s" % [seed_text, lunar_text, tool_text]


func _recover_from_fall() -> void:
	var world_generator := get_parent().get_node_or_null("WorldGenerator")
	if not world_generator or not world_generator.has_method("get_height_at_world"):
		return
	var terrain_y: float = world_generator.get_height_at_world(global_position.x, global_position.z)
	if global_position.y < terrain_y - 6.0:
		global_position.y = terrain_y + 1.5
		velocity = Vector3.ZERO


func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector.length_squared() < 0.0001:
		return Vector3.ZERO

	var forward: Vector3 = -global_transform.basis.z

	if camera:
		forward = -camera.global_transform.basis.z

	forward.y = 0.0

	if forward.length_squared() < 0.0001:
		forward = Vector3(0.0, 0.0, -1.0)
	else:
		forward = forward.normalized()

	var right: Vector3 = forward.cross(Vector3.UP)

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
		var screen_width: float = get_viewport().get_visible_rect().size.x

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
	var distance: float = offset.length()

	if distance <= joystick_deadzone * joystick_radius:
		return Vector2.ZERO

	var clamped := offset.limit_length(joystick_radius)

	return Vector2(
		clamped.x / joystick_radius,
		-clamped.y / joystick_radius
	)


func _apply_look(delta: Vector2) -> void:
	target_yaw -= delta.x * mouse_sensitivity

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



func _on_jump_pressed() -> void:
	jump_requested = true


func _on_interact_pressed() -> void:
	var ray := get_node_or_null("Camera3D/InteractionRay")

	if ray and ray.has_method("try_interact"):
		ray.try_interact()
