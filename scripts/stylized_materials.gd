extends Node

static func ground() -> StandardMaterial3D:
    return _mat(Color(0.24, 0.28, 0.23, 1), 1.0)

static func stone() -> StandardMaterial3D:
    return _mat(Color(0.34, 0.37, 0.36, 1), 0.95)

static func strange_stone() -> StandardMaterial3D:
    return _mat(Color(0.30, 0.25, 0.38, 1), 0.9)

static func wood() -> StandardMaterial3D:
    return _mat(Color(0.30, 0.20, 0.11, 1), 0.95)

static func copper() -> StandardMaterial3D:
    return _mat(Color(0.42, 0.25, 0.14, 1), 0.65, 0.12)

static func lux() -> StandardMaterial3D:
    var m := _mat(Color(0.08, 0.48, 0.52, 1), 0.7)
    m.emission_enabled = true
    m.emission = Color(0.02, 0.32, 0.36, 1)
    m.emission_energy_multiplier = 1.5
    return m

static func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material
