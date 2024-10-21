package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:slice"

Item :: enum {
    None,
    Sugar,
    Candy,
    Flour,
    CoffeeBean,
    Chocolate,
    Cookie,
    StarCandy,
    PhaseCoffee,
}

ItemHandle :: distinct dm.Handle

ItemInstance :: struct {
    type: Item,
    handle: ItemHandle,

    position: v2,

    nextTile: iv2,

    waitingForMerger: bool,
}

ItemCount :: struct {
    type: Item,
    count: int,
}

ItemRecipe :: distinct []ItemCount

CheckItemCollision :: proc(pos: v2, excludeHandle: ItemHandle) -> bool {
    it := dm.MakePoolIter(&gameState.spawnedItems)

    for item in dm.PoolIterate(&it) {
        if item.handle == excludeHandle {
            continue
        }

        collision := dm.CheckCollisionCircles(pos, ITEM_SIZE / 2, item.position, ITEM_SIZE / 2)
        if collision {
            return true
        }
    }

    return false
}

RemoveItemsForItemSpawn :: proc(building: ^BuildingInstance, item: Item) -> bool {
    recipe := Recipes[item]

    toRemove: [MAX_INPUTS]int
    conditionsMet: int

    for itemCount in recipe {
        for input, i in building.inputState {
            if input.storedItem == itemCount.type &&
               input.itemsCount >= itemCount.count
            {
                toRemove[i] += itemCount.count
                conditionsMet += 1

                break
            }
        }
    }

    if conditionsMet == len(recipe) {
        for &input, i in building.inputState {
            input.itemsCount -= toRemove[i]
        }

        return true
    }

    return false
}