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

# References
@onready var weapon = $Camera3D/M1911
@onready var hud = get_node("/root/Main/HUD")

func _ready():
    camera = $Camera3D
    original_camera_y = camera.position.y
    
    # Lock mouse
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    
    # Initial FOV
    camera.fov = current_fov

func _input(event):
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x * MOUSE_SENSITIVITY
        pitch -= event.relative.y * MOUSE_SENSITIVITY
        pitch = clamp(pitch, -1.5, 1.5)  # ~85 degrees up/down
        
        rotation.y = yaw
        camera.rotation.x = pitch

func _physics_process(delta):
    handle_input(delta)
    handle_movement(delta)
    handle_stamina(delta)
    handle_view_bobbing(delta)
    update_hud()

func handle_input(_delta):
    # Sprint
    if Input.is_action_pressed("sprint") and stamina > 5 and not sprint_exhausted:
        is_sprinting = true
    else:
        is_sprinting = false
    
    # Crouch
    is_crouching = Input.is_action_pressed("crouch")
    
    # Pause
    if Input.is_action_just_pressed("pause"):
        get_tree().paused = not get_tree().paused
        if get_tree().paused:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        else:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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

func update_hud():
    if hud:
        hud.update_stamina(stamina, is_sprinting or sprint_exhausted)
        if weapon:
            hud.update_ammo(weapon.current_ammo, weapon.reserve_ammo)