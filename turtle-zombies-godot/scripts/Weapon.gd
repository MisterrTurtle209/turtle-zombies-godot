extends Node3D

# Weapon stats (matching our Three.js M1911)
const MAG_SIZE = 8
const MAX_RESERVE = 80
const FIRE_RATE = 0.12  # seconds between shots
const RELOAD_TIME = 0.8

# State
var current_ammo = MAG_SIZE
var reserve_ammo = 40
var last_shot_time = 0.0
var is_reloading = false
var is_shooting = false

# References
@onready var muzzle_flash = $MuzzleFlash
@onready var slide = $Slide
@onready var camera = get_parent()

# Recoil
var recoil_pitch = 0.0
var original_rotation = Vector3.ZERO

func _ready():
    original_rotation = rotation
    if muzzle_flash:
        muzzle_flash.visible = false

func _process(delta):
    # Handle shooting
    if Input.is_action_pressed("shoot") and not is_reloading and not is_shooting:
        shoot()
    
    # Handle reload
    if Input.is_action_just_pressed("reload") and not is_reloading:
        reload()
    
    # Update recoil recovery
    if recoil_pitch > 0:
        recoil_pitch = lerp(recoil_pitch, 0.0, delta * 8.0)
        camera.rotation.x = original_rotation.x + recoil_pitch

func shoot():
    var current_time = Time.get_ticks_msec() / 1000.0
    if current_time - last_shot_time < FIRE_RATE:
        return
    
    if current_ammo <= 0:
        # Auto reload if empty
        if reserve_ammo > 0:
            reload()
        return
    
    last_shot_time = current_time
    current_ammo -= 1
    is_shooting = true
    
    # Recoil (upward kick + slight drift)
    recoil_pitch += 0.014
    camera.rotation.x += 0.009  # upward drift
    
    # Muzzle flash
    if muzzle_flash:
        muzzle_flash.visible = true
        await get_tree().create_timer(0.05).timeout
        if muzzle_flash:
            muzzle_flash.visible = false
    
    # Slide animation
    if slide:
        var tween = create_tween()
        tween.tween_property(slide, "position:z", -0.08, 0.05)
        tween.tween_property(slide, "position:z", 0.0, 0.1)
    
    # Bullet impact (raycast)
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(
        camera.global_position,
        camera.global_position - camera.global_transform.basis.z * 100
    )
    var result = space_state.intersect_ray(query)
    
    if result:
        # Create impact effect
        spawn_impact(result.position, result.normal)
    
    is_shooting = false

func reload():
    if is_reloading or current_ammo == MAG_SIZE or reserve_ammo <= 0:
        return
    
    is_reloading = true
    
    # Slide back animation
    if slide:
        var tween = create_tween()
        tween.tween_property(slide, "position:z", -0.15, 0.2)
    
    await get_tree().create_timer(RELOAD_TIME).timeout
    
    # Refill magazine
    var needed = MAG_SIZE - current_ammo
    var to_reload = min(needed, reserve_ammo)
    current_ammo += to_reload
    reserve_ammo -= to_reload
    
    # Slide forward
    if slide:
        var tween = create_tween()
        tween.tween_property(slide, "position:z", 0.0, 0.15)
    
    is_reloading = false

func spawn_impact(position: Vector3, normal: Vector3):
    # Simple impact effect (can be replaced with particles later)
    var impact = MeshInstance3D.new()
    impact.mesh = SphereMesh.new()
    impact.mesh.radius = 0.08
    impact.mesh.height = 0.16
    impact.position = position + normal * 0.02
    
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0.6, 0.5, 0.3)
    impact.material_override = material
    
    get_tree().current_scene.add_child(impact)
    
    # Fade out and remove
    var tween = create_tween()
    tween.tween_property(impact, "scale", Vector3.ZERO, 0.3)
    await tween.finished
    impact.queue_free()