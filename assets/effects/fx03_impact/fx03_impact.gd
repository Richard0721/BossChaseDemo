@tool
class_name Fx03Impact
extends Node3D

const FRAMES: Array[Texture2D] = [
	preload("res://assets/effects/fx03_impact/source/Images/1.png"),
	preload("res://assets/effects/fx03_impact/source/Images/2.png"),
	preload("res://assets/effects/fx03_impact/source/Images/3.png"),
	preload("res://assets/effects/fx03_impact/source/Images/4.png"),
	preload("res://assets/effects/fx03_impact/source/Images/5.png"),
	preload("res://assets/effects/fx03_impact/source/Images/6.png"),
	preload("res://assets/effects/fx03_impact/source/Images/7.png"),
]
const BURST_STARTS: Array[float] = [0.0, 0.3333, 0.1667, 0.5]
const BURST_OFFSETS: Array[Vector2] = [Vector2(6, -12), Vector2(37, 1), Vector2(-26, 39), Vector2(-22, -27)]
const FRAME_TIME := 1.0 / 30.0
const BURST_VISIBLE_TIME := 0.3333
const EFFECT_DURATION := 0.85
const BASE_PIXEL_SIZE := 0.006

@export_range(0.1, 5.0, 0.05) var effect_size := 1.3:
	set(value):
		effect_size = value
		if is_node_ready():
			_apply_size_and_offsets()
@export var effect_color := Color(1.0, 0.55, 0.12, 1.0)
@export var loop_preview := false
@export var auto_free := true

@onready var _sprites: Array[Sprite3D] = [$Burst1, $Burst2, $Burst3, $Burst4]
var _elapsed := 0.0


func _ready() -> void:
	_apply_size_and_offsets()
	_update_animation()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= EFFECT_DURATION:
		if Engine.is_editor_hint() or loop_preview:
			_elapsed = fmod(_elapsed, EFFECT_DURATION)
		elif auto_free:
			queue_free()
			return
		else:
			_elapsed = EFFECT_DURATION
	_update_animation()


func restart() -> void:
	_elapsed = 0.0
	visible = true
	_update_animation()


func _apply_size_and_offsets() -> void:
	for index in _sprites.size():
		var sprite := _sprites[index]
		sprite.pixel_size = BASE_PIXEL_SIZE * effect_size
		var offset: Vector2 = BURST_OFFSETS[index] * BASE_PIXEL_SIZE * effect_size
		sprite.position = Vector3(offset.x, -offset.y, float(index) * 0.002)


func _update_animation() -> void:
	for index in _sprites.size():
		var sprite := _sprites[index]
		var local_time: float = _elapsed - BURST_STARTS[index]
		if local_time < 0.0 or local_time > BURST_VISIBLE_TIME:
			sprite.visible = false
			continue
		sprite.visible = true
		var frame_index := clampi(int(local_time / FRAME_TIME), 0, FRAMES.size() - 1)
		sprite.texture = FRAMES[frame_index]
		var fade := 1.0
		var burst_scale := 1.0
		if local_time > 0.2:
			var fade_weight := clampf((local_time - 0.2) / (BURST_VISIBLE_TIME - 0.2), 0.0, 1.0)
			fade = 1.0 - fade_weight
			burst_scale = lerpf(1.0, 1.514, fade_weight)
		sprite.scale = Vector3.ONE * burst_scale
		sprite.modulate = Color(effect_color.r, effect_color.g, effect_color.b, effect_color.a * fade)
