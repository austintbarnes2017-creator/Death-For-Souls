# Shared Context: Architectural Blueprint
This document mirrors the core standards defined in `ARCHITECTURAL_BLUEPRINT.md`. All agents (Antigravity & Radiance) must adhere to these rules.

## 1. Composition Over Inheritance (CBSE)
- **Do not** add code directly to `CharacterBodySoulsBase.gd` if it can be a separate component.
- All new systems (Mana, Stamina, Inventory) must be isolated nodes under the `player` or `systems` hierarchy.

## 2. Server Authority
- The server is the absolute truth for physics and combat.
- Clients predict motion via `MovementComponent` but MUST reconcile to `server_state`.
- No damage calculations should ever happen solely on the client.

## 3. Node Hierarchy
- `res://components/`: Reusable logic nodes.
- `res://entities/`: NPCs and breakables.
- `res://systems/`: Global managers and networking.

## 4. Conflict Prevention
- Preference: Add new functionality to new files, keep shared file modifications to simple bridge/signal calls.

## 5. UI & Interface
- **MANDATORY**: Follow `docs/godot_ui_best_practices.md` to prevent "Hidden Parent" visibility bugs and variable shadowing.

