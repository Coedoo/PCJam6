package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:slice"
import "core:mem"

import "../ldtk"

v2 :: dm.v2
iv2 :: dm.iv2


BuildUpMode :: enum {
    None,
    Building,
    Pipe,
    Destroy,
}


GameState :: struct {
    levelArena: mem.Arena,
    levelAllocator: mem.Allocator,

    levels: []Level,
    level: ^Level, // currentLevel

    using levelState: struct {
        spawnedBuildings: dm.ResourcePool(BuildingInstance, BuildingHandle),

        money: int,

        playerPosition: v2,

        selectedTile: iv2,

        buildUpMode: BuildUpMode,
        selectedBuildingIdx: int,
        buildingPipeDir: DirectionSet,

        currentWaveIdx: int,

        levelFullySpawned: bool,

        pathsBetweenBuildings: map[PathKey][]iv2,

        // VFX
        turretFireParticle: dm.ParticleSystem,

        // Path
        // pathArena: mem.Arena,
        // pathAllocator: mem.Allocator,

        // cornerTiles: []iv2,
        // path: []iv2,
    },

    playerSprite: dm.Sprite,
    arrowSprite: dm.Sprite,
}

gameState: ^GameState

RemoveMoney :: proc(amount: int) -> bool {
    if gameState.money >= amount {
        gameState.money -= amount
        return true
    }

    return false
}

//////////////

MousePosGrid :: proc() -> (gridPos: iv2) {
    mousePos := dm.ScreenToWorldSpace(dm.input.mousePos)

    gridPos.x = i32(mousePos.x)
    gridPos.y = i32(mousePos.y)

    return
}

@export
PreGameLoad : dm.PreGameLoad : proc(assets: ^dm.Assets) {
    // dm.RegisterAsset("testTex.png", dm.TextureAssetDescriptor{})

    dm.RegisterAsset("PCJam6.ldtk", dm.RawFileAssetDescriptor{})
    dm.RegisterAsset("kenney_tilemap.png", dm.TextureAssetDescriptor{})
    dm.RegisterAsset("buildings.png", dm.TextureAssetDescriptor{})
    dm.RegisterAsset("turret_test_4.png", dm.TextureAssetDescriptor{})
    dm.RegisterAsset("Energy.png", dm.TextureAssetDescriptor{})

    dm.RegisterAsset("ship.png", dm.TextureAssetDescriptor{})


    dm.platform.SetWindowSize(1200, 900)
}

@(export)
GameHotReloaded : dm.GameHotReloaded : proc(gameState: rawptr) {
    gameState := cast(^GameState) gameState

    gameState.levelAllocator = mem.arena_allocator(&gameState.levelArena)
}

