# VoxelCraft: Core Runner

A roguelike extraction game built in Godot 4.6 with a procedurally generated voxel world. Venture outward from a safe center zone through increasingly hostile biomes to mine rare ores, then race back to extract before the environment kills you.

## Demo



https://github.com/user-attachments/assets/20101906-c091-439d-9d3c-ec49af45998c



## Gameplay Loop

1. **Spawn** at a safe central hub
2. **Explore** outward through 5 concentric biome zones, each more dangerous than the last
3. **Mine** ores using tiered tools (Wood through Void tier) with Minecraft-style hold-to-break mining
4. **Manage** a 36-slot inventory with drag-and-drop, stack splitting, and tool durability
5. **Extract** by returning to the center and channeling — ores transfer to your permanent stash
6. **Die** and lose everything you're carrying, or extract successfully and keep it all
7. **Upgrade** your stats and buy better tools at the between-runs shop using stashed ores
8. **Repeat** — push deeper each run as your gear improves

## Biome Zones

| Zone | Distance | Hazard | Ores |
|------|----------|--------|------|
| Safe Haven | 0–128 | None (escalates after 8 min) | Copper, Iron |
| The Wilds | 128–320 | Light damage over time | Wild Crystal, Thornite |
| Frozen Wastes | 320–560 | Cold damage, increasing fog | Frostite, Glacial Gem |
| Scorched Lands | 560–800 | Heat damage, lava terrain | Embersite, Magma Core |
| The Void | 800+ | Heavy damage, dark atmosphere | Void Shard |

## Features

- **Procedural voxel world** with biome-blended terrain, chunk streaming, and dynamic atmosphere
- **9 mineable ores** spread across 5 zones with noise-based placement
- **12 craftable tools** — 6 tiers of pickaxes and shovels with durability
- **Hold-to-mine system** where tool type and tier affect break speed
- **Full inventory** — 36 slots, hotbar, click-to-move, right-click to split stacks
- **2D minimap** showing zone rings, player position/facing, and extraction beacon
- **Base camp shop** with 3 tabs: stat upgrades, tool purchases, and block supplies
- **Environmental damage** that scales with distance and time spent in a run
- **Persistent progression** — stash and upgrades saved between sessions (JSON)
- **Block placement** — build shelters, bridges, and walls using mined or purchased blocks

## Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Mouse | Look |
| Left Click (hold) | Mine block |
| Right Click | Place block |
| Scroll / 1-9 | Select hotbar slot |
| Space | Jump |
| Shift | Sprint |
| E (hold, near center) | Extract |
| TAB (during run) | Open inventory |
| TAB (between runs) | Open/close shop |
| Enter | Dismiss death/success screen |
| F3 | Toggle debug overlay |
| Esc | Release/capture mouse |

## Tech Stack

- **Engine:** Godot 4.6 (Mono/.NET)
- **Voxel engine:** C# — chunk management, greedy meshing, noise-based world generation, texture atlas
- **Game systems:** GDScript — player, inventory, mining, HUD, shop, upgrades, save/load
- **Rendering:** Procedural 16x16 texture atlas, per-biome fog/lighting, zone VFX overlays

## Project Structure

```
scripts/
  voxel/           # C# voxel engine
    BlockTypes.cs       # Block definitions and UV mapping
    ChunkData.cs        # Per-chunk block storage
    ChunkManager.cs     # Chunk loading/unloading around player
    ChunkNode.cs        # Mesh generation and rendering
    WorldGenerator.cs   # Terrain and ore generation
    BiomeManager.cs     # Biome blending and zone definitions
    NoiseGenerator.cs   # Noise sampling
    TextureGenerator.cs # Procedural texture atlas
  Player.gd         # Movement, mining, placement, health
  Inventory.gd      # 36-slot inventory model
  ItemDB.gd         # Static item/block/tool definitions
  GameManager.gd    # Main orchestrator
  RunManager.gd     # Run state, zone damage, extraction
  UpgradeManager.gd # Stat upgrades and stash
  ShopManager.gd    # Tool and supply shop
  SaveManager.gd    # JSON save/load
  HUD.gd            # All UI (hotbar, inventory grid, minimap, shop, overlays)
scenes/
  main.tscn         # Root scene
  hud.tscn          # HUD canvas layer
  player.tscn       # Player character
```

## Running Locally

1. Install [Godot 4.6 (.NET)](https://godotengine.org/download)
2. Clone this repository
3. Open the project in Godot
4. Build the C# solution (Build > Build Solution, or the build button in the editor)
5. Press F5 to play

## License

MIT
