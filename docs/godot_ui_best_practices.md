# Godot UI Best Practices & Common Pitfalls

This guide is for **Agent Beta (Radiance)** and other contributors to ensure UI systems are robust, performant, and bug-free.

## 1. Visibility & Hierarchy
### The "Hidden Parent" Pitfall
- **Issue**: Setting `visible = false` on a parent node recursively hides all its children.
- **Scenario**: You instantiate a sub-menu as a child of the Main Menu and then hide the Main Menu. Result: The sub-menu is also hidden (blank screen).
- **Best Practice**: Instead of hiding the entire root node, hide only the specific containers or buttons that belong to that screen (e.g., `TitleContainer`, `ButtonsContainer`). This allows the background to remain and the new sub-menu to be visible.

```gdscript
# BAD: Hides children too
visible = false 

# GOOD: Hides only specific UI elements
main_buttons.visible = false
title_container.visible = false
```

## 2. Scene Transitions
- **Prefer Instantiation**: For sub-menus (Settings, Credits), use `instantiate()` and `add_child()` rather than `change_scene_to_file()`. This allows for smoother transitions and easier "Back" functionality.
- **Signal Handlers**: Always ensure "Back" buttons are connected to signals that restore the previous UI state.

## 3. Container Management
- **Size Flags**: Use `Expand` and `Fill` judiciously. If a container isn't resizing correctly, check the `size_flags_horizontal` and `size_flags_vertical` of its children.
- **Theme Overrides**: Use `add_theme_constant_override()` or `add_theme_stylebox_override()` instead of directly modifying inherited theme properties in code, as this ensures local changes don't bleed into other UI elements.

## 4. GDScript Pitfalls
- **Unreachable Code**: Be careful with `return` statements. Always ensure there is no code logic following a `return` or a `break` in the same branch.
- **Node References**: Prefer `@onready var` for node references. Avoid `get_node()` inside loops or `_process` for performance.
- **Obsolete API**: In Godot 4, use `get_tree().quit()` instead of just `quit()`.

## 5. UI Scaling
- Always test UI in different window sizes. Use anchors and containers (VBox, HBox, MarginContainer) rather than absolute positioning.
