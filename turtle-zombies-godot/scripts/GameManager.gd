extends Node3D

@onready var pause_menu = $HUD/PauseMenu
@onready var player = $Player

var game_in_progress = true

func _ready():
    pause_menu.visible = false
    get_tree().paused = false

func _on_resume_pressed():
    pause_menu.visible = false
    get_tree().paused = false
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_restart_pressed():
    get_tree().paused = false
    get_tree().reload_current_scene()

func _on_exit_pressed():
    get_tree().paused = false
    # For now just reload - in full game this would go to main menu
    get_tree().reload_current_scene()

func toggle_pause():
    pause_menu.visible = not pause_menu.visible
    get_tree().paused = pause_menu.visible
    
    if pause_menu.visible:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    else:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)