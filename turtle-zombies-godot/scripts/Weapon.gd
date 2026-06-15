extends Node3D
class_name Weapon

# =============================================================================
# FUTURE-PROOF WEAPON SYSTEM
# =============================================================================
# To add a new weapon:
# 1. Duplicate Weapon_M1911.tscn and rename it
# 2. Change the model + textures
# 3. In the Inspector, adjust:
#    - weapon_name, mag_size, fire_rate, etc.
#    - has_slide / has_hammer (true/false)
#    - slide_* and hammer_* animation values
#    - Create HammerPivot node if has_hammer = true
# =============================================================================

# =============================================================================
# WEAPON CONFIGURATION (export these so different weapons can have unique stats)
# =============================================================================
@export_group("Weapon Stats")
@export var weapon_name: String = "M1911"
@export var mag_size: int = 8
@export var max_reserve: int = 80
@export var fire_rate: float = 0.12          # seconds between shots
@export var reload_time: float = 0.8
@export var damage: float = 25.0
@export var ammo_type: String = "45ACP"

@export_group("Camera Recoil")
@export var camera_recoil_up: float = 0.014          # How much your aim gets forced UP per shot (main recoil feel)
@export var camera_recoil_side: float = 0.006        # Random left/right kick amount
@export var camera_recoil_recovery: float = 8.0      # How fast camera returns to center

@export_group("Weapon Visual Recoil")
@export var weapon_kick_back: float = 0.035          # Gun moves backward
@export var weapon_kick_up: float = 0.012            # Gun tilts upward
@export var weapon_kick_tilt: float = 0.8            # Front of barrel dips (realistic tilt)
@export var weapon_kick_time: float = 0.05
@export var weapon_return_time: float = 0.16

@export_group("Advanced Recoil")
@export var enable_random_side_kick: bool = true     # Random left/right tilt on fire

@export_group("Weapon Bob (when walking)")
@export var weapon_bob_amount: float = 0.008         # How much the weapon bobs up/down
@export var weapon_bob_speed: float = 12.0           # How fast it bobs (higher = faster footsteps feel)

@export_group("Weapon Sway (when looking around)")
@export var weapon_sway_amount: float = 0.025        # How much the weapon follows your mouse
@export var weapon_sway_speed: float = 10.0          # How fast it follows (higher = snappier)
@export var weapon_sway_reset_speed: float = 6.0     # How fast it returns to center when you stop looking (higher = faster reset)

@export_group("Slide Animation (tweak these for your model)")
@export var slide_fire_movement: float = 0.025      # Positive = forward, Negative = backward. Try both!
@export var slide_reload_movement: float = 0.035
@export var slide_fire_time: float = 0.05
@export var slide_return_time: float = 0.12
@export var slide_axis: String = "y"                 # "x", "y", or "z" - which local axis the slide moves on

@export_group("Weapon Type")
@export var has_slide: bool = true
@export var has_hammer: bool = true
@export var weapon_type: String = "Pistol"   # "Pistol", "Rifle", "Shotgun", etc. (for future use)

@export_group("Hammer Animation")
@export var hammer_cocked_rotation: float = -70.0   # Degrees when hammer is pulled back (cocked)
@export var hammer_fired_rotation: float = 5.0      # Degrees when hammer falls forward
@export var hammer_fire_time: float = 0.08
@export var hammer_return_time: float = 0.15

@export_group("Scene Node Paths (set these when duplicating the weapon scene per the header instructions)")
@export var slide_node_path: NodePath
@export var hammer_pivot_node_path: NodePath

# =============================================================================
# RUNTIME STATE
# =============================================================================
var current_ammo: int = 0
var reserve_ammo: int = 0
var last_shot_time: float = 0.0
var is_reloading: bool = false
var is_shooting: bool = false

# =============================================================================
# NODE REFERENCES
# =============================================================================
@onready var muzzle_flash: MeshInstance3D = $MuzzleFlash
@onready var camera: Node3D = get_parent()
var slide: Node3D = null
var slide_original_y: float = 0.0   # Stores the correct resting position of the slide
var hammer_pivot: Node3D = null

# Set by the owning Player in its _ready.
# Replaces the previous fragile get_parent().get_parent().get_parent() walk.
var owning_player: CharacterBody3D = null

# =============================================================================
# RECOIL SYSTEM
# =============================================================================
var recoil_pitch: float = 0.0
var original_rotation: Vector3 = Vector3.ZERO
var original_weapon_position: Vector3 = Vector3.ZERO
var original_weapon_rotation: Vector3 = Vector3.ZERO
var main_camera: Camera3D = null

var bob_time: float = 0.0
var sway_offset: Vector2 = Vector2.ZERO

# =============================================================================
# SIGNALS (for future UI / GameManager integration)
# =============================================================================
signal ammo_changed(current: int, reserve: int, weapon_name: String)
signal weapon_fired(weapon_name: String)
signal reload_started(weapon_name: String)
signal reload_finished(weapon_name: String)

