@tool
class_name BossModel
extends Node3D

const ANIMATION_SOURCES := {
	"lobby": "res://assets/boss/source/Person/Boss Dating.fbx",
	"taunt": "res://assets/boss/source/Person/Boss Tiaoxin.fbx",
	"walk": "res://assets/boss/source/Person/Boss Walk With Rifle.fbx",
	"jump": "res://assets/boss/source/Person/Boss Jump Down.fbx",
	"melee": "res://assets/boss/source/Person/Boss Jinzhan.fbx",
	"charge": "res://assets/boss/source/Person/Boss Chongci.fbx",
	"charge_impact": "res://assets/boss/source/Person/Boss Chongcizhuangjidao.fbx",
	"stunned": "res://assets/boss/source/Person/Boss Xuanyun.fbx",
	"death": "res://assets/boss/source/Person/Boss Death.fbx",
}
const LOOPING_ANIMATIONS := [&"lobby", &"taunt", &"walk", &"charge", &"stunned"]

@export var starting_animation: StringName = &"taunt"
@export var editor_preview_animation: StringName = &"walk"

@onready var animation_player: AnimationPlayer = $Rig/AnimationPlayer
@onready var weapon: Node3D = $Rig/Skeleton3D/WeaponAttachment/Weapon


func _ready() -> void:
	_install_animation_library()
	play_animation(editor_preview_animation if Engine.is_editor_hint() else starting_animation)


func _install_animation_library() -> void:
	var library := animation_player.get_animation_library("")
	if library == null:
		library = AnimationLibrary.new()
		animation_player.add_animation_library("", library)
	for animation_name: String in ANIMATION_SOURCES:
		var source_scene := load(ANIMATION_SOURCES[animation_name]) as PackedScene
		if source_scene == null:
			push_warning("无法载入 Boss 动画：%s" % ANIMATION_SOURCES[animation_name])
			continue
		var source_instance := source_scene.instantiate()
		var source_player := source_instance.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if source_player == null or not source_player.has_animation("mixamo_com"):
			source_instance.free()
			continue
		var animation := source_player.get_animation("mixamo_com").duplicate(true) as Animation
		animation.loop_mode = Animation.LOOP_LINEAR if StringName(animation_name) in LOOPING_ANIMATIONS else Animation.LOOP_NONE
		if library.has_animation(animation_name):
			library.remove_animation(animation_name)
		library.add_animation(animation_name, animation)
		source_instance.free()


func play_animation(animation_name: StringName, blend := 0.14, speed := 1.0, restart := false) -> void:
	if not is_node_ready() or not animation_player.has_animation(animation_name):
		return
	if not restart and animation_player.current_animation == animation_name and animation_player.is_playing():
		return
	animation_player.play(animation_name, blend, speed)


func get_animation_length(animation_name: StringName) -> float:
	if not is_node_ready() or not animation_player.has_animation(animation_name):
		return 1.5
	return animation_player.get_animation(animation_name).length