@(export)
GameLoad : dm.GameLoad : proc(platform: ^dm.Platform) {
    gameState = dm.AllocateGameData(platform, GameState)

    levelMem := make([]byte, LEVEL_MEMORY)
    mem.arena_init(&gameState.levelArena, levelMem)
    gameState.levelAllocator = mem.arena_allocator(&gameState.levelArena)

    gameState.playerSprite = dm.CreateSprite(dm.GetTextureAsset("ship.png"))
    gameState.playerSprite.scale = 2

    gameState.levels = LoadLevels()
    OpenLevel(START_LEVEL)

    gameState.arrowSprite = dm.CreateSprite(dm.GetTextureAsset("buildings.png"), dm.RectInt{32 * 2, 0, 32, 32})
    gameState.arrowSprite.scale = 0.4
    gameState.arrowSprite.origin = {0, 0.5}

    // for &system, i in gameState.tileEnergyParticles {
    //     system = dm.DefaultParticleSystem

    //     system.texture = dm.GetTextureAsset("Energy.png")
    //     system.startColor = EnergyColor[EnergyType(i)]

    //     system.emitRate = 0

    //     system.startSize = 0.4

    //     system.color = dm.ColorOverLifetime{
    //         min = {1, 1, 1, 1},
    //         max = {1, 1, 1, 0},
    //         easeFun = .Cubic_Out,
    //     }

    //     system.startSpeed = 0.5

    //     dm.InitParticleSystem(&system)
    // }
}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState = cast(^GameState) state

    cursorOverUI := dm.muiIsCursorOverUI(dm.mui, dm.input.mousePos)

    // Move Player
    moveVec := v2{
        dm.GetAxis(.A, .D),
        dm.GetAxis(.S, .W)
    }

    if moveVec != {0, 0} {
        moveVec = glsl.normalize(moveVec)
        gameState.playerPosition += moveVec * PLAYER_SPEED * f32(dm.time.deltaTime)
    }

    // Camera Control
    camAspect := dm.renderCtx.camera.aspect
    camHeight := dm.renderCtx.camera.orthoSize
    camWidth  := camAspect * camHeight

    levelSize := v2{
        f32(gameState.level.sizeX - 1), // -1 to account for level edge
        f32(gameState.level.sizeY - 1),
    }

    if gameState.buildUpMode == .None {
        scroll := dm.input.scroll if cursorOverUI == false else 0
        camHeight = camHeight - f32(scroll) * 0.3
        camWidth = camAspect * camHeight
    }

    camHeight = clamp(camHeight, 1, levelSize.x / 2)
    camWidth  = clamp(camWidth,  1, levelSize.y / 2)

    camSize := min(camHeight, camWidth / camAspect)
    dm.renderCtx.camera.orthoSize = camSize

    camPos := gameState.playerPosition
    camPos.x = clamp(camPos.x, camWidth + 1,  levelSize.x - camWidth)
    camPos.y = clamp(camPos.y, camHeight + 1, levelSize.y - camHeight)
    dm.renderCtx.camera.position.xy = cast([2]f32) camPos

    // Update Buildings
    buildingIt := dm.MakePoolIter(&gameState.spawnedBuildings)
    for building in dm.PoolIterate(&buildingIt) {
        buildingData := &Buildings[building.dataIdx]

        if building.productionTimer <= 0 {
            if building.currentItemsCount < buildingData.maxStorage {
                building.currentItemsCount += 1
                building.productionTimer = PRODUCTION_BASE / f32(buildingData.productionRate)
            }
        }
        else {
            building.productionTimer -= f32(dm.time.deltaTime)
        }
    }


    // Destroy structres
    if gameState.buildUpMode == .Destroy &&
       dm.GetMouseButton(.Left) == .JustPressed &&
       cursorOverUI == false
    {
        tile := TileUnderCursor()
        if tile.building != {} {
            RemoveBuilding(tile.building)
        }
        else if tile.pipeDir != {} {
            connectedBuildings := GetConnectedBuildings(tile.gridPos, allocator = context.temp_allocator)

            for dir in tile.pipeDir {
                neighborCoord := tile.gridPos + DirToVec[dir]
                neighbor := GetTileAtCoord(neighborCoord)
                if neighbor.building != {} {
                    neighbor.pipeDir -= { ReverseDir[dir] }
                }
            }

            tile.pipeDir = nil

            // for handleA in connectedBuildings {
            //     buildingA := dm.GetElementPtr(gameState.spawnedBuildings, handleA) or_continue

            //     #reverse for handleB, i in buildingA.energyTargets {
            //         buildingB := dm.GetElementPtr(gameState.spawnedBuildings, handleB) or_continue

            //         key := PathKey{buildingA.handle, buildingB.handle}
            //         oldPath := gameState.pathsBetweenBuildings[key] or_continue
            //         newPath := CalculatePath(buildingA.gridPos, buildingB.gridPos, PipePredicate)

            //         if PathsEqual(oldPath, newPath) {
            //             continue
            //         }

            //         delete(oldPath)

            //         if newPath != nil {
            //             gameState.pathsBetweenBuildings[key] = newPath
            //         }
            //         else {
            //             delete_key(&gameState.pathsBetweenBuildings, key)

            //             unordered_remove(&buildingA.energyTargets, i)

            //             if idx, found := slice.linear_search(buildingB.energySources[:], handleA); found {
            //                 unordered_remove(&buildingB.energySources, idx)
            //             }
            //         }

            //         // Delete packets on old path
            //         it := dm.MakePoolIterReverse(&gameState.energyPackets)
            //         for packet in dm.PoolIterate(&it) {
            //             if packet.pathKey == key {
            //                 dm.FreeSlot(&gameState.energyPackets, packet.handle)
            //             }
            //         }
            //     }
            // }
        }
    }

    if dm.GetMouseButton(.Right) == .JustPressed &&
       cursorOverUI == false
    {
        gameState.buildUpMode = .None
    }

    // Pipe
    if gameState.buildUpMode == .Pipe &&
       cursorOverUI == false
    {
        @static prevCoord: iv2

        leftBtn := dm.GetMouseButton(.Left)
        if leftBtn == .Down  {
            coord := MousePosGrid()
            if IsInDistance(gameState.playerPosition, coord) {
                tile := GetTileAtCoord(coord)

                canPlace :=  (prevCoord != coord || tile.pipeDir != gameState.buildingPipeDir)
                canPlace &&= tile.pipeDir != gameState.buildingPipeDir
                canPlace &&= tile.building == {}

                if canPlace {
                    tile.pipeDir = gameState.buildingPipeDir
                    for dir in gameState.buildingPipeDir {
                        neighborCoord := coord + DirToVec[dir]
                        neighbor := GetTileAtCoord(neighborCoord)
                        if neighbor.building != {} {
                            neighbor.pipeDir += { ReverseDir[dir] }
                        }
                    }

                    CheckBuildingConnection(tile.gridPos)

                    prevCoord = coord
                }
            }
        }

        if dm.input.scroll != 0 {
            dirSet := NextDir if dm.input.scroll < 0 else PrevDir
            newSet: DirectionSet
            for dir in gameState.buildingPipeDir {
                newSet += { dirSet[dir] }
            }
            gameState.buildingPipeDir = newSet
        }
    }

    // Highlight Building 
    if gameState.buildUpMode == .None && cursorOverUI == false {
        if dm.GetMouseButton(.Left) == .JustPressed {
            coord := MousePosGrid()
            gameState.selectedTile = coord
        }
    }

    // Building
    if gameState.buildUpMode == .Building
    {
        // if dm.input.scroll != 0 {
        //     dirSet := NextDir if dm.input.scroll < 0 else PrevDir
        //     gameState.buildedStructureRotation = dirSet[gameState.buildedStructureRotation]
        // }

        if dm.GetMouseButton(.Left) == .JustPressed &&
           cursorOverUI == false
        {
            idx := gameState.selectedBuildingIdx
            building := Buildings[idx]

            pos := MousePosGrid()

            if IsInDistance(gameState.playerPosition, pos) {
                if CanBePlaced(building, pos) {
                    if RemoveMoney(building.cost) {
                        // PlaceBuilding(idx, pos)
                        TryPlaceBuilding(idx, pos)
                    }
                }
            }
        }
    }

    // temp UI
    if dm.muiBeginWindow(dm.mui, "GAME MENU", {10, 10, 110, 450}) {
        dm.muiLabel(dm.mui, gameState.selectedTile)
        dm.muiLabel(dm.mui, "Money:", gameState.money)

        for b, idx in Buildings {
            if dm.muiButton(dm.mui, b.name) {
                gameState.selectedBuildingIdx = idx
                gameState.buildUpMode = .Building
            }
        }

        dm.muiLabel(dm.mui, "Pipes:")
        if dm.muiButton(dm.mui, "Stright") {
            gameState.buildUpMode = .Pipe
            gameState.buildingPipeDir = DirVertical
        }
        if dm.muiButton(dm.mui, "Angled") {
            gameState.buildUpMode = .Pipe
            gameState.buildingPipeDir = DirNE
        }
        if dm.muiButton(dm.mui, "Triple") {
            gameState.buildUpMode = .Pipe
            gameState.buildingPipeDir = {.South, .North, .East}
        }
        if dm.muiButton(dm.mui, "Quad") {
            gameState.buildUpMode = .Pipe
            gameState.buildingPipeDir = DirSplitter
        }

        dm.muiLabel(dm.mui)
        if dm.muiButton(dm.mui, "Destroy") {
            gameState.buildUpMode = .Destroy
        }

        if dm.muiButton(dm.mui, "Reset level") {
            name := gameState.level.name
            OpenLevel(name)
        }

        dm.muiLabel(dm.mui, "LEVELS:")
        for l in gameState.levels {
            if dm.muiButton(dm.mui, l.name) {
                OpenLevel(l.name)
            }
        }

        dm.muiLabel(dm.mui, "MEMORY")
        dm.muiLabel(dm.mui, "\tLevel arena HWM:", gameState.levelArena.peak_used / mem.Kilobyte, "kb")
        dm.muiLabel(dm.mui, "\tLevel arena used:", gameState.levelArena.offset / mem.Kilobyte, "kb")


        dm.muiEndWindow(dm.mui)
    }

    tile := GetTileAtCoord(gameState.selectedTile)
    if tile.building != {} || tile.pipeDir != {} {
        if dm.muiBeginWindow(dm.mui, "Selected Building", {600, 10, 140, 250}, {.NO_CLOSE}) {
            dm.muiLabel(dm.mui, tile.pipeDir)

            if dm.muiHeader(dm.mui, "Building") {
                if tile.building != {} {
                    building, ok := dm.GetElementPtr(gameState.spawnedBuildings, tile.building)
                    if ok {
                        data := &Buildings[building.dataIdx]
                        dm.muiLabel(dm.mui, "Name:", data.name)
                        dm.muiLabel(dm.mui, building.handle)
                        dm.muiLabel(dm.mui, "Pos:", building.gridPos)

                        dm.muiLabel(dm.mui)

                        productionTime := PRODUCTION_BASE / f32(data.productionRate)
                        productionPercent := building.productionTimer / productionTime

                        dm.muiLabel(dm.mui, "Production: ", int(productionPercent * 100), "%", sep = "")
                        dm.muiLabel(dm.mui, data.producedItem, building.currentItemsCount)
                        // dm.muiLabel(dm.mui, "requestedEnergy:", building.requestedEnergy)
                    }
                }
            }

            dm.muiEndWindow(dm.mui)
        }
    }

    if gameState.buildUpMode != .None {
        size := iv2{
            100, 60
        }

        pos := iv2{
            dm.renderCtx.frameSize.x / 2 - size.x / 2,
            dm.renderCtx.frameSize.y - 100,
        }

        if dm.muiBeginWindow(dm.mui, "Current Mode", {pos.x, pos.y, size.x, size.y}, 
            {.NO_CLOSE, .NO_RESIZE})
        {
            label := gameState.buildUpMode == .Building ? "Building" :
                     gameState.buildUpMode == .Pipe     ? "Pipe" :
                     gameState.buildUpMode == .Destroy  ? "Destroy" :
                                                          "UNKNOWN MODE"

            dm.muiLabel(dm.mui, label)

            dm.muiEndWindow(dm.mui)
        }
    }
}

