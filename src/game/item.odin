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
    BiggerCandy,
}

ItemHandle :: distinct dm.Handle

ItemInstance :: struct {
    type: Item,
    handle: ItemHandle,

    position: v2,

    nextTile: iv2,
}

ItemCount :: struct {
    type: Item,
    count: int,
}

ItemRecipe :: distinct []ItemCount

Recipes := [Item]ItemRecipe {
    .None = {},
    .Sugar = {},
    .Candy = {{.Sugar, 5}},
    .BiggerCandy = {{.Sugar, 3}, {.Candy, 2}},
}

CheckItemCollision :: proc(pos: v2, excludeHandle: ItemHandle) -> bool {
    it := dm.MakePoolIter(&gameState.spawnedItems)

    for item in dm.PoolIterate(&it) {
        if item.handle == excludeHandle {
            continue
        }

        collision := dm.CheckCollisionCircles(pos, 0.5, item.position, 0.5)
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