# =============================================================================
# GODOT LIFECYCLE
# =============================================================================
func _ready() -> void:
	# Initialize ammo
	current_ammo = mag_size
	reserve_ammo = 40   # Starting reserve ammo (can be changed per weapon later)
	
	original_rotation = rotation
	original_weapon_position = position
	original_weapon_rotation = rotation_degrees
	
	# Find the main camera for recoil
	main_camera = get_viewport().get_camera_3d()
	
	if muzzle_flash:
		muzzle_flash.visible = false
	
	# Find Slide and HammerPivot using explicit NodePaths first (set in the weapon scene).
	# This is robust when duplicating Weapon_M1911.tscn for new weapons (see top of file).
	if slide_node_path:
		slide = get_node_or_null(slide_node_path)
	if not slide:
		slide = find_child("Slide", true, false)  # fallback for compatibility during transition
	
	if has_slide:
		if slide:
			slide_original_y = slide.position.y
		else:
			push_warning("Weapon has_slide = true but no Slide node found in scene!")
	else:
		# has_slide = false is intentional for some weapon types (see export)
		pass
	
	if hammer_pivot_node_path:
		hammer_pivot = get_node_or_null(hammer_pivot_node_path)
	if not hammer_pivot:
		hammer_pivot = find_child("HammerPivot", true, false)
	
	if has_hammer:
		if hammer_pivot:
			hammer_pivot.rotation_degrees.x = hammer_cocked_rotation
		else:
			push_warning("Weapon has_hammer = true but no HammerPivot node found in scene!")
	else:
		# has_hammer = false is intentional for some weapon types
		pass	
	# Notify UI / other systems that this weapon is ready
	emit_signal("ammo_changed", current_ammo, reserve_ammo, weapon_name)


func _process(delta: float) -> void:
	# Handle shooting (semi-auto - must click each time)
	if Input.is_action_just_pressed("shoot") and not is_reloading and not is_shooting:
		shoot()
	
	# Handle reload
	if Input.is_action_just_pressed("reload") and not is_reloading:
		reload()
	
	# Camera recoil recovery (smooth return to where player was looking)
	if main_camera and recoil_pitch > 0:
		var recovery_amount = recoil_pitch * camera_recoil_recovery * delta
		main_camera.rotation.x -= recovery_amount
		recoil_pitch -= recovery_amount
		if recoil_pitch < 0:
			recoil_pitch = 0
	
	# === WEAPON BOB & SWAY ===
	_update_weapon_bob_and_sway(delta)


# =============================================================================
# SHOOTING
# =============================================================================
func shoot() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_shot_time < fire_rate:
		return
	
	last_shot_time = current_time
	is_shooting = true
	
	# If magazine is empty, do dry-fire (hammer drops and stays forward)
	if current_ammo <= 0:
		if has_hammer and hammer_pivot:
			var hammer_tween = create_tween()
			hammer_tween.tween_property(hammer_pivot, "rotation_degrees:x", hammer_fired_rotation, hammer_fire_time)
			# Hammer stays forward (no return animation)
		is_shooting = false
		return   # ← Prevents firing and bullet impacts
	
	current_ammo -= 1
	
	# Camera recoil is now handled directly in this script (see Camera Recoil section)
	
	# Muzzle flash
	if muzzle_flash:
		muzzle_flash.visible = true
		await get_tree().create_timer(0.05).timeout
		if is_instance_valid(muzzle_flash):
			muzzle_flash.visible = false
	
	# Slide animation (if weapon has slide)
	if has_slide and slide:
		var axis_prop = "position:" + slide_axis
		var tween = create_tween()
		tween.tween_property(slide, axis_prop, slide_fire_movement, slide_fire_time)
		tween.tween_property(slide, axis_prop, slide_original_y, slide_return_time)
	
	# Hammer animation - falls forward then returns to cocked
	if has_hammer and hammer_pivot:
		var hammer_tween = create_tween()
		hammer_tween.tween_property(hammer_pivot, "rotation_degrees:x", hammer_fired_rotation, hammer_fire_time)
		hammer_tween.tween_property(hammer_pivot, "rotation_degrees:x", hammer_cocked_rotation, hammer_return_time)
	
	# === CAMERA RECOIL ===
	if main_camera:
		var side_kick = 0.0
		if enable_random_side_kick:
			side_kick = randf_range(-camera_recoil_side, camera_recoil_side)
		
		# Add kick directly to camera (preserves where player was looking)
		main_camera.rotation.x += camera_recoil_up + side_kick
		recoil_pitch = camera_recoil_up + side_kick
		
		# Reset sway when shooting so recoil doesn't fight with it
		sway_offset = Vector2.ZERO
	
	# === WEAPON VISUAL RECOIL ===
	var kick_tween = create_tween()
	
	# Move gun back + up
	var target_pos = original_weapon_position + Vector3(0, weapon_kick_up, -weapon_kick_back)
	kick_tween.tween_property(self, "position", target_pos, weapon_kick_time)
	kick_tween.tween_property(self, "position", original_weapon_position, weapon_return_time)
	
	# Tilt gun (barrel dips - realistic front tilt)
	var target_rot = original_weapon_rotation + Vector3(weapon_kick_tilt, 0, 0)
	kick_tween.parallel().tween_property(self, "rotation_degrees", target_rot, weapon_kick_time)
	kick_tween.parallel().tween_property(self, "rotation_degrees", original_weapon_rotation, weapon_return_time)
	
	# Raycast for bullet impact (use the actual viewport camera)
	if main_camera:
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			main_camera.global_position,
			main_camera.global_position - main_camera.global_transform.basis.z * 100
		)
		var result = space_state.intersect_ray(query)
		
		if result:
			spawn_impact(result.position, result.normal)
	
	# Emit signal for UI / sound / effects
	emit_signal("weapon_fired", weapon_name)
	emit_signal("ammo_changed", current_ammo, reserve_ammo, weapon_name)
	
	is_shooting = false


