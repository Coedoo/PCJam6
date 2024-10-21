package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:slice"
import "core:strings"
import "core:mem"
import pq "core:container/priority_queue"

import "../ldtk"


Tile :: struct {
    gridPos: iv2,
    worldPos: v2,
    sprite: dm.Sprite,

    building: BuildingHandle,

    beltDir: BeltDir,

    nextTile: Maybe(iv2),

    type: TileType,

    isInput: bool,
    inputIndex: int,

    splitter: Maybe(Splitter),
    merger: Maybe(Merger),
}

TileStartingValues :: struct {
    hasBuilding: bool,
    buildingIdx: int,
    beltDir: Direction,
}

Level  :: struct {
    name: string,
    grid: []Tile,
    startingState: []TileStartingValues,
    sizeX, sizeY: i32,

    startCoord: iv2,
    endCoord: iv2,
}

// @NOTE: Must be the same values as LDTK
// @TODO: can I import it as well?
TileType :: enum {
    None,
    // Walls = 1,
    BuildArea = 2,
    WalkArea = 3,
    Edge = 4,
    BlueEnergy = 5,
    RedEnergy = 6,
    GreenEnergy = 7,
    CyanEnergy = 8,
}

TileTypeColor := #sparse [TileType]dm.color {
    .None = {0, 0, 0, 1},
    // .Walls = {0.73, 0.21, 0.4, 0.5},
    .BuildArea   = ({0, 153, 219, 128} / 255.0),
    .WalkArea    = ({234, 212, 170, 128} / 255.0),
    .Edge        = {0.2, 0.2, 0.2, 0.5},
    .BlueEnergy  = {0, 0, 1, 0.5},
    .RedEnergy   = {1, 0, 0, 0.5},
    .GreenEnergy = {0, 1, 0, 0.5},
    .CyanEnergy  = {0, 1, 1, 0.5},
}

/////

LoadLevels :: proc() -> (levels: []Level) {
    tilesHandle := dm.GetTextureAsset("tiles.png")
    // levelAsset := LevelAsset

    ldtkFile := dm.GetAssetData("PCJam6.ldtk")
    project, ok := ldtk.load_from_memory(ldtkFile.fileData).?

    if ok == false {
        fmt.eprintln("Failed to load level file")
        return
    }

    levels = make([]Level, len(project.levels))

    buildingsNameCache := make(map[string]int, allocator = context.temp_allocator)

    // @TODO: it's kinda error prone
    PixelsPerTile :: 16

    for loadedLevel, i in project.levels {
        levelPxSize := iv2{i32(loadedLevel.px_width), i32(loadedLevel.px_height)}
        levelSize := dm.ToV2(levelPxSize) / PixelsPerTile

        level := &levels[i]
        level.sizeX = i32(levelSize.x)
        level.sizeY = i32(levelSize.y)

        level.name = strings.clone(loadedLevel.identifier)

        for layer in loadedLevel.layer_instances {
            yOffset := layer.c_height * layer.grid_size

            if layer.identifier == "Tiles" {
                tiles := layer.type == .Tiles ? layer.grid_tiles : layer.auto_layer_tiles
                level.grid = make([]Tile, layer.c_width * layer.c_height)

                // Setup tile's types
                for type, i in layer.int_grid_csv {
                    coord := iv2{
                        i32(i) % level.sizeX,
                        i32(i) / level.sizeX,
                    }

                    coord.y = level.sizeY - coord.y - 1
                    idx := coord.y * level.sizeX + coord.x
                    
                    level.grid[idx] = Tile {
                        gridPos = iv2{i32(coord.x), i32(coord.y)},
                        worldPos = CoordToPos(coord),
                        type = cast(TileType) type,
                    }
                    level.grid[idx].type = cast(TileType) type
                }

                // Tile's sprites
                for tile, i in tiles {
                    sprite := dm.CreateSprite(
                        tilesHandle,
                        dm.RectInt{i32(tile.src.x), i32(tile.src.y), PixelsPerTile, PixelsPerTile}
                    )

                    tilemapPos := tile.px / layer.grid_size
                    // reverse the axis because LDTK Y axis goes down
                    tilemapPos.y = int(level.sizeY) - tilemapPos.y - 1

                    idx := tilemapPos.y * int(level.sizeX) + tilemapPos.x
                    // level.grid[idx].sprite = sprite

                    coord := iv2{i32(tilemapPos.x), i32(tilemapPos.y)}
                    level.grid[idx] = Tile {
                        gridPos = iv2{i32(coord.x), i32(coord.y)},
                        worldPos = CoordToPos(coord),
                        // type = cast(TileType) type,
                        sprite = sprite,
                    }
                }
            }
            else {
                fmt.eprintln("Unhandled level layer:", layer.identifier)
            }
        }
    }

    return
}

