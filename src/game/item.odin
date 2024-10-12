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
}

ItemHandle :: distinct dm.Handle

ItemInstance :: struct {
    type: Item,
    handle: ItemHandle,

    position: v2,

    nextTile: iv2,
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