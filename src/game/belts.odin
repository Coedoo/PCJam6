package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:slice"

Direction :: enum {
    None,

    East,
    North,
    West,
    South,
}

BeltDir :: struct {
    from, to: Direction,
}

NextDir := [Direction]Direction {
    .None  = .None,

    .East  = .South, 
    .North = .East, 
    .West  = .North, 
    .South = .West
}

PrevDir := [Direction]Direction {
    .None = .None,

    .East  = .North, 
    .North = .West, 
    .West  = .South, 
    .South = .East
}

ReverseDir := [Direction]Direction {
    .None = .None,

    .East  = .West,
    .West  = .East,
    .North = .South,
    .South = .North,
}

DirToRot := [Direction]f32 {
    .None = 0,

    .East  = 0, 
    .North = 90, 
    .West  = 180, 
    .South = 270
}

DirToVec := [Direction]iv2 {
    .None = {0, 0},

    .East  = {1,  0},
    .North = {0,  1},
    .West  = {-1, 0},
    .South = {0, -1},
}

SplitterHandle :: distinct dm.Handle
MergerHandle :: distinct dm.Handle

Splitter :: struct {
    inDir: Direction,
    nextOut: Direction,
}

Merger :: struct {
    outDir: Direction,
    movingItem: ItemHandle,
    queuedItems: [Direction]bool,
}


VecToDir :: proc(vec: iv2) -> Direction {
    if abs(vec.x) > abs(vec.y) {
        return vec.x < 0 ? .West : .East
    }
    else {
        return vec.y < 0 ? .South : .North
    }
}

CoordToPos :: proc(coord: iv2) -> v2 {
    return dm.ToV2(coord) + {0.5, 0.5}
}

PlaceBelt :: proc(coord: iv2, dir: BeltDir) -> ^Tile {
    tile := GetTileAtCoord(coord)
    if tile == nil {
        return nil
    }

    tile.beltDir = dir

    dirVec := DirToVec[dir.to]
    nextTile := GetTileAtCoord(coord + dirVec)
    if nextTile != nil 
    {
        if nextTile.beltDir.from == ReverseDir[dir.to] {
            tile.nextTile = coord + dirVec
        }
        else if splitter, ok := nextTile.splitter.?; ok {
            if splitter.inDir == ReverseDir[dir.to] {
                tile.nextTile = coord + dirVec
            }
        }
        else if merger, ok := nextTile.merger.?; ok {
            if merger.outDir != ReverseDir[dir.to] {
                tile.nextTile = coord + dirVec
            }
        }
    }

    dirVec = DirToVec[dir.from]
    prevTile := GetTileAtCoord(coord + dirVec)
    if prevTile != nil
    {
       if prevTile.beltDir.to == ReverseDir[dir.from] {
            prevTile.nextTile = coord
        }
        else if merger, ok := prevTile.merger.?; ok {
            if merger.outDir == ReverseDir[dir.from] {
                prevTile.nextTile = coord
            }
        }
    }

    return tile
}

PlaceSplitter :: proc(tile: ^Tile) {
    splitter := Splitter {
        inDir = ReverseDir[gameState.buildingBeltDir.to],
        nextOut = gameState.buildingBeltDir.to
    }

    tile.splitter = splitter

    dirVec := DirToVec[splitter.inDir]
    prevTile := GetTileAtCoord(tile.gridPos + dirVec)
    if prevTile != nil {
        if prevTile.beltDir.to == ReverseDir[splitter.inDir] {
            prevTile.nextTile = tile.gridPos
        }
    }
}

PlaceMerger :: proc(tile: ^Tile) {
    merger := Merger {
        outDir = gameState.buildingBeltDir.to,
    }

    neighbors := GetNeighbourTiles(tile.gridPos, context.temp_allocator)
    for neighbor in neighbors {
        dir := DirToVec[neighbor.beltDir.to]
        if neighbor.gridPos + dir == tile.gridPos {
            neighbor.nextTile = tile.gridPos
        }
    }

    tile.merger = merger
}

DestroyBelt :: proc(tile: ^Tile) {
    tile.beltDir = {}
    tile.nextTile = nil

    for x in -1..=1 {
        for y in -1..=1 {
            if x == 0 && y == 0 {
                continue
            }

            otherTile := GetTileAtCoord(tile.gridPos + {i32(x), i32(y)})
            if otherTile == nil {
                continue
            }

            if otherTile.nextTile == tile.gridPos {
                otherTile.nextTile = nil
            }
        }
    }

}