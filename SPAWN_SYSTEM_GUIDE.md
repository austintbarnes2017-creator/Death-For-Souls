# Spawn System Guide

## Overview
The spawn system has been updated to support multiple spawn locations for the expanded game world, including both the starter area and the new city area.

## Components

### 1. SpawnManager (demo_level/spawn_manager.gd)
- **Purpose**: Manages spawn points for different areas
- **Location**: Added to world_castle.tscn scene
- **Functionality**:
  - Tracks player's preferred spawn location using metadata
  - Connects to existing spawn site system
  - Provides manual spawn location control

### 2. Spawn Points
- **SpawnSite**: Original starter area spawn point
  - Position: `(-5.55901, 0, 4.05321)`
  - Used for first-time spawns and normal gameplay
  
- **CitySpawnSite**: New city entrance spawn point
  - Position: `(-50, 0, -67)`
  - Located near the city main gate entrance
  - Used when player has visited the city before

## How It Works

### Automatic Spawning
1. When the game starts, the player spawns at the starter area (SpawnSite)
2. After the player visits and explores the city, the system remembers this
3. On subsequent spawns, the player can choose to spawn at the city entrance

### Manual Control
The SpawnManager provides public functions for manual control:

```gdscript
# Set city as preferred spawn
SpawnManager.set_city_spawn()

# Set starter area as preferred spawn  
SpawnManager.set_starter_spawn()
```

## City Navigation

### Entry Points
- **Main Gate**: Located at the south wall of the city
- **City Spawn**: Positioned at `(-50, 0, -67)` for easy city access

### City Layout
- **Main Street**: Runs north-south through the city center
- **Cross Street**: Runs east-west, intersecting Main Street
- **Buildings**: Houses, shops, tavern, market stall
- **Central Tower**: Tallest structure at city center
- **Exit Path**: Leads back to the original area via ramp

## Usage in Game

1. **First Playthrough**: Player starts at starter area, follows path to city
2. **Subsequent Playthroughs**: Player can spawn directly at city entrance
3. **Admin Control**: Use admin panel to manually set spawn preferences

## Technical Details

- The spawn system integrates with the existing spawn site group system
- Uses Godot's metadata system to track player state
- Maintains compatibility with original spawn mechanics
- Supports both automatic and manual spawn location control

## Troubleshooting

If spawn issues occur:
1. Check that SpawnManager is properly configured in world_castle.tscn
2. Verify spawn point positions match city layout
3. Ensure player has proper metadata for city access
4. Test both automatic and manual spawn functions