OpenLevel :: proc(name: string) {
    CloseCurrentLevel()

    mem.zero_item(&gameState.levelState)
    free_all(gameState.levelAllocator)
    gameState.levelArena.peak_used = 0

    context.allocator = gameState.levelAllocator

    dm.InitResourcePool(&gameState.spawnedBuildings, 128)
    dm.InitResourcePool(&gameState.spawnedItems, 512)

    gameState.level = nil
    for &l in gameState.levels {
        if l.name == name {
            gameState.level = &l
            break
        }
    }

    //@TODO: it would be better to start test level in this case
    assert(gameState.level != nil, fmt.tprintf("Failed to start level of name:", name))
    gameState.playerPosition = dm.ToV2(iv2{gameState.level.sizeX, gameState.level.sizeY}) / 2


    // for &tile, i in gameState.level.grid {
    //     if gameState.level.startingState[i].hasBuilding {
    //         TryPlaceBuilding(gameState.level.startingState[i].buildingIdx, tile.gridPos)
    //     }
    // }

}

CloseCurrentLevel :: proc() {
    if gameState.level == nil {
        return
    }

    mem.zero_item(&gameState.levelState)
    free_all(gameState.levelAllocator)

    for &tile in gameState.level.grid {
        tile.building = {}
        tile.beltDir = {}
    }

    gameState.level = nil
}


///////////

IsInsideGrid :: proc(coord: iv2) -> bool {
    return coord.x >= 0 && coord.x < gameState.level.sizeX &&
           coord.y >= 0 && coord.y < gameState.level.sizeY
}

CoordToIdx :: proc(coord: iv2) -> i32 {
    assert(IsInsideGrid(coord))
    return coord.y * gameState.level.sizeX + coord.x
}

WorldPosToCoord :: proc(pos: v2) -> iv2 {
    x := i32(pos.x)
    y := i32(pos.y)

    return {x, y}
}

IsTileFree :: proc(coord: iv2) -> bool {
    idx := CoordToIdx(coord)
    return gameState.level.grid[idx].building == {}
}

GetTileOnWorldPos :: proc(pos: v2) -> ^Tile {
    x := i32(pos.x)
    y := i32(pos.y)

    return GetTileAtCoord({x, y})
}

GetTileAtCoord :: proc(coord: iv2) -> ^Tile {
    if IsInsideGrid(coord) {
        idx := CoordToIdx(coord)
        return &gameState.level.grid[idx]
    }

    return nil
}

TileUnderCursor :: proc() -> ^Tile {
    coord := MousePosGrid()
    return GetTileAtCoord(coord)
}

GetNeighbourCoords :: proc(coord: iv2, allocator := context.allocator) -> []iv2 {
    ret := make([dynamic]iv2, 0, 4, allocator = allocator)

    for x := i32(-1); x <= i32(1); x += 1 {
        for y := i32(-1); y <= i32(1); y += 1 {
            n := coord + {x, y}
            if (n.x != coord.x &&
                n.y != coord.y) ||
                n == coord
            {
                continue
            }


            if IsInsideGrid(n) {
                append(&ret, n)
            }
        }
    }

    return ret[:]
}

