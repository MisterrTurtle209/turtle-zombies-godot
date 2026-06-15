extends Control

var health_bar: ProgressBar
var points_label: Label
var ammo_label: Label
var stamina_bar: ProgressBar
var stamina_ui: Control

func _ready():
    # Get node references safely
    health_bar = get_node_or_null("HealthBar")
    points_label = get_node_or_null("Points")
    ammo_label = get_node_or_null("AmmoContainer/Ammo")
    stamina_ui = get_node_or_null("StaminaUI")
    
    if stamina_ui:
        stamina_bar = stamina_ui.get_node_or_null("StaminaBar")
    
    # Initialize HUD values
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

func update_ammo(current: int, reserve: int, weapon_name: String = "Weapon"):
    if ammo_label:
        ammo_label.text = "%s\n%d / %d" % [weapon_name, current, reserve]

func update_stamina(stamina: float, should_show: bool = false):
    if stamina_bar:
        stamina_bar.value = stamina
    if stamina_ui:
        # Show stamina bar when sprinting or stamina is low
        stamina_ui.visible = should_show or stamina < 100

func show_low_ammo_warning(is_low: bool, is_empty: bool):
    var low_ammo_label = get_node_or_null("LowAmmoLabel")
    var no_ammo_label = get_node_or_null("NoAmmoLabel")
    
    if not low_ammo_label or not no_ammo_label:
        return
    
    if is_empty:
        # Show NO AMMO (red, pulsing)
        low_ammo_label.visible = false
        no_ammo_label.visible = true
        var pulse = sin(Time.get_ticks_msec() / 500.0) * 0.3 + 0.7
        no_ammo_label.modulate.a = pulse
    elif is_low:
        # Show LOW AMMO (yellow, pulsing)
        low_ammo_label.visible = true
        no_ammo_label.visible = false
        var pulse = sin(Time.get_ticks_msec() / 500.0) * 0.3 + 0.7
        low_ammo_label.modulate.a = pulse
    else:
        # Hide both
        low_ammo_label.visible = false
        no_ammo_label.visible = false