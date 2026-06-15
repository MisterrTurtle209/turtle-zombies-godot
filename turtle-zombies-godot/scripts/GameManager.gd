extends Node3D

@onready var pause_menu = get_node_or_null("HUD/PauseMenu")
@onready var player = get_node_or_null("Player")

func _ready():
    if pause_menu:
        pause_menu.visible = false
    get_tree().paused = false

func _input(event):
    if event.is_action_pressed("pause"):
        toggle_pause()

func toggle_pause():
    if not pause_menu:
        return
    
    pause_menu.visible = not pause_menu.visible
    get_tree().paused = pause_menu.visible
    
    if pause_menu.visible:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    else:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_pressed():
    if pause_menu:
        pause_menu.visible = false
    get_tree().paused = false
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_restart_pressed():
    get_tree().paused = false
    get_tree().reload_current_scene()

func _on_exit_pressed():
    get_tree().paused = false
    get_tree().reload_current_scene()