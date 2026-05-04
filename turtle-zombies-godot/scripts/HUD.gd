extends Control

@onready var health_bar = $HealthBar
@onready var points_label = $Points
@onready var ammo_label = $Ammo
@onready var stamina_bar = $StaminaUI/StaminaBar
@onready var stamina_ui = $StaminaUI

func _ready():
    # Initialize HUD
    if health_bar:
        health_bar.value = 100
    if points_label:
        points_label.text = "000500"
    if ammo_label:
        ammo_label.text = "M1911\n8 / 40"
    if stamina_bar:
        stamina_bar.value = 100
    if stamina_ui:
        stamina_ui.visible = false

func update_health(health: float):
    if health_bar:
        health_bar.value = health

func update_points(points: int):
    if points_label:
        points_label.text = str(points).pad_zeros(6)

func update_ammo(current: int, reserve: int):
    if ammo_label:
        ammo_label.text = "M1911\n%d / %d" % [current, reserve]

func update_stamina(stamina: float, show: bool = false):
    if stamina_bar:
        stamina_bar.value = stamina
    if stamina_ui:
        stamina_ui.visible = show or stamina < 100