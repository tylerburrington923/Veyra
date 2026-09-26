extends StaticBody3D
class_name VeyraResourceNode

@export_enum("Stone", "Wood", "Metal", "Echo-Stone", "Vitreous Lux") var resource_type := "Stone"
@export var amount := 3
@export var tool_required := "T00_HANDS"
@export var tool_efficiency := 1.0
@export var durability_cost := 1.0
@export var respawn_seconds := 45.0

var resource_id: String = ""
var remaining: int = 0
var depleted := false
var respawn_time := 0.0
var interaction_cooldown := 0.0

func _ready() -> void:
    add_to_group("resource_node")
    collision_layer = 2
    collision_mask = 1
    remaining = maxi(0, amount)
    set_process(false)

func interact() -> void:
    if depleted or remaining <= 0 or interaction_cooldown > 0.0:
        return

    var player: Node = get_tree().get_first_node_in_group("local_player")
    if not player:
        return

    var inventory: Node = player.get_inventory() if player.has_method("get_inventory") else null
    if not inventory:
        return

    var required := tool_required
    if required.is_empty():
        required = "T00_HANDS"

    if required != "T00_HANDS":
        if not player.has_method("get_tool_id") or player.get_tool_id() != required:
            return

    var yield_amount := maxi(1, int(round(tool_efficiency)))
    yield_amount = mini(yield_amount, remaining)

    if not inventory.has_method("add_resource"):
        return

    if player.has_method("can_use_tool") and not player.can_use_tool(durability_cost):
        return

    var accepted := int(inventory.add_resource(resource_type, yield_amount))
    if accepted <= 0:
        return

    if player.has_method("use_tool") and not player.use_tool(durability_cost):
        inventory.remove_resource(resource_type, accepted)
        return

    remaining -= accepted
    interaction_cooldown = 0.18
    set_process(true)
    if remaining <= 0:
        _deplete()

func get_interaction_point() -> Vector3:
	return global_position + Vector3.UP * 0.75

func get_interaction_text() -> String:
    if depleted or remaining <= 0:
        return "%s depleted" % resource_type
    return "Gather %s  [%d]" % [resource_type, remaining]

func _process(delta: float) -> void:
    if interaction_cooldown > 0.0:
        interaction_cooldown = maxf(0.0, interaction_cooldown - delta)
    if not depleted:
        if interaction_cooldown <= 0.0:
            set_process(false)
        return
    respawn_time -= delta
    if respawn_time <= 0.0:
        _restore()

func _deplete() -> void:
    remaining = 0
    depleted = true
    respawn_time = maxf(1.0, respawn_seconds)
    set_process(true)
    visible = false
    collision_layer = 0
    collision_mask = 0

func _restore() -> void:
    remaining = maxi(0, amount)
    depleted = false
    respawn_time = 0.0
    set_process(false)
    visible = true
    collision_layer = 2
    collision_mask = 1

func get_save_state() -> Dictionary:
    if resource_id.is_empty() or (not depleted and remaining == amount):
        return {}
    return {
        "remaining": remaining,
        "depleted": depleted,
        "respawn_time": maxf(0.0, respawn_time)
    }

func apply_save_state(state: Dictionary) -> void:
    if state.is_empty():
        return

    remaining = clampi(int(state.get("remaining", amount)), 0, maxi(0, amount))
    depleted = bool(state.get("depleted", remaining <= 0))
    respawn_time = maxf(0.0, float(state.get("respawn_time", 0.0)))

    if depleted:
        set_process(true)
        visible = false
        collision_layer = 0
        collision_mask = 0
    else:
        set_process(false)
        visible = true
        collision_layer = 2
        collision_mask = 1
