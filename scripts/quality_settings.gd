extends Node

## Runtime quality controls.
## These are intentionally conservative for 4 GB Android devices.

var shadows_enabled := true
var max_dynamic_lights := 2
var effects_enabled := true
var foliage_density := 0.65

func configure_low_memory_mode() -> void:
    shadows_enabled = true
    max_dynamic_lights = 1
    effects_enabled = true
    foliage_density = 0.5

func configure_balanced_mode() -> void:
    shadows_enabled = true
    max_dynamic_lights = 2
    effects_enabled = true
    foliage_density = 0.75

func configure_high_mode() -> void:
    shadows_enabled = true
    max_dynamic_lights = 4
    effects_enabled = true
    foliage_density = 1.0
