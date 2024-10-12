package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:slice"

import "../ldtk"

BuildingHandle :: dm.Handle

BuildingIO :: struct {
    offset: iv2,
    beltDir: BeltDir,
}

BuildingInput :: struct {
    storedItem: Item,
    itemsCount: int,
}

Building :: struct {
    name: string,
    spriteName: string,
    spriteRect: dm.RectInt,

    // flags: BuildignFlags,
    restrictedTiles: []TileType,

    size: iv2,

    cost: int,

    maxStorage: int,

    output: BuildingIO,
    inputs: []BuildingIO,

    producedItem: Item,
    productionRate: int,
}

BuildingInstance :: struct {
    handle: BuildingHandle,
    dataIdx: int,

    gridPos: iv2,
    position: v2,

    currentItemsCount: int,
    productionTimer: f32,

    inputState: [MAX_INPUTS]BuildingInput,
}

GetBuilding :: proc(handle: BuildingHandle) -> (^BuildingInstance, Building) {
    instance, ok := dm.GetElementPtr(gameState.spawnedBuildings, handle)
    if ok == false {
        return nil, {}
    }

    return instance, Buildings[instance.dataIdx]
}