extends StaticBody3D
class_name VeyraEchoStone

## Lightweight anomaly state. Echo-Stone stores interaction energy and resonance
## without spawning or driving rigid-body physics.

@export var hardness := 3.0
@export var memory_decay_per_second := 0.08
@export var release_threshold := 6.0

var stored_energy := 0.0
var thermal_state := 0.0
var structural_state := 0.0
var resonance_state := 0.0
var activated := false
var _visual_accumulator := 0.0

@onready var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D

func _ready() -> void:
    add_to_group("echo_stone")
    var terrain := get_parent().get_node_or_null("WorldGenerator")
    if terrain and terrain.has_method("get_height_at_world"):
        global_position.y = terrain.get_height_at_world(global_position.x, global_position.z) + 0.9
    _refresh_visual()

func _process(delta: float) -> void:
    stored_energy = maxf(0.0, stored_energy - memory_decay_per_second * delta)
    thermal_state = move_toward(thermal_state, 0.0, delta * 0.12)
    resonance_state = move_toward(resonance_state, 0.0, delta * 0.2)
    _visual_accumulator += delta

    if activated and stored_energy <= release_threshold * 0.35:
        activated = false
        _refresh_visual()
    elif _visual_accumulator >= 0.1:
        _visual_accumulator = 0.0
        _refresh_visual()

func interact() -> void:
    apply_force(-global_transform.basis.z, 1.0)

func apply_force(direction: Vector3, magnitude: float) -> void:
    var force := maxf(0.0, magnitude)
    stored_energy = minf(release_threshold * 1.5, stored_energy + force / maxf(hardness, 0.1))
    structural_state = clampf(stored_energy / release_threshold, 0.0, 1.0)
    resonance_state = clampf(resonance_state + force * 0.08, 0.0, 1.0)

    if stored_energy >= release_threshold:
        _release()

    _refresh_visual()

func heat(amount: float) -> void:
    thermal_state = clampf(thermal_state + amount, 0.0, 1.0)
    stored_energy = minf(release_threshold * 1.5, stored_energy + amount * 0.5)
    _refresh_visual()

func get_material_state() -> Dictionary:
    return {
        "hardness": hardness,
        "stored_energy": stored_energy,
        "thermal_state": thermal_state,
        "structural_state": structural_state,
        "resonance_state": resonance_state,
        "activated": activated
    }

func _release() -> void:
    activated = true
    stored_energy *= 0.25
    structural_state = clampf(stored_energy / release_threshold, 0.0, 1.0)
    print("Echo-Stone released stored resonance.")
    _refresh_visual()

func _refresh_visual() -> void:
    if not mesh:
        return
    var material := mesh.get_active_material(0)
    if material is StandardMaterial3D:
        var m := material as StandardMaterial3D
        var glow := clampf(resonance_state * 1.5 + thermal_state * 0.5 + (0.35 if activated else 0.0), 0.0, 1.5)
        m.emission_enabled = glow > 0.05
        m.emission = Color(0.16, 0.06, 0.28, 1) * glow
        m.emission_energy_multiplier = 0.8 + glow * 1.8
