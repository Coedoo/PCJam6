package game

import "core:mem"

import dm "../dmcore"

LEVEL_MEMORY :: mem.Kilobyte * 512
PATH_MEMORY :: mem.Kilobyte * 128

PLAYER_SPEED :: 10
BUILDING_DISTANCE :: 10

START_MONEY :: 1000

PRODUCTION_BASE :: 10

ITEM_SIZE :: 1
ITEM_SPEED :: 3

MAX_INPUTS :: 3
INPUT_MAX_ITEMS :: 50

START_LEVEL :: "Level_0"

// DEBUG
DEBUG_TILE_OVERLAY := false


// BUILDINGS

Buildings := [?]Building {
    {
        name = "Container",
        spriteName = "buildings.png",
        spriteRect = {0, 0, 32, 32},

        size = {3, 3},

        cost = 100,

        output = {},
        inputs = {
            {{0, 1}, {.West, .East}}
        },

        isContainer = true,
    },

    {
        name = "Factory 1",
        spriteName = "buildings.png",
        spriteRect = {0, 0, 32, 32},

        size = {3, 3},

        maxStorage = 20,
        producedItem= .Sugar,
        productionRate = 10,

        cost = 100,

        output = {{2, 1}, {.West, .East}}
    },

    {
        name = "Factory 2",
        spriteName = "buildings.png",
        spriteRect = {32, 0, 32, 32},

        size = {3, 3},

        maxStorage = 20,
        producedItem= .Candy,
        productionRate = 10,

        cost = 100,

        output = {{2, 1}, {.West, .East}},
        
        inputs = {
            {{0, 1}, {.West, .East}}
        }
    },

    {
        name = "Factory 3",
        spriteName = "buildings.png",
        spriteRect = {32, 0, 32, 32},

        size = {3, 3},

        maxStorage = 20,
        producedItem= .Candy,
        productionRate = 10,

        cost = 100,

        output = {{2, 1}, {.West, .East}},
        
        inputs = {
            {{0, 0},{.West, .East}},
            {{0, 2},{.West, .East}},
        }
    },
}