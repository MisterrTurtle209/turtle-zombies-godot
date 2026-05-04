extends Node3D

# Barricade system - ready for zombie breaking
var planks = []
var broken_count = 0

func _ready():
    # Collect all plank references
    planks = $HorizontalPlanks.get_children() + $VerticalPlanks.get_children()
    
    # Store for later use
    set_meta("planks", planks)
    set_meta("broken_count", 0)

func break_plank():
    if broken_count >= planks.size():
        return false
    
    var plank = planks[broken_count]
    if plank:
        # Simple break effect - hide the plank
        plank.visible = false
        
        # TODO: Add particle effect, sound, etc.
        broken_count += 1
        set_meta("broken_count", broken_count)
        
        return true
    return false

func is_fully_broken():
    return broken_count >= planks.size()