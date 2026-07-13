class_name RunePickup
extends Area3D

const RUNE_COLORS := {
	&"Heal": Color(0.08, 1.0, 0.35, 1.0),
	&"Speed": Color(0.05, 0.42, 1.0, 1.0),
	&"Attack": Color(1.0, 0.08, 0.06, 1.0),
	&"Defense": Color(1.0, 0.92, 0.58, 1.0),
}
const RUNE_LABELS := {
	&"Heal": "HEAL RUNE",
	&"Speed": "SPEED RUNE",
	&"Attack": "ATTACK RUNE",
	&"Defense": "DEFENSE RUNE",
}

var rune_type: StringName = &"Heal"
var lifetime := 60.0


func configure(new_type: StringName, new_lifetime: float) -> void:
	rune_type = new_type
	lifetime = new_lifetime


func _ready() -> void:
	add_to_group("rune_pickups")
	body_entered.connect(_on_body_entered)
	$Label3D.text = RUNE_LABELS[rune_type]
	var color: Color = RUNE_COLORS[rune_type]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, 0.68)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	$Orb.material_override = material
	$Ring.material_override = material
	$OmniLight3D.light_color = color


func _process(delta: float) -> void:
	lifetime -= delta
	rotation.y += delta * 1.5
	$Orb.position.y = 1.0 + sin(Time.get_ticks_msec() * 0.0035) * 0.18
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer or multiplayer.is_server()):
		return
	if body.has_method("apply_rune"):
		body.apply_rune(rune_type)
		queue_free()