# =============================================================================
# RELOADING
# =============================================================================
func reload() -> void:
	if is_reloading or current_ammo == mag_size or reserve_ammo <= 0:
		return
	
	is_reloading = true
	emit_signal("reload_started", weapon_name)
	
	# Slide animation during reload (if weapon has slide)
	if has_slide and slide:
		var axis_prop = "position:" + slide_axis
		var tween = create_tween()
		tween.tween_property(slide, axis_prop, slide_reload_movement, slide_fire_time * 3)
	
	# Pull hammer back to cocked position on reload (if weapon has hammer)
	if has_hammer and hammer_pivot:
		var hammer_tween = create_tween()
		hammer_tween.tween_property(hammer_pivot, "rotation_degrees:x", hammer_cocked_rotation, 0.2)
	
	await get_tree().create_timer(reload_time).timeout
	
	# Refill magazine
	var needed = mag_size - current_ammo
	var to_reload = min(needed, reserve_ammo)
	current_ammo += to_reload
	reserve_ammo -= to_reload
	
	# Return slide to position
	if slide:
		var tween = create_tween()
		tween.tween_property(slide, "position:y", slide_original_y, 0.1)
	
	is_reloading = false
	is_shooting = false
	emit_signal("reload_finished", weapon_name)
	emit_signal("ammo_changed", current_ammo, reserve_ammo, weapon_name)


# =============================================================================
# WEAPON BOB & SWAY
# =============================================================================
func _update_weapon_bob_and_sway(delta: float):
	if not main_camera:
		return
	
	if not owning_player:
		return
	
	var velocity = owning_player.velocity
	var speed = velocity.length()
	var is_moving = speed > 0.5 and owning_player.is_on_floor()
	
	# === BOBBING ===
	var bob_offset = 0.0
	if is_moving:
		bob_time += delta * weapon_bob_speed
		bob_offset = sin(bob_time) * weapon_bob_amount * clamp(speed / 3.5, 0.3, 1.0)
	
	# === SWAY (clean system - works with recoil) ===
	# Target based on camera rotation
	var target_sway_x = -main_camera.rotation.x * weapon_sway_amount * 2.2   # Up/Down
	var target_sway_y = -main_camera.rotation.y * weapon_sway_amount * 1.6   # Left/Right
	
	# Lerp toward target (this is the "following" feel)
	sway_offset.x = lerp(sway_offset.x, target_sway_x, delta * weapon_sway_speed)
	sway_offset.y = lerp(sway_offset.y, target_sway_y, delta * weapon_sway_speed)
	
	# Apply additive (doesn't fight with recoil)
	position = original_weapon_position + Vector3(0, bob_offset, 0)
	rotation_degrees.x = original_weapon_rotation.x + sway_offset.x * 50
	rotation_degrees.y = original_weapon_rotation.y + sway_offset.y * 45


# =============================================================================
# VISUAL EFFECTS
# =============================================================================
func spawn_impact(impact_position: Vector3, normal: Vector3) -> void:
	var impact = MeshInstance3D.new()
	impact.mesh = SphereMesh.new()
	impact.mesh.radius = 0.08
	impact.mesh.height = 0.16
	impact.position = impact_position + normal * 0.02
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.5, 0.3)
	impact.material_override = material
	
	get_tree().current_scene.add_child(impact)
	
	var tween = create_tween()
	tween.tween_property(impact, "scale", Vector3.ZERO, 0.3)
	await tween.finished
	impact.queue_free()


# =============================================================================
# HELPER FUNCTIONS (for future weapon switching / ammo pickups)
# =============================================================================
func add_ammo(amount: int) -> void:
	reserve_ammo = min(reserve_ammo + amount, max_reserve)
	emit_signal("ammo_changed", current_ammo, reserve_ammo, weapon_name)


func get_ammo_info() -> Dictionary:
	return {
		"weapon_name": weapon_name,
		"current_ammo": current_ammo,
		"reserve_ammo": reserve_ammo,
		"mag_size": mag_size,
		"ammo_type": ammo_type
	}


func is_empty() -> bool:
	return current_ammo <= 0 and reserve_ammo <= 0
