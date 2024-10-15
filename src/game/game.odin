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
    Belt,
    Destroy,
}

BeltBuildMode :: enum {
    Belt,
    Splitter,
    Merger,
}

GameStage :: enum {
    VN,
    Build,
    Validation,
    ValidationResult,
}

GameState :: struct {
    levelArena: mem.Arena,
    levelAllocator: mem.Allocator,

    levels: []Level,
    level: ^Level, // currentLevel

    using levelState: struct {
        spawnedBuildings: dm.ResourcePool(BuildingInstance, BuildingHandle),
        spawnedItems: dm.ResourcePool(ItemInstance, ItemHandle),

        money: int,

        playerPosition: v2,

        selectedTile: iv2,

        buildUpMode: BuildUpMode,
        beltBuildMode: BeltBuildMode,
        selectedBuildingIdx: int,
        buildingBeltDir: BeltDir,

        currentWaveIdx: int,

        levelFullySpawned: bool,

        pathsBetweenBuildings: map[PathKey][]iv2,

        stage: GameStage,

        validationTimer: f32,
        validationResult: [Item]int,

        challengeIdx: int,
        challengeMessageIdx: int,
    },

    playerSprite: dm.Sprite,
    arrowSprite: dm.Sprite,

    itemsSprites: [Item]dm.Sprite,

    splitterSprite: dm.Sprite,
    mergerSprite: dm.Sprite,

    beltsSprites: map[BeltDir]dm.Sprite,
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

    dm.RegisterAsset("Jelly.png", dm.TextureAssetDescriptor{})
    dm.RegisterAsset("belts.png", dm.TextureAssetDescriptor{})
    dm.RegisterAsset("items.png", dm.TextureAssetDescriptor{})

    dm.RegisterAsset("Jelly_VN_Normal.png", dm.TextureAssetDescriptor{})
    dm.RegisterAsset("Jelly_VN_Thinking.png", dm.TextureAssetDescriptor{})
    dm.RegisterAsset("Jelly_VN_NotLikeThis.png", dm.TextureAssetDescriptor{})


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

    gameState.playerSprite = dm.CreateSprite(dm.GetTextureAsset("Jelly.png"), dm.RectInt{0, 0, 32, 33})
    gameState.playerSprite.scale = 2
    gameState.playerSprite.frames = 4
    gameState.playerSprite.animDirection = .Horizontal

    gameState.levels = LoadLevels()
    OpenLevel(START_LEVEL)

    gameState.arrowSprite = dm.CreateSprite(dm.GetTextureAsset("buildings.png"), dm.RectInt{32 * 2, 0, 32, 32})
    gameState.arrowSprite.scale = 0.4
    gameState.arrowSprite.origin = {0, 0.5}


    itemsTex := dm.GetTextureAsset("items.png")
    gameState.itemsSprites = {
        .None = {},
        .Sugar       = dm.CreateSprite(itemsTex, dm.RectInt{0,  0, 16, 16}),
        .Candy       = dm.CreateSprite(itemsTex, dm.RectInt{16, 0, 16, 16}),
        .BiggerCandy = dm.CreateSprite(itemsTex, dm.RectInt{0, 16, 16, 16}),
    }

    beltsTex := dm.GetTextureAsset("belts.png")
    gameState.splitterSprite = dm.CreateSprite(beltsTex, dm.RectInt{0, 16, 16, 16})
    gameState.mergerSprite = dm.CreateSprite(beltsTex, dm.RectInt{16, 16, 16, 16})

    gameState.beltsSprites[{.West, .East}]   = dm.CreateSprite(beltsTex, dm.RectInt{0,  0, 16, 16})
    gameState.beltsSprites[{.East, .West}]   = dm.CreateSprite(beltsTex, dm.RectInt{0,  0, 16, 16}, flipX = true)
    gameState.beltsSprites[{.South, .North}] = dm.CreateSprite(beltsTex, dm.RectInt{16, 0, 16, 16})
    gameState.beltsSprites[{.North, .South}] = dm.CreateSprite(beltsTex, dm.RectInt{16, 0, 16, 16}, flipY = true)

    gameState.beltsSprites[{.South, .East}] = dm.CreateSprite(beltsTex, dm.RectInt{32, 0, 16, 16})
    gameState.beltsSprites[{.South, .West}] = dm.CreateSprite(beltsTex, dm.RectInt{32, 0, 16, 16}, flipX = true)

    gameState.beltsSprites[{.West, .South}] = dm.CreateSprite(beltsTex, dm.RectInt{48, 0, 16, 16})
    gameState.beltsSprites[{.East, .South}] = dm.CreateSprite(beltsTex, dm.RectInt{48, 0, 16, 16}, flipX = true)

    gameState.beltsSprites[{.North, .East}] = dm.CreateSprite(beltsTex, dm.RectInt{48, 16, 16, 16})
    gameState.beltsSprites[{.North, .West}] = dm.CreateSprite(beltsTex, dm.RectInt{48, 16, 16, 16}, flipX = true)

    gameState.beltsSprites[{.East, .North}] = dm.CreateSprite(beltsTex, dm.RectInt{32, 16, 16, 16})
    gameState.beltsSprites[{.West, .North}] = dm.CreateSprite(beltsTex, dm.RectInt{32, 16, 16, 16}, flipX = true)
}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState = cast(^GameState) state

    switch gameState.stage {
        case .VN: VNModeUpdate(); return
        case .Build: BuildingModeUpdate()
        case .Validation: ValidationModeUpdate()
        case .ValidationResult: ValidationResultUpdate()
    }
    // Highlight Building 
    if gameState.buildUpMode == .None && dm.muiIsCursorOverUI(dm.mui, dm.input.mousePos) == false {
        if dm.GetMouseButton(.Left) == .JustPressed {
            coord := MousePosGrid()
            gameState.selectedTile = coord
        }
    }

    tile := GetTileAtCoord(gameState.selectedTile)
    if tile.building != {} || tile.beltDir != {} {
        if dm.muiBeginWindow(dm.mui, "Selected Building", {600, 10, 140, 250}, {.NO_CLOSE}) {
            dm.muiLabel(dm.mui, tile.beltDir)

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

                        dm.muiLabel(dm.mui, "\nInputs:")
                        for input in building.inputState {
                            if input.storedItem == .None {
                                continue
                            }

                            dm.muiLabel(dm.mui, input.storedItem, input.itemsCount)
                        }
                    }
                }
            }

            dm.muiEndWindow(dm.mui)
        }
    }
}