GetNeighbourTiles :: proc(coord: iv2, allocator := context.allocator) -> []^Tile {
    ret := make([dynamic]^Tile, 0, 4, allocator = allocator)

    for x := i32(-1); x <= i32(1); x += 1 {
        for y := i32(-1); y <= i32(1); y += 1 {
            n := coord + {x, y}
            if (n.x != coord.x &&
                n.y != coord.y) ||
               n == coord
            {
                continue
            }

            if(IsInsideGrid(n)) {
                append(&ret, GetTileAtCoord(n))
            }
        }
    }

    return ret[:]
}

////////////////////

CanBePlaced :: proc(building: Building, coord: iv2) -> bool {
    pos := gameState.playerPosition + PLAYER_COLL_OFFSET
    playerBounds := dm.Bounds2D{
        pos.x - PLAYER_COLL_SIZE.x / 2, pos.x + PLAYER_COLL_SIZE.x / 2,
        pos.y - PLAYER_COLL_SIZE.y / 2, pos.y + PLAYER_COLL_SIZE.y / 2,
    }

    buildingPos := dm.ToV2(coord)
    buildingBounds := dm.Bounds2D{
        buildingPos.x, buildingPos.x + f32(building.size.x),
        buildingPos.y, buildingPos.y + f32(building.size.y),
    }
    coll := dm.CheckCollisionBounds(playerBounds, buildingBounds)

    if coll {
        return false
    }

    for y in 0..<building.size.y {
        for x in 0..<building.size.x {
            pos := coord + {x, y}

            if IsInsideGrid(pos) == false {
                return false
            }

            if len(building.restrictedTiles) != 0 {
                tile := GetTileAtCoord(pos)

                found := false
                for restrictedTile in building.restrictedTiles {
                    if tile.type == restrictedTile {
                        found = true
                        break
                    }
                }

                if found == false {
                    return false
                }
            }

            if IsTileFree(pos) == false {
                return false
            }
        }
    }

    return true
}

TryPlaceBuilding :: proc(buildingIdx: int, gridPos: iv2) -> bool {
    building := Buildings[buildingIdx]
    if CanBePlaced(building, gridPos) == false {
        return false
    }

    PlaceBuilding(buildingIdx, gridPos)
    return true
}

PlaceBuilding :: proc(buildingIdx: int, gridPos: iv2) {
    building := Buildings[buildingIdx]
    toSpawn := BuildingInstance {
        dataIdx = buildingIdx,
        gridPos = gridPos,
        position = dm.ToV2(gridPos) + dm.ToV2(building.size) / 2,
    }

    handle := dm.AppendElement(&gameState.spawnedBuildings, toSpawn)

    // TODO: check for outside grid coords
    for y in 0..<building.size.y {
        for x in 0..<building.size.x {
            idx := CoordToIdx(gridPos + {x, y})
            gameState.level.grid[idx].building = handle
            gameState.level.grid[idx].beltDir = {}
        }
    }

    if building.output.beltDir != {} {
        PlaceBelt(gridPos + building.output.offset, building.output.beltDir)
    }

    for input, i in building.inputs {
        tile := PlaceBelt(gridPos + input.offset, input.beltDir)
        if tile == nil {
            continue
        }

        tile.isInput = true
        tile.inputIndex = i
    }

    dm.PlaySound(cast(dm.SoundHandle) dm.GetAsset("building_place.wav"));
}


