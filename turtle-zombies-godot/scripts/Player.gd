extends CharacterBody3D

# Movement constants (matching our Three.js feel)
const MOVE_SPEED = 4.6
const SPRINT_MULT = 1.35
const CROUCH_MULT = 0.5
const FRICTION = 0.82
const MOUSE_SENSITIVITY = 0.002

# Stamina system
const MAX_STAMINA = 100.0
const SPRINT_DRAIN = 22.2
const SPRINT_RECHARGE = 25.0
const SPRINT_COOLDOWN_TIME = 3.0

# State variables
var stamina = MAX_STAMINA
var is_sprinting = false
var is_crouching = false
var sprint_exhausted = false
var sprint_cooldown = 0.0

# Camera and movement
var camera: Camera3D
var original_camera_y: float
var velocity_xz = Vector2.ZERO
var yaw = 0.0
var pitch = 0.0

# View bobbing
var bob_time = 0.0
var current_fov = 72.0
var hud_update_timer: float = 0.0
const HUD_STAMINA_UPDATE_INTERVAL = 0.15  # seconds

# References
@onready var weapon_holder: Node3D = $Camera3D/WeaponHolder
@onready var weapon: Weapon = $Camera3D/WeaponHolder/M1911

# HUD reference is wired in the scene (Main.tscn -> Player instance).
# This replaces the previous brittle absolute path get_node("/root/Main/HUD").
@export var hud: Control

# Future-proof: support for multiple weapons
var current_weapon: Weapon = null

func _ready():
	camera = $Camera3D
	original_camera_y = camera.position.y
	
	# Lock mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Initial FOV
	camera.fov = current_fov
	
	# Set up weapon signal connection (much better than polling every frame)
	if weapon:
		current_weapon = weapon
		weapon.ammo_changed.connect(_on_weapon_ammo_changed)
		weapon.owning_player = self   # Clean reference for bob/sway (avoids parent walking)
		# Initial HUD update
		_on_weapon_ammo_changed(weapon.current_ammo, weapon.reserve_ammo, weapon.weapon_name)
	
	if not hud:
		push_warning("Player HUD reference not set (assign the HUD node to the exported 'Hud' property on the Player instance in Main.tscn)")

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENSITIVITY
		pitch -= event.relative.y * MOUSE_SENSITIVITY
		pitch = clamp(pitch, -1.5, 1.5)  # ~85 degrees up/down
		
		rotation.y = yaw
		camera.rotation.x = pitch

func _physics_process(delta):
	if get_tree().paused:
		return
	
	handle_input(delta)
	handle_movement(delta)
	handle_stamina(delta)
	handle_view_bobbing(delta)
	
	# Update stamina on HUD periodically (not every frame)
	hud_update_timer += delta
	if hud_update_timer >= HUD_STAMINA_UPDATE_INTERVAL:
		hud_update_timer = 0.0
		if hud and current_weapon:
			hud.update_stamina(stamina, is_sprinting or sprint_exhausted)

func handle_input(_delta):
	if get_tree().paused:
		return
	
	# Sprint
	if Input.is_action_pressed("sprint") and stamina > 5 and not sprint_exhausted:
		is_sprinting = true
	else:
		is_sprinting = false
	
	# Crouch
	is_crouching = Input.is_action_pressed("crouch")
	
	# Note: Pause is now fully owned by GameManager (single source of truth).
	# Player no longer toggles pause or mouse mode directly. This eliminates duplication.

func handle_movement(_delta):
	var input_dir = Vector2.ZERO
	
	if Input.is_action_pressed("move_forward"):
		input_dir.y += 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	
	input_dir = input_dir.normalized()
	
	# Calculate movement speed
	var speed = MOVE_SPEED
	if is_sprinting:
		speed *= SPRINT_MULT
	if is_crouching:
		speed *= CROUCH_MULT
	
	# Apply movement
	var direction = (transform.basis * Vector3(input_dir.x, 0, -input_dir.y)).normalized()
	
	if direction:
		velocity_xz = velocity_xz.lerp(Vector2(direction.x, direction.z) * speed, 1.0 - FRICTION)
	else:
		velocity_xz = velocity_xz * FRICTION
	
	velocity.x = velocity_xz.x
	velocity.z = velocity_xz.y
	velocity.y = 0  # No jumping/gravity for now
	
	move_and_slide()

func handle_stamina(delta):
	if is_sprinting and stamina > 0:
		stamina -= SPRINT_DRAIN * delta
		sprint_cooldown = SPRINT_COOLDOWN_TIME
		if stamina <= 0:
			sprint_exhausted = true
			is_sprinting = false
	else:
		if sprint_cooldown > 0:
			sprint_cooldown -= delta
		else:
			stamina = min(stamina + SPRINT_RECHARGE * delta, MAX_STAMINA)
			if stamina >= MAX_STAMINA:
				sprint_exhausted = false

func handle_view_bobbing(delta):
	var speed = velocity.length()
	var bob_amount = 0.0
	var bob_speed = 0.0
	var cam_pos = camera.position  # Use different variable name to avoid shadowing
	
	if speed > 0.1 and is_on_floor():
		if is_sprinting:
			bob_amount = 0.08
			bob_speed = 12.0
			current_fov = lerp(current_fov, 76.0, delta * 5.0)
		else:
			bob_amount = 0.05
			bob_speed = 8.0
			current_fov = lerp(current_fov, 72.0, delta * 5.0)
	else:
		current_fov = lerp(current_fov, 72.0, delta * 3.0)
	
	bob_time += delta * bob_speed
	var bob_offset = sin(bob_time) * bob_amount
	
	cam_pos.y = original_camera_y + bob_offset
	camera.position = cam_pos
	camera.fov = current_fov

func apply_recoil(recoil_amount: float, _drift_amount: float):
	pitch += recoil_amount
	pitch = clamp(pitch, -1.5, 1.5)
	camera.rotation.x = pitch


# Called automatically when the weapon emits ammo_changed signal
func _on_weapon_ammo_changed(current: int, reserve: int, weapon_name: String):
	if hud:
		hud.update_ammo(current, reserve, weapon_name)
		
		# Low ammo warning logic (based on reserve)
		var is_empty = current <= 0 and reserve <= 0
		var is_low = reserve <= 0 and current > 0
		hud.show_low_ammo_warning(is_low, is_empty)
	
	# Also update stamina every time ammo changes (cheap and keeps HUD fresh)
	if hud:
		hud.update_stamina(stamina, is_sprinting or sprint_exhausted)
