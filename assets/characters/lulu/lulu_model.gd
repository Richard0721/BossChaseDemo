@tool
class_name LuluModel
extends Node3D

const ANIMATION_SOURCES := {
	"idle": "res://assets/characters/lulu/source/Person/Lulu Idle.fbx",
	"standing": "res://assets/characters/happy_student/source/Happy Student standing.fbx",
	"pointing": "res://assets/characters/lulu/source/Person/Lulu Pointing.fbx",
	"walk_rifle": "res://assets/characters/happy_student/source/Happy Student Walk With Rifle.fbx",
	"jump_down": "res://assets/characters/happy_student/source/Happy Student Jump Down.fbx",
	"death": "res://assets/characters/lulu/source/Person/Lulu Death.fbx",
	"hammer_attack": "res://assets/items/hammer/animations/Chuzi Attack.fbx",
	"hammer_walk": "res://assets/items/hammer/animations/Chuzi walk.fbx",
	"hammer_standing": "res://assets/items/hammer/animations/Chuizi Standing Idle.fbx",
	"hammer_throw": "res://assets/items/hammer/animations/Chuizi Throw.fbx",
}
const LOOPING_ANIMATIONS := [&"idle", &"standing", &"pointing", &"walk_rifle", &"hammer_walk", &"hammer_standing"]

@export var starting_animation: StringName = &"idle"
@export var show_weapon := true
@export var editor_preview_animation: StringName = &"standing"

@onready var animation_player: AnimationPlayer = $Rig/AnimationPlayer
@onready var _weapon: Node3D = $Rig/Skeleton3D/WeaponAttachment/Weapon


func _ready() -> void:
	_install_animation_library()
	_weapon.visible = show_weapon
	play_animation(editor_preview_animation if Engine.is_editor_hint() else starting_animation)


func _install_animation_library() -> void:
	var library := animation_player.get_animation_library("")
	if library == null:
		library = AnimationLibrary.new()
		animation_player.add_animation_library("", library)
	for animation_name: String in ANIMATION_SOURCES:
		var source_scene := load(ANIMATION_SOURCES[animation_name]) as PackedScene
		if source_scene == null:
			push_warning("无法载入 Lulu 动画：%s" % ANIMATION_SOURCES[animation_name])
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


func play_animation(animation_name: StringName, blend := 0.16, speed := 1.0, restart := false) -> void:
	if not is_node_ready() or not animation_player.has_animation(animation_name):
		return
	if not restart and animation_player.current_animation == animation_name and animation_player.is_playing():
		return
	animation_player.play(animation_name, blend, speed)


func set_weapon_visible(is_visible: bool) -> void:
	show_weapon = is_visible
	if is_instance_valid(_weapon):
		_weapon.visible = is_visible


func set_shield_visible(is_visible: bool) -> void:
	var shield := get_node_or_null("Rig/Skeleton3D/ShieldAttachment/Shield") as Node3D
	if shield != null:
		shield.visible = is_visible


func set_hammer_visible(is_visible: bool) -> void:
	var hammer := get_node_or_null("Rig/Skeleton3D/HammerAttachment/Hammer") as HammerVisual
	if hammer != null:
		if is_visible:
			hammer.scale = Vector3.ONE
			hammer._apply_mount_settings()
		hammer.visible = is_visible


func set_rapid_gun_visible(is_visible: bool) -> void:
	var rapid_gun := get_node_or_null("Rig/Skeleton3D/RapidGunAttachment/RapidGun") as Node3D
	if rapid_gun != null:
		rapid_gun.visible = is_visible
