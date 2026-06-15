extends Node3D
class_name PlayerModel

@onready var torso: MeshInstance3D = $Torso
@onready var head: MeshInstance3D = $Head
@onready var left_arm: MeshInstance3D = $LeftArm
@onready var right_arm: MeshInstance3D = $RightArm
@onready var left_leg: MeshInstance3D = $LeftLeg
@onready var right_leg: MeshInstance3D = $RightLeg

@export var walk_speed_threshold: float = 0.5
@export_group("Arm & Weapon Position (tweak these in Inspector)")
@export var right_arm_position: Vector3 = Vector3(0.4, 0.9, 0)
@export var left_arm_position: Vector3 = Vector3(-0.4, 0.9, 0)
@export var weapon_position: Vector3 = Vector3(0.05, -0.35, 0.15)
@export var weapon_rotation_degrees: Vector3 = Vector3(0, -90, 0)

var time: float = 0.0
var is_walking: bool = false

func _ready():
	# Apply custom positions from Inspector
	if right_arm:
		right_arm.position = right_arm_position
	if left_arm:
		left_arm.position = left_arm_position

func update_animation(velocity: Vector3, is_on_floor: bool):
	var speed = velocity.length()
	
	if speed > walk_speed_threshold and is_on_floor:
		if not is_walking:
			is_walking = true
	else:
		if is_walking:
			is_walking = false

func _process(delta):
	time += delta
	
	if is_walking:
		# Walking animation - arm and leg swing
		var swing = sin(time * 8.0) * 0.8
		
		if left_leg:
			left_leg.rotation_degrees.x = swing * 25
		if right_leg:
			right_leg.rotation_degrees.x = -swing * 25
		if left_arm:
			left_arm.rotation_degrees.x = swing * 35
		if right_arm:
			right_arm.rotation_degrees.x = -swing * 35
	else:
		# Idle - gentle breathing + relaxed arms
		var bob = sin(time * 1.5) * 0.02
		if torso:
			torso.position.y = 0.9 + bob
		if head:
			head.position.y = 1.55 + bob * 0.5
		
		# Reset to idle pose
		if left_leg:
			left_leg.rotation_degrees.x = 0
		if right_leg:
			right_leg.rotation_degrees.x = 0
		if left_arm:
			left_arm.rotation_degrees.x = -15
		if right_arm:
			right_arm.rotation_degrees.x = -15