RemoveBuilding :: proc(building: BuildingHandle) {
    inst, ok := dm.GetElementPtr(gameState.spawnedBuildings, building)
    if ok == false {
        return
    }

    buildingData := &Buildings[inst.dataIdx]
    for y in 0..<buildingData.size.y {
        for x in 0..<buildingData.size.x {
            tile := GetTileAtCoord(inst.gridPos + {x, y})
            tile.building = {}
            if tile.beltDir != {} {
                DestroyBelt(tile)
            }

            tile.isInput = false
        }
    }

    dm.FreeSlot(&gameState.spawnedBuildings, building)

    RefreshMoney()
}

TileTraversalPredicate :: #type proc(currentTile: Tile, neighbor: Tile, goal: iv2) -> bool

TestConnectionPredicate :: proc(currentTile: Tile, neighbor: Tile, goal: iv2) -> bool {
    return neighbor.gridPos == goal || 
        (
            neighbor.type == .WalkArea && 
            neighbor.building == {}
        )
}

WalkablePredicate :: proc(currentTile: Tile, neighbor: Tile, goal: iv2) -> bool {
    return neighbor.gridPos == goal || (neighbor.type == .WalkArea && neighbor.building == {})
}

// PipePredicate :: proc(currentTile: Tile, neighbor: Tile, goal: iv2) -> bool {
//     delta :=  neighbor.gridPos - currentTile.gridPos
//     dir := VecToDir(delta)
//     reverse := ReverseDir[dir]

//     return (dir in currentTile.beltDir && 
//             reverse in neighbor.beltDir) && 
//            (neighbor.building == {} ||
//             neighbor.gridPos == goal 
//             )
// }

CalculatePath :: proc(start, goal: iv2, traversalPredicate: TileTraversalPredicate, allocator := context.allocator) -> []iv2 {
    openCoords: pq.Priority_Queue(iv2)

    // @TODO: I can probably make gScore and fScore as 2d array so 
    // there is no need for maps
    cameFrom := make(map[iv2]iv2, allocator = context.temp_allocator)
    gScore   := make(map[iv2]f32, allocator = context.temp_allocator)
    fScore   := make(map[iv2]f32, allocator = context.temp_allocator)

    Heuristic :: proc(a, b: iv2) -> f32 {
        return glsl.distance(dm.ToV2(a), dm.ToV2(b))
    }

    Less :: proc(a, b: iv2) -> bool {
        scoreMap := cast(^map[iv2]f32) context.user_ptr
        aScore := scoreMap[a] or_else max(f32)
        bScore := scoreMap[b] or_else max(f32)

        return aScore < bScore
    }

    context.user_ptr = &fScore
    pq.init(&openCoords, Less, pq.default_swap_proc(iv2))

    pq.push(&openCoords, start)

    gScore[start] = 0
    fScore[start] = Heuristic(start, goal)

    for pq.len(openCoords) > 0 {
        current := pq.peek(openCoords)
        if current == goal {
            ret := make([dynamic]iv2, allocator)
            append(&ret, current)

            for (current in cameFrom) {
                current = cameFrom[current]
                inject_at(&ret, 0, current)
            }

            return ret[:]
        }

        currentTile := GetTileAtCoord(current)

        pq.pop(&openCoords)
        neighboursCoords := GetNeighbourCoords(current, allocator = context.temp_allocator)
        for neighborCoord in neighboursCoords {
            neighbourTile := GetTileAtCoord(neighborCoord)

            if traversalPredicate(currentTile^, neighbourTile^, goal) == false {
                continue
            }

            // @NOTE: I can make it depend on the edge on the tilemap
            // weight := glsl.distance(dm.ToV2(current), dm.ToV2(neighborCoord))
            newScore := gScore[current] + 1
            oldScore := gScore[neighborCoord] or_else max(f32)
            if newScore < oldScore {
                cameFrom[neighborCoord] = current
                gScore[neighborCoord] = newScore
                fScore[neighborCoord] = newScore + Heuristic(neighborCoord, goal)
                if slice.contains(openCoords.queue[:], neighborCoord) == false {
                    pq.push(&openCoords, neighborCoord)
                }
            }
        }
    }

    return nil
}
