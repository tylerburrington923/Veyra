extends StaticBody3D
class_name VeyraResourceNode

@export_enum("Stone", "Wood", "Metal", "Echo-Stone", "Vitreous Lux") var resource_type := "Stone"
@export var amount := 1
@export var tool_required := "T00_HANDS"
@export var tool_efficiency := 1.0
@export var durability_cost := 1.0

var depleted := false
var respawn_time := 0.0
@export var respawn_seconds := 45.0

func _ready() -> void:
    add_to_group("resource_node")
    collision_layer = 2
    collision_mask = 1
    set_process(false)

func _process(delta: float) -> void:
    if not depleted:
        return
    respawn_time -= delta
    if respawn_time <= 0.0:
        _restore()

func interact() -> void:
    if depleted:
        return

    var player := get_tree().get_first_node_in_group("local_player")
    if not player or not player.has_method("add_resource"):
        return

    if tool_required != "T00_HANDS":
        if not player.has_method("get_tool_id") or player.get_tool_id() != tool_required:
            return

    if player.has_method("use_tool") and not player.use_tool(durability_cost):
        return

    var yield_amount := maxi(1, int(round(float(amount) * tool_efficiency)))
    player.add_resource(resource_type, yield_amount)
    depleted = true
    respawn_time = maxf(1.0, respawn_seconds)
    set_process(true)
    visible = false
    collision_layer = 0
    collision_mask = 0

func _restore() -> void:
    depleted = false
    respawn_time = 0.0
    set_process(false)
    visible = true
    collision_layer = 2
    collision_mask = 1