VNModeUpdate :: proc() {
    if dm.GetMouseButton(.Left) == .JustReleased {
        gameState.challengeMessageIdx += 1
        if gameState.challengeMessageIdx >= len(Challanges[gameState.challengeIdx].messages) {
            gameState.stage = .Build
        }
    }

    dm.renderCtx.camera.position.xy = cast([2]f32) gameState.playerPosition
}

BuildingModeUpdate :: proc() {
    cursorOverUI := dm.muiIsCursorOverUI(dm.mui, dm.input.mousePos)

    // Move Player
    inputVec := v2{
        dm.GetAxis(.A, .D),
        dm.GetAxis(.S, .W)
    }

    if inputVec != {0, 0} {
        moveVec := glsl.normalize(inputVec)

        CheckCollision :: proc(moveVec: v2) -> bool {
            newPos := gameState.playerPosition + moveVec * PLAYER_SPEED * f32(dm.time.deltaTime)
            playerBounds := dm.Bounds2D{
                newPos.x - 1, newPos.x + 1,
                newPos.y - 1, newPos.y + 1,
            }

            isColliding: bool
            it := dm.MakePoolIter(&gameState.spawnedBuildings)
            for building in dm.PoolIterate(&it) {
                data := Buildings[building.dataIdx]
                buildingBounds := dm.Bounds2D{
                    f32(building.gridPos.x), f32(building.gridPos.x + data.size.x),
                    f32(building.gridPos.y), f32(building.gridPos.y + data.size.y),
                }

                coll := dm.CheckCollisionBounds(playerBounds, buildingBounds)
                if coll {
                    return true
                }
            }

            return false
        }

        isColliding: [2]bool = {true, true}
        if moveVec.x != 0 && CheckCollision({moveVec.x, 0}) == false {
            gameState.playerPosition += v2{moveVec.x, 0} * PLAYER_SPEED * f32(dm.time.deltaTime)
            isColliding.x = false
        }
        if moveVec.y != 0 && CheckCollision({0, moveVec.y}) == false {
            gameState.playerPosition += v2{0, moveVec.y} * PLAYER_SPEED * f32(dm.time.deltaTime)
            isColliding.y = false
        }

        if isColliding.x == false || isColliding.y == false {
            if inputVec.y == -1 {
                gameState.playerSprite.texturePos.y = 0
                gameState.playerSprite.flipX = false
            }
            else if inputVec.y == 1 {
                gameState.playerSprite.texturePos.y = 32
                gameState.playerSprite.flipX = false
            }
            else if inputVec.x == -1 {
                gameState.playerSprite.texturePos.y = 64
                gameState.playerSprite.flipX = false
            }
            else {
                gameState.playerSprite.texturePos.y = 64
                gameState.playerSprite.flipX = true
            }

            dm.AnimateSprite(&gameState.playerSprite, f32(dm.time.gameTime), 0.2)
            // fmt.println("FUCK")
        }
    }
    else {
        gameState.playerSprite.currentFrame = 0
        // fmt.println(dm.time.frame, gameState.playerSprite.texturePos.x)
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

    // Destroy structres
    if gameState.buildUpMode == .Destroy &&
       dm.GetMouseButton(.Left) == .JustPressed &&
       cursorOverUI == false
    {
        tile := TileUnderCursor()
        if tile.building != {} {
            RemoveBuilding(tile.building)
        }
        else if tile.beltDir != {} {
            DestroyBelt(tile)
        }
    }

    if dm.GetMouseButton(.Right) == .JustPressed &&
       cursorOverUI == false
    {
        gameState.buildUpMode = .None
    }

    // Belt
    if gameState.buildUpMode == .Belt &&
       cursorOverUI == false
    {
        leftBtn := dm.GetMouseButton(.Left)
        if leftBtn == .Down  {
            coord := MousePosGrid()
            if IsInDistance(gameState.playerPosition, coord) {
                tile := GetTileAtCoord(coord)

                canPlace := tile.building == {}

                if canPlace {
                    switch gameState.beltBuildMode {
                    case .Belt: 
                        PlaceBelt(coord, gameState.buildingBeltDir)
                    case .Splitter:
                        PlaceSplitter(tile)
                    case .Merger:
                        tile.merger = Merger{
                            outDir = gameState.buildingBeltDir.to
                        }
                    }

                }
            }
        }

        if dm.input.scroll != 0 {
            dirSet := NextDir if dm.input.scroll < 0 else PrevDir
            gameState.buildingBeltDir.from = dirSet[gameState.buildingBeltDir.from]
            gameState.buildingBeltDir.to = dirSet[gameState.buildingBeltDir.to]
        }

        if dm.GetKeyState(.Num1) == .JustPressed {
            gameState.beltBuildMode = .Belt
            gameState.buildingBeltDir.from = ReverseDir[gameState.buildingBeltDir.to]
        }
        if dm.GetKeyState(.Num2) == .JustPressed {
            gameState.beltBuildMode = .Belt
            gameState.buildingBeltDir.from = NextDir[gameState.buildingBeltDir.to]
        }
        if dm.GetKeyState(.Num3) == .JustPressed {
            gameState.beltBuildMode = .Splitter
        }
        if dm.GetKeyState(.Num4) == .JustPressed {
            gameState.beltBuildMode = .Merger
        }

        if dm.GetMouseButton(.Middle) == .JustPressed {
            newDir := BeltDir {
                from = gameState.buildingBeltDir.to,
                to   = gameState.buildingBeltDir.from,
            }

            gameState.buildingBeltDir = newDir
        }
    }


    // Building
    if gameState.buildUpMode == .Building
    {
        if dm.GetMouseButton(.Left) == .JustPressed &&
           cursorOverUI == false
        {
            idx := gameState.selectedBuildingIdx
            building := Buildings[idx]

            pos := MousePosGrid()
            pos -= building.size / 2

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

    if dm.muiBeginWindow(dm.mui, "MAIN GUI", {10, 10, 170, 300}, {.NO_TITLE, .NO_RESIZE}) {
        dm.muiLabel(dm.mui, "Money:", gameState.money)
        if dm.muiButton(dm.mui, "Build Building") {
            gameState.buildUpMode = .Building
        }

        if dm.muiButton(dm.mui, "Build Belt") {
            gameState.buildUpMode = .Belt
        }

        dm.muiLabel(dm.mui, "")
        if dm.muiHeader(dm.mui, "Level goals") {
            dm.muiLabel(dm.mui, "TBD")
        }

        if dm.muiButton(dm.mui, "CHECK SOLUTION") {
            StartValidation()
        }

        dm.muiEndWindow(dm.mui)
    }


    if gameState.buildUpMode == .Building {
        if dm.muiBeginWindow(dm.mui, "BUILDINGS", {190, 10, 170, 300}, {.NO_TITLE, .NO_RESIZE }) {
            dm.muiLabel(dm.mui, "Buildings:")
            for b, idx in Buildings {
                if dm.muiButton(dm.mui, fmt.tprintf("%v - %v", idx + 1, b.name)) {
                    gameState.selectedBuildingIdx = idx
                }
            }
            dm.muiEndWindow(dm.mui)
        }
    }

    if gameState.buildUpMode == .Belt {
        if dm.muiBeginWindow(dm.mui, "BELTS", {190, 10, 170, 300}, {.NO_TITLE, .NO_RESIZE}) {
            dm.muiLabel(dm.mui, "Belts:")
            if dm.muiButton(dm.mui, "1 - Belt") {
                gameState.beltBuildMode = .Belt
                gameState.buildingBeltDir = {.West, .East}
            }
            
            if dm.muiButton(dm.mui, "2 - Angled") {
                gameState.beltBuildMode = .Belt
                gameState.buildingBeltDir = {.South, .East}
            }

            if dm.muiButton(dm.mui, "3 - Splitter") {
                gameState.beltBuildMode = .Splitter
            }

            if dm.muiButton(dm.mui, "4 - Merger") {
                gameState.beltBuildMode = .Merger
            }

            dm.muiEndWindow(dm.mui)
        }
    }

    // temp UI
    // if dm.muiBeginWindow(dm.mui, "GAME MENU", {10, 10, 110, 450}) {
    //     dm.muiLabel(dm.mui, gameState.selectedTile)
    //     dm.muiLabel(dm.mui, "Money:", gameState.money)

    //     for b, idx in Buildings {
    //         if dm.muiButton(dm.mui, b.name) {
    //             gameState.selectedBuildingIdx = idx
    //             gameState.buildUpMode = .Building
    //         }
    //     }

    //     // dm.muiLabel(dm.mui, "Pipes:")
    //     if dm.muiButton(dm.mui, "Belt") {
    //         gameState.buildUpMode = .Belt
    //         gameState.beltBuildMode = .Straight
    //         gameState.buildingBeltDir = {.West, .East}
    //     }

    //     // if dm.muiButton(dm.mui, "Angled") {
    //     //     gameState.buildUpMode = .Belt
    //     //     gameState.buildingBeltDir = {.South, .East}
    //     // }

    //     dm.muiLabel(dm.mui)
    //     if dm.muiButton(dm.mui, "Destroy") {
    //         gameState.buildUpMode = .Destroy
    //     }

    //     if dm.muiButton(dm.mui, "Reset level") {
    //         name := gameState.level.name
    //         OpenLevel(name)
    //     }

    //     dm.muiLabel(dm.mui, "LEVELS:")
    //     for l in gameState.levels {
    //         if dm.muiButton(dm.mui, l.name) {
    //             OpenLevel(l.name)
    //         }
    //     }

    //     dm.muiLabel(dm.mui, "MEMORY")
    //     dm.muiLabel(dm.mui, "\tLevel arena HWM:", gameState.levelArena.peak_used / mem.Kilobyte, "kb")
    //     dm.muiLabel(dm.mui, "\tLevel arena used:", gameState.levelArena.offset / mem.Kilobyte, "kb")

    //     if dm.muiButton(dm.mui, "START VALIDATION") {
    //         StartValidation()
    //     }

    //     dm.muiEndWindow(dm.mui)
    // }

    // if gameState.buildUpMode != .None {
    //     size := iv2{
    //         100, 60
    //     }

    //     pos := iv2{
    //         dm.renderCtx.frameSize.x / 2 - size.x / 2,
    //         dm.renderCtx.frameSize.y - 100,
    //     }

    //     if dm.muiBeginWindow(dm.mui, "Current Mode", {pos.x, pos.y, size.x, size.y}, 
    //         {.NO_CLOSE, .NO_RESIZE})
    //     {
    //         label := gameState.buildUpMode == .Building ? "Building" :
    //                  gameState.buildUpMode == .Belt     ? "Belt" :
    //                  gameState.buildUpMode == .Destroy  ? "Destroy" :
    //                                                       "UNKNOWN MODE"

    //         dm.muiLabel(dm.mui, label)

    //         dm.muiEndWindow(dm.mui)
    //     }
    // }
}

StartValidation :: proc() {
    gameState.stage = .Validation
    gameState.validationTimer = 0

    viewBounds := dm.Bounds2D{
        max(f32), min(f32),
        max(f32), min(f32),
    }

    buildingIt := dm.MakePoolIter(&gameState.spawnedBuildings)
    for building in dm.PoolIterate(&buildingIt) {
        data := Buildings[building.dataIdx]
        buildingBounds := dm.Bounds2D {
            f32(building.gridPos.x), f32(building.gridPos.x + data.size.x),
            f32(building.gridPos.y), f32(building.gridPos.y + data.size.y),
        }

        viewBounds.left  = min(viewBounds.left, buildingBounds.left)
        viewBounds.right = max(viewBounds.right, buildingBounds.right)
        viewBounds.bot   = min(viewBounds.bot, buildingBounds.bot)
        viewBounds.top   = max(viewBounds.top, buildingBounds.top)
    }

    camAspect := dm.renderCtx.camera.aspect
    camHeight := (viewBounds.top - viewBounds.bot)
    camWidth  := (viewBounds.right - viewBounds.left)
    camSize := max(camHeight, camWidth / camAspect) / 2

    dm.renderCtx.camera.position.xy = cast([2]f32) dm.BoundsCenter(viewBounds)
    dm.renderCtx.camera.orthoSize = camSize
}

ValidationModeUpdate :: proc() {
    gameState.validationTimer += dm.time.deltaTime

    // Update Buildings
    buildingIt := dm.MakePoolIter(&gameState.spawnedBuildings)
    for building in dm.PoolIterate(&buildingIt) {
        buildingData := &Buildings[building.dataIdx]

        if buildingData.producedItem != .None {
            if building.isProducing {
                building.productionTimer += f32(dm.time.deltaTime)
                
                productionTime := PRODUCTION_BASE / f32(buildingData.productionRate)
                if building.productionTimer >= productionTime {
                    building.productionTimer = 0
                    building.currentItemsCount += 1
                    building.isProducing = false
                }
            }

            if building.isProducing == false &&
                RemoveItemsForItemSpawn(building, buildingData.producedItem)
            {
                building.isProducing = true
            }
        }

        // spawnItems
        if building.currentItemsCount > 0 {
            spawnCoord := building.gridPos + buildingData.output.offset
            spawnPos := CoordToPos(spawnCoord)
            if CheckItemCollision(spawnPos, {}) == false {
                item := dm.CreateElement(&gameState.spawnedItems)
                item.type = buildingData.producedItem
                item.position = spawnPos
                item.nextTile = spawnCoord

                building.currentItemsCount -= 1
            }
        }
    }

    // Update Items
    it := dm.MakePoolIterReverse(&gameState.spawnedItems)
    for item in dm.PoolIterate(&it) {
        targetPos := CoordToPos(item.nextTile)
        pos, leftDist := dm.MoveTowards(item.position, targetPos, ITEM_SPEED * f32(dm.time.deltaTime))
        if leftDist == 0 {
            if CheckItemCollision(pos, item.handle) == false {
                item.position = pos
            }
        }
        else {
            tile := GetTileAtCoord(item.nextTile)
            if tile.isInput {
                building, data := GetBuilding(tile.building)
                input := &building.inputState[tile.inputIndex]
                
                if (input.storedItem == .None || input.storedItem == item.type) &&
                   input.itemsCount < INPUT_MAX_ITEMS
                {
                    input.storedItem = item.type
                    input.itemsCount += 1

                    dm.FreeSlot(&gameState.spawnedItems, item.handle)

                    continue
                }
            }


            if merger, ok := tile.merger.?; ok {
                merger.movingItem = {}
                tile.merger = merger
            }

            if splitter, ok := tile.splitter.?; ok {
                nextDir := splitter.nextOut
                for i in 0..<4 {
                    nextPos := CoordToPos(tile.gridPos + DirToVec[nextDir])
                    if CheckItemCollision(nextPos, {}) == false {
                        tile.nextTile = tile.gridPos + DirToVec[nextDir]

                        nextDir = NextDir[nextDir]
                        if nextDir == splitter.inDir {
                            nextDir = NextDir[nextDir]
                        }
                        break
                    }
                    else {
                        nextDir = NextDir[nextDir]
                        if nextDir == splitter.inDir {
                            nextDir = NextDir[nextDir]
                        }
                    }
                }

                splitter.nextOut = nextDir
                tile.splitter = splitter
            }

            if nextTileCoord, ok := tile.nextTile.?; ok {
                nextTile := GetTileAtCoord(nextTileCoord)
                assert(nextTile != nil)

                if merger, ok := nextTile.merger.?; ok {
                    isFree := true
                    for q in merger.queuedItems {
                        if q == true {
                            isFree = false
                            break
                        }
                    }

                    if isFree && merger.movingItem == {} {
                        item.nextTile = nextTile.gridPos
                        merger.movingItem = item.handle
                        merger.queuedItems[tile.beltDir.to] = false
                    }
                    else {
                        // merger.queuedItems[tile.beltDir.to] = true
                    }

                    nextTile.merger = merger
                }
                else {
                    item.nextTile = nextTile.gridPos
                }


                targetPos = CoordToPos(item.nextTile)
                pos, leftDist = dm.MoveTowards(item.position, targetPos, leftDist)
                if CheckItemCollision(pos, item.handle) == false {
                    item.position = pos
                }
            }
        }
    }

    ClearValidationState :: proc() {
        dm.ClearPool(&gameState.spawnedItems)

        it := dm.MakePoolIter(&gameState.spawnedBuildings)
        for building in dm.PoolIterate(&it) {
            building.isProducing = false
            building.currentItemsCount = 0
            building.productionTimer = 0

            data := Buildings[building.dataIdx]

            for &input in building.inputState {
                input = {}
            }
        }

        for &tile in gameState.level.grid {
            if merger, ok := tile.merger.?; ok {
                merger.movingItem = {}
                merger.queuedItems = {}
                tile.merger = merger
            }
        }

    }


    if dm.muiBeginWindow(dm.mui, "VALIDATION", {10, 10, 170, 300}, {.NO_TITLE, .NO_RESIZE}) {
        dm.muiLabel(
            dm.mui, 
            fmt.tprintf("Time: %.2v/%v s", gameState.validationTimer, VALIDATION_MODE_DURATION)
        )

        if dm.muiButton(dm.mui, "Stop") {
            gameState.validationResult = {}

            ClearValidationState()
            gameState.stage = .Build
        }

        dm.muiEndWindow(dm.mui)
    }

    // validation mode end
    if gameState.validationTimer >= VALIDATION_MODE_DURATION {

        gameState.validationResult = {}

        it := dm.MakePoolIter(&gameState.spawnedBuildings)
        for building in dm.PoolIterate(&it) {

            data := Buildings[building.dataIdx]
            for &input in building.inputState {
                if data.isContainer {
                    gameState.validationResult[input.storedItem] += input.itemsCount
                }
            }
        }

        ClearValidationState()
        gameState.stage = .ValidationResult
    }

}

ValidationResultUpdate :: proc() {
    // Result
    size := iv2{150, 220}
    pos := iv2{
        dm.renderCtx.frameSize.x / 2 - size.x / 2,
        dm.renderCtx.frameSize.y / 2 - size.y / 2,
    }
    if dm.muiBeginWindow(dm.mui, "RESULT", {pos.x, pos.y, size.x, size.y}, { .NO_TITLE, .NO_RESIZE}) {
        for res, i in gameState.validationResult {
            type := Item(i)
            if type == .None do continue
            if res == 0 do continue

            dm.muiLabel(dm.mui, type, "-", res)
        }

        if dm.muiButton(dm.mui, "Ok") {
            gameState.stage = .Build
        }

        dm.muiEndWindow(dm.mui)
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

    // Draw Belts
    DrawBelt :: proc(beltDir: BeltDir, pos: v2, alpha: f32) {
        sprite, ok := gameState.beltsSprites[beltDir]
        if ok {
            dm.DrawSprite(
                sprite, 
                pos,
                color = {1, 1, 1, alpha}
            )
        }
    }

    for tile, idx in gameState.level.grid {

        if tile.beltDir != {} {
            DrawBelt(tile.beltDir, tile.worldPos, 1)
        }
        else if splitter, ok := tile.splitter.?; ok {
            dm.DrawSprite(
                gameState.splitterSprite,
                tile.worldPos,
                math.to_radians(DirToRot[ReverseDir[splitter.inDir]])
            )
        }
        else if merger, ok := tile.merger.?; ok {
            dm.DrawSprite(
                gameState.mergerSprite,
                tile.worldPos,
                math.to_radians(DirToRot[tile.beltDir.from])
            )
        }


        if next, ok := tile.nextTile.?; ok {
            posA := tile.worldPos
            posB := CoordToPos(next)
            dm.DrawLine(dm.renderCtx, posA, posB, false, dm.BLUE)
        }
    }

    // Draw Items 
    it := dm.MakePoolIter(&gameState.spawnedItems)
    for item in dm.PoolIterate(&it) {
        sprite := gameState.itemsSprites[item.type]
        dm.DrawSprite(sprite, item.position)
    }

    // draw Buildings
    for &building in gameState.spawnedBuildings.elements {
        // @TODO @CACHE
        buildingData := &Buildings[building.dataIdx]
        tex := dm.GetTextureAsset(buildingData.spriteName)
        sprite := dm.CreateSprite(tex, buildingData.spriteRect)
        sprite.scale = f32(buildingData.size.x)

        pos := building.position
        dm.DrawSprite(sprite, pos)
    }

    // Draw Placing structures
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
                        coord := coord - building.size / 2
                        color = (CanBePlaced(building, coord) ?
                                           {0, 1, 0, 0.2} :
                                           {1, 0, 0, 0.2})

                    case .Belt: 
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

    if gameState.buildUpMode == .Building {
        building := Buildings[gameState.selectedBuildingIdx]
        gridPos := MousePosGrid()
        gridPos -= building.size / 2


        // @TODO @CACHE
        tex := dm.GetTextureAsset(building.spriteName)
        sprite := dm.CreateSprite(tex, building.spriteRect)

        color := dm.GREEN
        if CanBePlaced(building, gridPos) == false ||
            IsInDistance(gameState.playerPosition, gridPos) == false
        {
            color = dm.RED
        }

        sprite.scale = f32(building.size.x)

        dm.DrawSprite(
            sprite, 
            dm.ToV2(gridPos) + dm.ToV2(building.size) / 2, 
            color = color, 
        )
    }

    // Draw Building Belt
    if gameState.buildUpMode == .Belt {
        pos := CoordToPos(MousePosGrid())

        switch gameState.beltBuildMode {
        case .Belt: 
            DrawBelt(gameState.buildingBeltDir, pos, 0.4)
        case .Splitter: 
            dm.DrawSprite(
                gameState.splitterSprite, 
                pos,
                math.to_radians(DirToRot[gameState.buildingBeltDir.to]),
                {1, 1, 1, 0.4},
            )
        case .Merger:
            dm.DrawSprite(
                gameState.mergerSprite, 
                pos,
                math.to_radians(DirToRot[gameState.buildingBeltDir.to]),
                {1, 1, 1, 0.4},
            )
        }
    }

    // Destroying
    if gameState.buildUpMode == .Destroy {
        if IsInDistance(gameState.playerPosition, MousePosGrid()) {
            tile := TileUnderCursor()
            if tile.building != {} || tile.beltDir != {} {
                dm.DrawBlankSprite(tile.worldPos, 1, {1, 0, 0, 0.5})
            }
        }
    }


    // Player
    dm.DrawSprite(gameState.playerSprite, gameState.playerPosition)

    for k, path in gameState.pathsBetweenBuildings {
        for i := 0; i < len(path) - 1; i += 1 {
            a := path[i]
            b := path[i + 1]

            dm.DrawLine(dm.renderCtx, dm.ToV2(a) + {0.5, 0.5}, dm.ToV2(b) + {0.5, 0.5}, false, dm.RED)
        }
    }

    if gameState.stage == .VN {
        rectHeight :: 200
        margin :: 20

        centerPos := v2 {
            f32(dm.renderCtx.frameSize.x) / 2,
            f32(dm.renderCtx.frameSize.y) - rectHeight / 2 - margin,
        }
        width := f32(dm.renderCtx.frameSize.x) - margin * 2

        message := Challanges[gameState.challengeIdx].messages[gameState.challengeMessageIdx]
        
        dm.DrawRect(
            dm.GetTextureAsset(message.imageName),
            v2{
                f32(dm.renderCtx.frameSize.x) - 200,
                centerPos.y
            },
            scale = 1.5
        )

        dm.DrawRect(centerPos, v2{width, rectHeight}, color = dm.color{0, 0, 0, 0.6})
        dm.DrawTextCentered(
            dm.renderCtx,
            message.message,
            dm.LoadDefaultFont(dm.renderCtx),
            centerPos, 40)

        dm.DrawTextCentered(
            dm.renderCtx,
            "Click To continue",
            dm.LoadDefaultFont(dm.renderCtx),
            v2{centerPos.x, f32(dm.renderCtx.frameSize.y) - margin - 20},
            15,
            color = {0.4, 0.4, 0.4, 0.8})
    }
}
