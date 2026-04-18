# Architectural Blueprint for Godot 4 Multiplayer Souls-Like RPG

This document serves as the primary technical reference and "Source of Truth" for the development of a highly synchronized, multiplayer action-RPG. It is designed to coordinate both human developers and autonomous AI agents.

## 1. Core Architectural Pillars

### Component-Based Software Engineering (CBSE)
To prevent project-clearing Git merge conflicts, this project enforces a **Composition over Inheritance** paradigm.
- **Rule**: Avoid monolithic scripts. Decouple logic into isolated components.
- **Scene Assembly**: Each component must be saved as a discrete `.tscn` file. 

### Authoritative Dedicated Server Architecture
For precision souls-like combat, the game utilizes a server-authoritative model.
- **Client Role**: Rendering engine and input transmitter.
- **Server Role**: Physics calculations, root motion extraction, and collision validation.
- **Latency Mitigation**: Implement Client-Side Prediction and Server Reconciliation.

## 2. Technical Stack & Shared Requirements

| System | Recommended Solution |
| :--- | :--- |
| **Networking Backend** | GD-Sync or Authoritative ENet + Netfox |
| **Level Streaming** | Open World Database (OWDB) |
| **Terrain / Foliage** | Terrain3D |
| **AI (Behavior Trees)** | LimboAI (C++ GDExtension) |
| **Narrative / Quest** | DialogueQuest + Simple Quest System |

## 3. Parallel Development Framework (Agent Collaboration)

- **Absolute Node Isolation**: Agents must never modify the same `.tscn` file simultaneously.
- **Exported Variable Configuration**: Logic is written once; tuning is done via the Inspector.
- **Ephemeral Feature Branches**: Branches must be hyper-specific and merged immediately.

## 4. 6-Phase Execution Roadmap

1. **Phase 1**: Environment & Scaffolding (Directory hierarchy, plugin registration).
2. **Phase 2**: Multiplayer Infrastructure (`NetworkManager`, Spawners/Syncers).
3. **Phase 3**: Character Controller Refactoring (Server authority, state replication).
4. **Phase 4**: World Generation & Streaming (OWDB, Terrain3D).
5. **Phase 5**: Combat Authority & Hit Registration (Server-side validation, RPC).
6. **Phase 6**: RPG Systems & UI (LimboAI, Inventory SubViewports).
