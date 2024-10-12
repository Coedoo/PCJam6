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
