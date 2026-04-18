# Architectural Blueprint for a Godot 4 Multiplayer Souls-Like RPG

## Systems Integration and Parallel Development Framework

> [!IMPORTANT]
> **This document is mandatory reading for all human developers and AI agents contributing to this repository.**
> Every code change, plugin integration, and scene modification **must** conform to the rules defined herein. Violations will cause cascading merge conflicts and architectural regression.

---

## Table of Contents

1. [Executive Overview](#1-executive-overview)
2. [Current Codebase Anatomy](#2-current-codebase-anatomy)
3. [Core Architectural Pillars](#3-core-architectural-pillars)
4. [Multiplayer Networking Infrastructure](#4-multiplayer-networking-infrastructure)
5. [Open-World Generation and Level Streaming](#5-open-world-generation-and-level-streaming)
6. [RPG Systems: AI, Inventory, and Quests](#6-rpg-systems-ai-inventory-and-quests)
7. [User Interface and Dark Fantasy Asset Integration](#7-user-interface-and-dark-fantasy-asset-integration)
8. [Parallel Development Workflow and Version Control](#8-parallel-development-workflow-and-version-control)
9. [6-Phase Execution Roadmap (Agent-Ready)](#9-6-phase-execution-roadmap-agent-ready)
10. [Technical Stack Reference Table](#10-technical-stack-reference-table)

---

## 1. Executive Overview

The "Death For Souls" project is a multiplayer action-RPG built on the [Cats-Godot4-Modular-Souls-like-Template](https://github.com/catprisbrey/Cats-Godot4-Modular-Souls-like-Template). The foundational mechanics of a "souls-like" experience—precision timing, interruptible animation-driven combat, root-motion character physics, and unforgiving hit registration—introduce extreme computational complexities when adapted for distributed network environments.

Translating these inherently solitary mechanics into a seamless cooperative or competitive multiplayer experience requires:

1. **Authoritative server architectures** paired with client-side prediction algorithms that mask transmission delays.
2. **Dynamic level streaming** to manage open-world memory without severing multiplayer synchronization.
3. **Component-based software engineering** to enable parallel AI-agent development without Git merge conflicts.

This document provides the exhaustive, structurally rigid blueprint for constructing every system layer.

### Project Metadata

| Property | Value |
| :--- | :--- |
| **Engine** | Godot 4.6+ (GL Compatibility renderer) |
| **Language** | GDScript (with C++ GDExtension for performance-critical plugins) |
| **Base Template** | Cats-Godot4-Modular-Souls-like-Template |
| **Repository** | `github.com/austintbarnes2017-creator/Death-For-Souls` |
| **Current Autoloads** | `Global.gd` (character/admin state), `CombatFeedback` (utility) |
| **Physics Layers** | World (1), Player (2), Targets (3), Interactable (4), Ladder (5) |

---

## 2. Current Codebase Anatomy

Before modifying anything, every agent **must** understand the existing structure. The template is **not** a blank slate—it contains deeply interconnected signal-driven systems.

### 2.1 Directory Structure (Current State)

```
res://
├── addons/              # Editor plugins (currently: copy_all_errors)
├── assets/              # 3D models, textures, materials, characters
│   └── characters/      # skin_f.tres, skin_m.tres, eye materials
├── audio/               # Sound effects and music
├── cameras/             # Follow camera system (follow_cam_3d.gd)
├── components/          # [NEW - EMPTY] Future compositional components
├── demo_level/          # World castle scene, world materials, gridmap
├── enemy/               # Enemy base controller, health system, patrol AI
├── entities/            # [NEW - EMPTY] Future entity assemblies
├── interactable objects/# Ladders, doors, levers, spawn sites
├── levels/              # [NEW - EMPTY] Future level chunks
├── player/              # Character controller, animation tree, equipment
│   ├── animation_libraries/  # 110+ pre-configured animation files
│   ├── equipment_system/     # Weapons (Ax, Shield), equipment manager
│   ├── footfall_system/      # Step sound effects
│   ├── item_system/          # Consumable items, inventory resources
│   ├── player_interact_sensors/ # Raycast-based interaction detection
│   └── player_targeting_system/ # Lock-on / strafe targeting
├── systems/             # [NEW - EMPTY] Future global systems
├── ui/                  # Main menu, character creation, HUD, admin panel
└── utility/             # Combat feedback singleton
```

### 2.2 Core Scripts and Their Responsibilities

#### `CharacterBodySoulsBase` (player/character_body_souls_base.gd — 862 lines)

This is the **central player controller**. It is currently a monolithic script that manages:

| Responsibility | Key Variables / Signals |
| :--- | :--- |
| **State Machine** | `enum state {SPAWN, FREE, STATIC_ACTION, DYNAMIC_ACTION, DODGE, SPRINT, LADDER, ATTACK}` |
| **Movement** | `input_dir`, `direction`, `speed`, `default_speed`, `walk_speed` |
| **Root Motion Physics** | Displacement extracted from `AnimationTree` root bone accumulator |
| **Combat (Offense)** | `weapon_system`, `weapon_type`, `attack_combo_timer`, signals: `attack_started`, `big_attack_started` |
| **Combat (Defense)** | `gadget_system`, `guarding`, `parry_active`, `parry_window` (0.3s), signals: `parry_started`, `block_started` |
| **Health** | `health_system`, `can_be_hurt`, `is_dead`, signals: `hurt_started`, `death_started` |
| **Inventory** | `inventory_system`, `current_item`, signals: `use_item_started`, `item_used` |
| **Locomotion** | `dodge_speed`, `sprint_speed`, `jump_velocity`, `strafing`, `strafe_cross_product` |
| **Interaction** | `interact_sensor`, `interactable`, `interact_loc` |

> [!WARNING]
> **This script is the #1 merge conflict risk in the entire project.** Any multiplayer refactoring must decompose its responsibilities into isolated component scripts (see [Section 8](#8-parallel-development-workflow-and-version-control)).

#### `AnimationTreeSoulsBase` (player/souls_animation_tree.gd — 233 lines)

The animation companion script. It listens to **every signal** emitted by `CharacterBodySoulsBase` and translates them into animation state transitions:

- **Movement blending**: `set_strafe()` and `set_free_move()` use `lerp()` on blend positions.
- **Oneshot animations**: `request_oneshot()` fires named AnimationNodeOneShot requests (Attack, Dodge, Jump, Parry, etc.).
- **Weapon tree switching**: Dynamically swaps the active movement state machine based on `weapon_type` string (e.g., `SLASH_tree`, `BLUNT_tree`).
- **Attack combos**: `attack_count` alternates between combo stages (1 → 2 → 1), with a timer-based reset.

**Critical for multiplayer**: The `current_animation` string and all blend positions must be synchronized across clients.

#### `CharacterBodyEnemyBase` (enemy/CharacterBodyEnemyBase.gd)

The enemy controller mirrors the player pattern with simplified AI:
- Basic pathfinding via `NavigationAgent3D`.
- Linear state switching (Idle → Chase → Attack).
- Health system with ragdoll death.

**Multiplayer requirement**: Enemy state must be server-authoritative. Clients must not run enemy physics.

#### `Global.gd` (Autoload Singleton)

Currently manages:
- `current_character: Dictionary` — Active character save data.
- `is_admin: bool` — Admin panel access (file-based, `user://admin.json`).
- Character data serialization to `user://current_character.json`.

**Multiplayer requirement**: This singleton must be split. Character data becomes server-managed. Admin status requires server-side validation (current file-based check is trivially exploitable).

### 2.3 Signal Architecture (Observer Pattern)

The template is driven by the **Observer pattern**. Nodes fire broadcast signals; listener nodes react independently. This is **critical for multiplayer adaptation** because:

1. Network synchronizer nodes can **intercept signals** to replicate specific state changes.
2. New multiplayer components can **subscribe to existing signals** without rewriting combat logic.
3. The animation tree already listens purely via signals—multiplayer animation sync can be layered on top.

**Signal flow for a single attack:**
```
Player presses attack input
  → CharacterBodySoulsBase._input() validates state
    → attack_started signal emitted
      → AnimationTreeSoulsBase._on_attack_started() fires oneshot
      → [FUTURE] NetworkSyncComponent intercepts → sends RPC to server
        → Server validates collision → broadcasts damage state
          → All clients receive damage confirmation → play VFX
```

---

## 3. Core Architectural Pillars

### 3.1 Root Motion and Animation-Centric Physics

In traditional action games, velocity is dictated by hardcoded vectors in `_physics_process()`. This template uses **root motion-driven physics**:

1. Translation and rotation are extracted from the animation rig's root bone displacement across keyframes.
2. The engine retrieves the motion delta via `animation_tree.get_root_motion_position_accumulator()`.
3. This delta is fed into `CharacterBody3D.move_and_slide()`.

**Why this matters for multiplayer:**
- Attack lunges, dodge rolls, and heavy weapon wind-ups have physical weight that **perfectly matches** their visual representation.
- The server must extract root motion on its headless simulation—it cannot rely on client-reported positions.
- All humanoid models must map to standard skeletal conventions (Godot, Unity, or Mixamo armatures) to ensure the animation library drives physics consistently across character swaps.

### 3.2 Component-Based Software Engineering (CBSE)

**Rule: Composition Over Inheritance. No exceptions.**

The current `CharacterBodySoulsBase` (862 lines) violates this principle. It must be decomposed:

```
player.tscn (CharacterBody3D root — lightweight)
├── MovementComponent.tscn      # input_dir, speed, direction, move_and_slide()
├── CombatComponent.tscn        # weapon_system, gadget_system, attack logic
├── HealthComponent.tscn        # HP, damage, death, can_be_hurt, parry
├── InventoryComponent.tscn     # item management, equipment slots
├── InteractionComponent.tscn   # interact_sensor, ladders, doors
├── AnimationComponent.tscn     # AnimationTree, blend logic, oneshots
├── NetworkSyncComponent.tscn   # MultiplayerSynchronizer, authority checks
└── VisualModelComponent.tscn   # MeshInstance3D, materials, skeletal mesh
```

**Each component is saved as its own `.tscn` file.** This means two developers (or two AI agents) can simultaneously edit `CombatComponent.tscn` and `HealthComponent.tscn` without touching the same file.

### 3.3 Authoritative Dedicated Server Architecture

For precision souls-like combat, the **dedicated server model is the only viable option**:

| Aspect | Client Role | Server Role |
| :--- | :--- | :--- |
| **Input** | Captures keystrokes/joystick, sends to server | Receives and validates input |
| **Physics** | Does NOT run `move_and_slide()` | Extracts root motion, runs physics step |
| **Collision** | Does NOT detect hits | Calculates weapon hitbox vs. enemy hurtbox overlap |
| **Animation** | Plays predicted animations locally | Runs headless animation for collision timing |
| **State** | Renders server-broadcast state | Maintains authoritative game state |
| **VFX** | Instantiates particles on damage confirmation | Does NOT render graphics |

**Why not Peer-to-Peer?**
- P2P introduces latency fluctuations dependent on the host's network quality.
- Hit registration becomes **luck-based** rather than skill-based.
- P2P inherently trusts the client—any player can broadcast fraudulent damage values.
- For a competitive or punishing action RPG, P2P is architecturally unacceptable.

---

## 4. Multiplayer Networking Infrastructure

### 4.1 High-Level Multiplayer API: Spawners and Synchronizers

Godot 4 provides scene replication nodes:

**`MultiplayerSpawner`**: Automates instantiation/destruction of nodes across the network.
- Configure a spawn path and maintain identical scene tree structure on client and server.
- Use for: player avatars, dropped loot meshes, instantiated spells/projectiles.

**`MultiplayerSynchronizer`**: Manages continuous state replication.
- Bind these properties: `global_transform`, `velocity`, `current_animation` string, blend positions.
- **Cannot** synchronize custom `Resource` types (e.g., `ItemResource`). These require RPC handling.
- Isolate the player model's transform from the kinematic body for interpolation separation.

### 4.2 Client-Side Prediction and Server Reconciliation

Pure server authority introduces **input delay** (~100ms round-trip). In a souls-like, this makes the game feel unplayable. The solution:

```
1. Player presses dodge
2. LOCAL CLIENT immediately plays dodge animation and moves character (PREDICTION)
3. Input vector + frame timestamp is sent to server
4. Server processes the input chronologically
5. Server broadcasts authoritative state to all clients
6. IF client predicted position diverges from server position beyond threshold:
   → Client snaps to server coordinates (RECONCILIATION)
   → Visual mesh interpolates the difference to smooth the transition
```

**Recommended addon**: [Netfox](https://github.com/foxssake/netfox) — provides lag compensation, client-side prediction, and server reconciliation frameworks for Godot 4. This eliminates the need to manually implement frame buffer interpolation mathematics.

### 4.3 Combat Hit Registration (Server-Side Only)

```gdscript
# CLIENT: Sends attack intent to server
@rpc("any_peer", "call_local", "reliable")
func request_attack(attack_type: String, timestamp: int) -> void:
    if not multiplayer.is_server():
        return
    
    # Server validates the attack
    var attacker_id = multiplayer.get_remote_sender_id()
    var attacker_node = get_player_by_id(attacker_id)
    
    # Server plays the attack animation on its headless simulation
    attacker_node.play_attack(attack_type)
    
    # Server checks weapon hitbox vs. all enemy hurtboxes
    var overlapping_areas = attacker_node.weapon_hitbox.get_overlapping_areas()
    for area in overlapping_areas:
        var target = area.get_parent()
        if target.has_method("take_damage"):
            var damage = calculate_damage(attacker_node, target)
            target.take_damage(damage)
            
            # Broadcast confirmed damage to all clients for VFX
            broadcast_damage_event.rpc(target.get_path(), damage)
```

**Key constraint**: Clients **never** detect collisions. They only render visual feedback (particles, camera shake, hit-stop) upon receiving server confirmation.

### 4.4 Backend Infrastructure Options

| Solution | Pros | Cons | Constraint |
| :--- | :--- | :--- | :--- |
| **GD-Sync** | Managed backend, global relays, no port-forwarding, built-in property sync | Indie tier: 8 player lobby cap, 50GB/month data limit | Best for rapid prototyping |
| **ENet + Netfox** | Full control, authoritative server, lag compensation built-in | Requires self-hosted server infrastructure | Best for production |
| **Steam Networking** | NAT traversal, relay fallback, massive existing player base | Steam-exclusive distribution | Best for Steam release |

---

## 5. Open-World Generation and Level Streaming

Loading an entire open-world geometry into the GPU simultaneously will **catastrophically throttle performance**. The architecture requires chunk-based streaming.

### 5.1 Open World Database (OWDB)

The [OWDB addon](https://godotengine.org/asset-library/asset/2650) provides:

- **Automatic chunk management**: Batches loading/unloading of scene nodes based on volumetric size and proximity to the player.
- **Seamless boundary transitions**: Prevents unexpected node deletion and preserves custom properties across load boundaries.
- **Multiplayer networking layer**: Solves a critical Godot limitation—`MultiplayerSynchronizer` and `MultiplayerSpawner` struggle with dynamically changing scene trees.
  - OWDB's networking layer integrates **chunk-based visibility**: the server only synchronizes entities within the active chunks rendered by a specific client.
  - This prevents broadcasting coordinates of thousands of distant enemies, preserving bandwidth.

### 5.2 Terrain3D

[Terrain3D](https://github.com/TokisanGames/Terrain3D) provides:

- **Clipmap-based LOD generation**: Dynamic level-of-detail for terrain geometry.
- **Foliage instancing**: Renders vast forests/grass without crippling the render thread.
- **Code-generated spatial object**: Not a static pre-compiled mesh—can be synchronized over multiplayer.
- **Collision synchronization**: When nested within spawner nodes, all clients calculate identical collision heights, preventing root-motion characters from clipping through ground or floating.

### 5.3 Integration Pattern

```
WorldRoot (Node3D)
├── OWDB_Manager (OWDB root)
│   ├── Chunk_0_0.tscn (auto-loaded when player is near)
│   │   ├── Terrain3D instance
│   │   ├── StaticEnvironment (trees, rocks, buildings)
│   │   └── EnemySpawnPoints
│   ├── Chunk_0_1.tscn (unloaded when player is far)
│   └── Chunk_1_0.tscn
├── MultiplayerSpawner (manages player instantiation)
└── NetworkManager (autoload singleton)
```

---

## 6. RPG Systems: AI, Inventory, and Quests

### 6.1 Enemy AI: LimboAI (C++ GDExtension)

**Why LimboAI over Beehave?**
- Beehave (pure GDScript) suffers **severe performance degradation** with large entity clusters.
- LimboAI (C++ GDExtension) simulates hundreds of concurrent agents without frame drops.
- LimboAI combines **Behavior Trees** with **Hierarchical State Machines**.
- **Blackboard system**: Centralized memory where tasks read/write shared variables.
- **Blackboard scopes**: Enable coordinated squad tactics across multiple agents.

**Example behavior tree for a souls-like enemy:**
```
Selector
├── Sequence [Is Dead?]
│   └── Action: Play death animation, trigger ragdoll, spawn loot
├── Sequence [Player Detected?]
│   ├── Condition: Distance to player < aggro_range
│   ├── Selector
│   │   ├── Sequence [In Attack Range?]
│   │   │   ├── Condition: Distance < attack_range
│   │   │   └── Action: Execute attack (choose from combo tree)
│   │   └── Sequence [Chase]
│   │       └── Action: Navigate toward player (NavigationAgent3D)
├── Sequence [Patrol]
│   └── Action: Move between patrol_point nodes
└── Action: Idle animation
```

### 6.2 Inventory Serialization over Multiplayer

Godot's `MultiplayerSynchronizer` **cannot** synchronize custom `Resource` types (like `ItemResource`). Inventory must use **validated RPCs**:

```gdscript
# CLIENT → SERVER: Request to equip item by string ID
@rpc("any_peer", "call_local", "reliable")
func request_equip_item(item_id: String) -> void:
    if not multiplayer.is_server():
        return
    
    var requester_id = multiplayer.get_remote_sender_id()
    
    # Server validates: Does this player actually own this item?
    if not inventory_database.player_has_item(requester_id, item_id):
        return  # Reject fraudulent request
    
    # Server updates authoritative inventory state
    inventory_database.equip_item(requester_id, item_id)
    
    # Server tells ALL clients to visually equip the item
    confirm_equip_item.rpc(requester_id, item_id)

# SERVER → ALL CLIENTS: Visual confirmation
@rpc("authority", "call_local", "reliable")
func confirm_equip_item(player_id: int, item_id: String) -> void:
    var player_node = get_player_by_id(player_id)
    var weapon_scene = load("res://player/equipment_system/equipment/" + item_id + ".tscn")
    player_node.attach_weapon(weapon_scene.instantiate())
```

### 6.3 Instanced Loot (Not Shared Loot)

Shared loot creates player friction and discourages cooperation. Use **instanced loot**:

1. Enemy dies → server calculates drop tables using `RandomNumberGenerator`.
2. Server sends targeted RPC **only** to the killer's `peer_id` (or party members).
3. Each client renders its own loot meshes locally.
4. Players in the same space see **different** loot—no competition, no anxiety.

### 6.4 Narrative and Quest Systems

| System | Addon | Architectural Justification |
| :--- | :--- | :--- |
| **Dialogue** | [DialogueQuest](https://github.com/hohfchns/DialogueQuest) | Standalone testing app isolates writers from the codebase. Writers cannot accidentally break scripts. |
| **Quests** | [Simple Quest System](https://godotengine.org/asset-library/asset) | Modular design with custom `Resource` handling for dynamic open-world objective tracking. Quest states update via the established RPC matrix. |

---

## 7. User Interface and Dark Fantasy Asset Integration

### 7.1 Scaling UI Rules

- **Always use `Control` nodes** with anchor-based positioning.
- **Never use raw pixel coordinates** — the HUD must scale across all monitor resolutions.
- Maintain a **minimalist, diegetic** UI aesthetic (information conveyed without obscuring the 3D environment).

### 7.2 3D Item Previews in 2D Inventory (SubViewport Technique)

To render 3D weapon models inside 2D inventory grids (like Elden Ring):

```
InventorySlot (TextureRect)
└── SubViewport (hidden, 128×128)
    ├── Camera3D (fixed angle, orthographic)
    ├── DirectionalLight3D (rim lighting)
    └── WeaponMesh (instantiated 3D model)

# The SubViewport generates a ViewportTexture
# → Assigned to the TextureRect's texture property
# Result: High-fidelity 3D item icons rendered in real-time
```

### 7.3 Asset Sources

| Asset Type | Source | License |
| :--- | :--- | :--- |
| **UI Theme** | [Azagaya Minimalistic UI](https://azagaya.itch.io) | Open-source (Open Sans font) |
| **3D Props** | [Kenney](https://kenney.nl), [Quaternius](https://quaternius.com) | CC0 (public domain) |
| **Dark Fantasy Icons** | itch.io medieval UI packs | Varies (check per pack) |
| **Typography** | "Olde Tome", "Darinia", or similar gothic fonts | Check license per font |

---

## 8. Parallel Development Workflow and Version Control

### 8.1 The Problem: Why Godot Projects Corrupt Under Parallel Development

Godot 4 stores scenes as `.tscn` text files. When two developers edit nodes in the **same scene**:

1. The `load_steps` metadata at the top of the file changes (it counts total resources).
2. External resource reference indices shift.
3. Git **cannot** resolve these overlapping mathematical modifications.
4. Result: **Catastrophic merge conflict** that corrupts the scene file.

The `project.godot` file is equally dangerous—adding input maps, autoloads, or window settings alters a monolithic config that is extremely sensitive to concurrent edits.

### 8.2 The Solution: Strict Isolation Rules

> [!CAUTION]
> **ALL developers and AI agents must follow these rules without exception.**

#### Rule 1: Absolute Scene File Isolation

If Agent Alpha is modifying `player.tscn`, Agent Beta **must not open or modify it**. Agents must **declare target files** in their branch name or commit message before initiating writes.

#### Rule 2: Component Scenes Over Monolithic Scenes

Every functional unit is saved as its own `.tscn` file. The main entity scenes are assembled purely through instancing. Two agents editing `CombatComponent.tscn` and `HealthComponent.tscn` simultaneously will **never** trigger a Git conflict.

#### Rule 3: @export Variables Over Hardcoding

Scripts must use `@export` variables extensively:
```gdscript
# GOOD: Agent Alpha writes the logic once. Agent Beta tunes values in the Inspector.
@export var parry_window: float = 0.3
@export var dodge_speed: float = 10.0
@export var sprint_speed: float = 7.0

# BAD: Hardcoded values require opening the .gd file to change.
var parry_window = 0.3
```

#### Rule 4: Ephemeral Feature Branches

- Branches must be **hyper-specific**: `feature/implement-dodge-stamina-drain`
- Branches must be **merged immediately** upon task completion.
- Long-running branches accumulate unresolvable deltas and **will** corrupt the project.

#### Rule 5: project.godot Coordination

Only **one agent at a time** may modify `project.godot`. Changes to input maps, autoloads, physics layers, or window settings must be committed and pushed **before** another agent begins work that touches this file.

### 8.3 Branch Naming Convention

```
feature/<agent>-<system>-<specific-task>
```

Examples:
- `feature/alpha-networking-spawner-config`
- `feature/beta-ui-lobby-layout`
- `feature/alpha-combat-server-hitbox`
- `feature/beta-animation-interpolation`

---

## 9. 6-Phase Execution Roadmap (Agent-Ready)

Each phase specifies **exactly which files** each agent touches. No overlap is permitted.

---

### Phase 1: Environment Initialization and Architectural Scaffolding

**Objective**: Establish the pristine repository state, directory structure, and base plugin registrations.

#### Agent Alpha (Core Engine & Version Control)

| Task | Files Modified | Notes |
| :--- | :--- | :--- |
| Verify `.gitignore` excludes `.godot/` cache | `.gitignore` | Prevents local path conflicts |
| Restructure assets into compositional hierarchy | `res://components/`, `res://entities/`, `res://systems/`, `res://levels/` | Create placeholder `.gdkeep` files so Git tracks empty dirs |
| Establish baseline `project.godot` configurations | `project.godot` | Physics layers, input maps, window scaling — **merge to main immediately** |

#### Agent Beta (Plugin Retrieval & Compilation)

| Task | Files Modified | Notes |
| :--- | :--- | :--- |
| Download LimboAI C++ GDExtension | `res://addons/limboai/` | Pre-compiled binaries |
| Download OWDB plugin | `res://addons/owdb/` | Level streaming |
| Download Terrain3D plugin | `res://addons/terrain3d/` | Terrain generation |
| Integrate plugins into `project.godot` | `project.godot` | **WAIT** for Agent Alpha to push first. Then pull, add plugin activation booleans, push. |

---

### Phase 2: Multiplayer Networking Infrastructure

**Objective**: Establish client-server communication channels.

#### Agent Alpha (Server Authority & Packet Routing)

| Task | Files Modified |
| :--- | :--- |
| Create `NetworkManager` autoload singleton | `res://systems/network_manager.gd` |
| Implement `ENetMultiplayerPeer` host/join logic | `res://systems/network_manager.gd` |
| Configure `MultiplayerSpawner` for player scene | `res://systems/network_manager.gd` (or dedicated spawner scene) |
| Integrate Netfox addon for lag compensation | `res://addons/netfox/`, `res://systems/network_manager.gd` |
| Register `NetworkManager` as autoload in `project.godot` | `project.godot` |

#### Agent Beta (Lobby & Connection UI)

| Task | Files Modified |
| :--- | :--- |
| Create `Lobby_UI.tscn` with IP input, connect buttons, player list | `res://ui/lobby_ui.tscn`, `res://ui/lobby_ui.gd` |
| Create `LobbyManager` state machine | `res://ui/lobby_manager.gd` |
| Listen for `peer_connected` / `peer_disconnected` from NetworkManager | `res://ui/lobby_manager.gd` |
| Implement scene transition to game world via `change_scene_to_file()` | `res://ui/lobby_manager.gd` |

---

### Phase 3: Character Controller Refactoring and State Replication

**Objective**: Refactor the monolithic player script into networked components.

#### Agent Alpha (Physics and Synchronization)

| Task | Files Modified |
| :--- | :--- |
| Inject `MultiplayerSynchronizer` into `player.tscn` | `res://player/character_body_souls_base.tscn` |
| Bind replication variables: root motion accumulator, global transform, velocity | `res://player/character_body_souls_base.tscn` (synchronizer config) |
| Add authority guard: `set_physics_process(multiplayer.is_server())` | `res://player/character_body_souls_base.gd` |
| Extract `MovementComponent` from monolithic script | `res://components/movement_component.gd` + `.tscn` |
| Extract `NetworkSyncComponent` | `res://components/network_sync_component.gd` + `.tscn` |

#### Agent Beta (Animation State and Visual Interpolation)

| Task | Files Modified |
| :--- | :--- |
| Bind `current_animation` string to MultiplayerSynchronizer | `res://player/souls_animation_tree.gd` |
| Implement interpolation on skeletal mesh using `lerp()` toward server coordinates | `res://components/visual_interpolation_component.gd` + `.tscn` |
| Extract `AnimationComponent` from monolithic script | `res://components/animation_component.gd` + `.tscn` |

> [!IMPORTANT]
> Agent Beta operates **exclusively** on AnimationTree sub-nodes and visual mesh scripts. Agent Alpha operates on the root CharacterBody3D and physics scripts. No overlap.

---

### Phase 4: World Generation and Spatial Streaming

**Objective**: Integrate massive environment streaming with multiplayer visibility.

#### Agent Alpha (OWDB Network Integration)

| Task | Files Modified |
| :--- | :--- |
| Instantiate OWDB root node in main level scene | `res://levels/world_root.tscn` |
| Configure chunking parameters (spatial radius, batch limits) | `res://levels/world_root.tscn` |
| Enable OWDB multiplayer networking layer | `res://levels/world_root.tscn` |
| Configure chunk-based visibility so server only broadcasts to adjacent clients | `res://levels/world_root.tscn` |

#### Agent Beta (Terrain3D Setup and Foliage)

| Task | Files Modified |
| :--- | :--- |
| Create isolated `terrain.tscn` | `res://levels/terrain.tscn` |
| Configure Terrain3D clipmap LOD distances | `res://levels/terrain.tscn` |
| Set texture arrays (albedo, roughness, normal maps) | `res://levels/terrain.tscn` |
| Generate foliage instancer for grass/flora | `res://levels/terrain.tscn` |
| Nest completed `terrain.tscn` as pre-loaded resource within OWDB structure | Coordination with Agent Alpha |

---

### Phase 5: Combat Authority and Hit Registration

**Objective**: Strip client collision authority and implement server-validated damage.

#### Agent Alpha (Server Collision Logic)

| Task | Files Modified |
| :--- | :--- |
| Strip all native collision detection from client-side combat scripts | `res://components/combat_component.gd` |
| Implement server-side hurtbox validation | `res://systems/combat_authority.gd` |
| Create `@rpc("any_peer", "call_local")` attack request function | `res://systems/combat_authority.gd` |
| Calculate spatial overlap between weapon transform and target hitbox during active frames | `res://systems/combat_authority.gd` |
| Broadcast confirmed damage state to all peers | `res://systems/combat_authority.gd` |

#### Agent Beta (Visual Feedback and Effect Instancing)

| Task | Files Modified |
| :--- | :--- |
| Develop damage VFX response system (particle emitters) | `res://components/vfx_component.gd` + `.tscn` |
| Implement camera shake on damage receipt | `res://cameras/camera_effects.gd` |
| Implement hit-stop effect based on damage float | `res://components/vfx_component.gd` |
| Trigger audio stream players based on damage severity | `res://components/audio_component.gd` + `.tscn` |

> [!NOTE]
> Agent Beta operates **solely** on audio-visual instancing nodes. Zero risk of conflicting with Agent Alpha's collision matrix script.

---

### Phase 6: RPG Systems, AI, and Interface

**Objective**: Introduce enemy AI, inventory economy, and narrative frameworks.

#### Agent Alpha (LimboAI and Instanced Loot)

| Task | Files Modified |
| :--- | :--- |
| Create foundational LimboAI BehaviorTree resources for enemies | `res://enemy/behavior_trees/` |
| Define sequence: Patrol → Detect → Chase → Attack | `res://enemy/behavior_trees/enemy_base_bt.tres` |
| Establish Blackboard parameters linking aggro targets to `peer_id` | `res://enemy/behavior_trees/enemy_base_bt.tres` |
| Implement instanced loot logic on enemy death | `res://systems/loot_manager.gd` |
| Calculate drop tables with `RandomNumberGenerator` | `res://systems/loot_manager.gd` |
| Send targeted RPC to killer's `peer_id` for loot instantiation | `res://systems/loot_manager.gd` |

#### Agent Beta (Inventory HUD and SubViewport Rendering)

| Task | Files Modified |
| :--- | :--- |
| Integrate DialogueQuest addon and configure UI nodes | `res://addons/dialogue_quest/`, `res://ui/dialogue_ui.tscn` |
| Build dynamic Inventory UI | `res://ui/inventory_ui.tscn`, `res://ui/inventory_ui.gd` |
| Implement SubViewport 3D→2D item icon rendering | `res://ui/inventory_ui.gd` |
| Create inventory RPC caller for equip commands | `res://ui/inventory_ui.gd` |
| Wait for server validation before updating visual UI state | `res://ui/inventory_ui.gd` |

---

## 10. Technical Stack Reference Table

| System Requirement | Recommended Solution | Architectural Justification |
| :--- | :--- | :--- |
| **Network Topology** | Dedicated Authoritative Server | Prevents client manipulation; deterministic collision resolution for precision combat. |
| **Node Instantiation** | `MultiplayerSpawner` | Automates serialization/replication of dynamically spawned player scenes and world entities. |
| **State Replication** | `MultiplayerSynchronizer` | Efficiently syncs transform, velocity, and animation states via optimized byte streams. |
| **Lag Compensation** | Netfox Addon | Pre-calculated interpolation for client prediction and server reconciliation. |
| **Backend Infrastructure** | GD-Sync (prototyping) or ENet (production) | GD-Sync: global relays, no port-forwarding. ENet: full authority control. |
| **Enemy AI** | LimboAI (C++ GDExtension) | Unparalleled performance for large entity counts; Blackboard memory sharing; combined BT + HSM. |
| **Level Streaming** | Open World Database (OWDB) | Native multiplayer chunk-visibility; prevents GPU memory overflow. |
| **Terrain Generation** | Terrain3D | Clipmap LODs, foliage instancing; synchronizes across client geometries. |
| **Dialogue** | DialogueQuest | Standalone testing app isolates writers from repository, preventing script corruption. |
| **Quest Tracking** | Simple Quest System | Modular Resource-based design for dynamic open-world objectives. |
| **Version Control** | Git + Ephemeral Feature Branches | Strict CBSE rules prevent `.tscn` merge conflicts. |

---

> [!TIP]
> **For AI Agents entering this repository**: Start by reading this document in full. Then check `project.godot` for current autoloads and physics layer definitions. Finally, review `CharacterBodySoulsBase` and `AnimationTreeSoulsBase` to understand the existing signal-driven architecture before writing any code.
