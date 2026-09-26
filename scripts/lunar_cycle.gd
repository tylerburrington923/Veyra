extends Node3D
class_name VeyraLunarCycle

## Permanent-night celestial cycle for Veyra.
## The moon is the world clock instead of a conventional day/night cycle.
## Keep the simulation deterministic: phase advances from world time and a seed offset.

@export var cycle_length_seconds: float = 900.0
@export var phase_offset: float = 0.0
@export var moon_distance: float = 55.0
@export var moon_height: float = 34.0
@export var light_energy_min: float = 0.18
@export var light_energy_max: float = 0.72
@export var visual_update_interval: float = 0.05

var world_time: float = 0.0
var world_seed: int = 47291
var moon_light: DirectionalLight3D
var moon_mesh: MeshInstance3D
var phase_index: int = 0
var phase_name: String = "Dark"
var _visual_accumulator: float = 0.0

const PHASE_NAMES := ["Dark", "Crescent", "First Quarter", "Gibbous", "Full", "Waning Gibbous", "Last Quarter", "Waning Crescent"]

func _ready() -> void:
    _build_moon()
    _refresh()

func configure(seed_value: int, initial_time: float) -> void:
    world_seed = seed_value
    phase_offset = fmod(abs(float(seed_value % 1000)) / 1000.0, 1.0)
    world_time = initial_time
    _refresh()

func advance(delta: float) -> void:
    if cycle_length_seconds <= 0.0:
        return
    world_time = fmod(world_time + delta, cycle_length_seconds)
    _visual_accumulator += delta
    if _visual_accumulator < visual_update_interval:
        return
    _visual_accumulator = 0.0
    _refresh()

func get_phase() -> float:
    if cycle_length_seconds <= 0.0:
        return 0.0
    return fmod(world_time / cycle_length_seconds + phase_offset, 1.0)

func get_phase_index() -> int:
    return phase_index

func get_phase_name() -> String:
    return phase_name

func get_lunar_state() -> Dictionary:
    return {
        "phase": get_phase(),
        "phase_index": phase_index,
        "phase_name": phase_name,
        "cycle_seconds": cycle_length_seconds,
        "world_seed": world_seed
    }

func _build_moon() -> void:
    moon_light = DirectionalLight3D.new()
    moon_light.name = "MoonLight"
    moon_light.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
    moon_light.shadow_enabled = false
    moon_light.directional_shadow_max_distance = 55.0
    moon_light.light_color = Color(0.56, 0.64, 0.82, 1.0)
    add_child(moon_light)

    moon_mesh = MeshInstance3D.new()
    moon_mesh.name = "Moon"
    var sphere := SphereMesh.new()
    sphere.radius = 2.2
    sphere.height = 4.4
    sphere.radial_segments = 12
    sphere.rings = 6
    moon_mesh.mesh = sphere

    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.64, 0.69, 0.78, 1.0)
    material.emission_enabled = true
    material.emission = Color(0.18, 0.22, 0.34, 1.0)
    material.emission_energy_multiplier = 0.9
    material.roughness = 1.0
    moon_mesh.material_override = material
    add_child(moon_mesh)

func _refresh() -> void:
    if not moon_light or not moon_mesh:
        return

    var phase := get_phase()
    phase_index = int(floor(phase * PHASE_NAMES.size())) % PHASE_NAMES.size()
    phase_name = PHASE_NAMES[phase_index]

    var angle := phase * TAU
    var horizontal := cos(angle)
    var vertical := sin(angle)

    var moon_origin := Vector3.ZERO
    var player := get_tree().get_first_node_in_group("local_player")
    if player is Node3D:
        moon_origin = player.global_position
    moon_mesh.global_position = moon_origin + Vector3(
        horizontal * moon_distance,
        moon_height + vertical * 10.0,
        sin(angle) * moon_distance
    )
    moon_light.rotation_degrees = Vector3(-30.0 - vertical * 22.0, phase * 360.0 - 180.0, 0.0)

    # Full moon is brightest; dark/new moon remains dim rather than disappearing.
    var illumination := 0.5 + 0.5 * cos((phase - 0.5) * TAU)
    moon_light.light_energy = lerpf(light_energy_min, light_energy_max, illumination)

    # Keep the celestial object lightweight: phase is represented by brightness/scale
    # for now; a shader-based crescent can be added later without per-frame geometry.
    var scale_factor := lerpf(0.86, 1.05, illumination)
    moon_mesh.scale = Vector3.ONE * scale_factor
