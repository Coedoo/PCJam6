package game

import "core:mem"

import dm "../dmcore"

LEVEL_MEMORY :: mem.Kilobyte * 512
PATH_MEMORY :: mem.Kilobyte * 128

PLAYER_SPEED :: 10
BUILDING_DISTANCE :: 10

START_MONEY :: 1000

PRODUCTION_BASE :: 10

START_LEVEL :: "Level_0"

// DEBUG
DEBUG_TILE_OVERLAY := false


// BUILDINGS

Buildings := [?]Building {
    {
        name = "Factory 1",
        spriteName = "buildings.png",
        spriteRect = {0, 0, 32, 32},

        size = {3, 3},

        maxStorage = 20,
        producedItem= .Sugar,
        productionRate = 10,

        cost = 100,
    },
}