@(export)
GameUpdateDebug : dm.GameUpdateDebug : proc(state: rawptr, debug: bool) {
    gameState = cast(^GameState) state

    if debug {
        if dm.muiBeginWindow(dm.mui, "Config", {10, 200, 150, 100}) {
            dm.muiToggle(dm.mui, "TILE_OVERLAY", &DEBUG_TILE_OVERLAY)

            dm.muiEndWindow(dm.mui)
        }
    }
}

@(export)
GameRender : dm.GameRender : proc(state: rawptr) {
    gameState = cast(^GameState) state
    dm.ClearColor({0.1, 0.1, 0.3, 1})

    // Level
    for tile, idx in gameState.level.grid {
        dm.DrawSprite(tile.sprite, tile.worldPos)
        if DEBUG_TILE_OVERLAY {
            dm.DrawBlankSprite(tile.worldPos, {1, 1}, TileTypeColor[tile.type])
        }
    }


    // Pipe
    for tile, idx in gameState.level.grid {
        for dir in tile.pipeDir {
            dm.DrawWorldRect(
                dm.renderCtx.whiteTexture,
                tile.worldPos,
                {0.5, 0.1},
                rotation = math.to_radians(DirToRot[dir]),
                color = {0, 0.1, 0.8, 0.9},
                pivot = {0, 0.5}
            )
        }
    }

    // Buildings

    // shader := dm.GetAsset("Shaders/test.hlsl")
    // dm.PushShader(cast(dm.ShaderHandle) shader)
    for &building in gameState.spawnedBuildings.elements {
        // @TODO @CACHE
        buildingData := &Buildings[building.dataIdx]
        tex := dm.GetTextureAsset(buildingData.spriteName)
        sprite := dm.CreateSprite(tex, buildingData.spriteRect)
        sprite.scale = f32(buildingData.size.x)

        pos := building.position
        // color := GetEnergyColor(building.currentEnergy)

        // dm.SetShaderData(2, [4]f32{1, 0, 1, 1})
        dm.DrawSprite(sprite, pos)

    }
    // dm.PopShader()

    // Selected building
    if gameState.buildUpMode == .Building {
        gridPos := MousePosGrid()

        building := Buildings[gameState.selectedBuildingIdx]

        // @TODO @CACHE
        tex := dm.GetTextureAsset(building.spriteName)
        sprite := dm.CreateSprite(tex, building.spriteRect)

        color := dm.GREEN
        if CanBePlaced(building, gridPos) == false {
            color = dm.RED
        }

        // @TODO: make this a function
        pos := MousePosGrid()
        playerPos := WorldPosToCoord(gameState.playerPosition)

        delta := pos - playerPos

        if delta.x * delta.x + delta.y * delta.y > BUILDING_DISTANCE * BUILDING_DISTANCE {
            color = dm.RED
        }

        dm.DrawSprite(
            sprite, 
            dm.ToV2(gridPos) + dm.ToV2(building.size) / 2, 
            color = color, 
        )
    }

    // Draw Building Pipe
    if gameState.buildUpMode == .Pipe {
        coord := MousePosGrid()

        color: dm.color = (IsInDistance(gameState.playerPosition, coord) ?
                           {0, 0.1, 0.8, 0.5} :
                           {0.8, 0.1, 0, 0.5})

        for dir in gameState.buildingPipeDir {
            dm.DrawWorldRect(
                dm.renderCtx.whiteTexture,
                dm.ToV2(coord) + 0.5,
                {0.5, 0.1},
                rotation = math.to_radians(DirToRot[dir]),
                color = color,
                pivot = {0, 0.5}
            )
        }
    }

    // Destroying
    if gameState.buildUpMode == .Destroy {
        if IsInDistance(gameState.playerPosition, MousePosGrid()) {
            tile := TileUnderCursor()
            if tile.building != {} || tile.pipeDir != nil {
                dm.DrawBlankSprite(tile.worldPos, 1, {1, 0, 0, 0.5})
            }
        }
    }

    // Building Range
    if gameState.buildUpMode != .None {

        playerCoord := WorldPosToCoord(gameState.playerPosition)
        building := Buildings[gameState.selectedBuildingIdx]

        for y in -BUILDING_DISTANCE..=BUILDING_DISTANCE {
            for x in -BUILDING_DISTANCE..=BUILDING_DISTANCE {

                coord := playerCoord + iv2{i32(x), i32(y)}
                if IsInsideGrid(coord) &&
                    IsInDistance(gameState.playerPosition, coord)
                {

                    color: dm.color
                    switch gameState.buildUpMode {
                    case .Building: 
                        color = (CanBePlaced(building, coord) ?
                                           {0, 1, 0, 0.2} :
                                           {1, 0, 0, 0.2})

                    case .Pipe: 
                        tile := GetTileAtCoord(coord)
                        color = (tile.building == {} ?
                                           {0, 0, 1, 0.2} :
                                           {1, 0, 0, 0.2})

                    case .Destroy:
                        color = {1, 0, 0, 0.2}

                    case .None:
                    }

                    dm.DrawBlankSprite(CoordToPos(coord), {1, 1}, color)
                }
            }
        }

        dm.DrawGrid()
    }

    // Player
    dm.DrawSprite(gameState.playerSprite, gameState.playerPosition)

    // path
    // for i := 0; i < len(gameState.path) - 1; i += 1 {
    //     a := gameState.path[i]
    //     b := gameState.path[i + 1]

    //     posA := CoordToPos(a)
    //     posB := CoordToPos(b)
    //     dm.DrawLine(dm.renderCtx, posA, posB, false, dm.BLUE)
    //     dm.DrawCircle(dm.renderCtx, posA, 0.1, false, dm.BLUE)
    // }

    // mouseGrid := MousePosGrid()
    // tiles: [dynamic]iv2
    // hit := IsEmptyLineBetweenCoords(gameState.selectedTile, mouseGrid, &tiles)
    // dm.DrawLine(dm.renderCtx, CoordToPos(gameState.selectedTile), CoordToPos(mouseGrid), false)
    // for t in tiles {
    //     pos := CoordToPos(t)
    //     dm.DrawBlankSprite(pos, {1, 1}, {0, 1, 0, 0.4} if hit else {1, 0, 0, 0.4})
    // }

    selectedTile := GetTileAtCoord(gameState.selectedTile)
    if selectedTile != nil {
        for waypoint in selectedTile.visibleWaypoints {
            dm.DrawLine(dm.renderCtx, CoordToPos(gameState.selectedTile), CoordToPos(waypoint), false)
        }
    }

    for k, path in gameState.pathsBetweenBuildings {
        for i := 0; i < len(path) - 1; i += 1 {
            a := path[i]
            b := path[i + 1]

            dm.DrawLine(dm.renderCtx, dm.ToV2(a) + {0.5, 0.5}, dm.ToV2(b) + {0.5, 0.5}, false, dm.RED)
        }
    }


    dm.DrawText(dm.renderCtx, "WIP version: 0.0.1 pre-pre-pre-pre-pre-alpha", dm.LoadDefaultFont(dm.renderCtx), {0, f32(dm.renderCtx.frameSize.y - 30)}, 20)
}
