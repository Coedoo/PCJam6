package game

import "core:mem"

import dm "../dmcore"

LEVEL_MEMORY :: mem.Kilobyte * 512

PLAYER_SPEED :: 10
PLAYER_COLL_SIZE :: v2{0.6, 0.2}
PLAYER_COLL_OFFSET :: v2{0, -0.9}

BUILDING_DISTANCE :: 7

PRODUCTION_BASE :: 1

ITEM_SIZE :: 0.7
ITEM_SPEED :: 10

MAX_INPUTS :: 3
INPUT_MAX_ITEMS :: 10

START_LEVEL :: "Level_0"

START_CHALLENGE :: 4

// DEBUG
DEBUG_TILE_OVERLAY := false

Recipes := [Item]ItemRecipe {
    .None = {},
    .Sugar = {},
    .Flour = {},
    .CoffeeBean = {},

    .Chocolate = {{.Sugar, 5}},
    .Candy = {{.Sugar, 5}},

    .StarCandy = {{.Sugar, 2}, {.Candy, 1}},
    .Cookie = {{.Chocolate, 3}, {.Flour, 2}},
    .PhaseCoffee = {{.CoffeeBean, 4}, {.Sugar, 4}},
}

Buildings := [?]Building {
    {
        name = "Container",
        spriteName = "buildings.png",
        spriteRect = {48 * 2, 0, 48, 48},

        description = "Stores all the items you made",

        size = {3, 3},

        cost = 100,

        output = {},
        inputs = {
            {{0, 1}, {.West, .East}}
        },

        isContainer = true,
    },

    {
        name = "Sugar factory",
        spriteName = "buildings.png",
        spriteRect = {0, 0, 48, 48},

        description = "Creates sugar from something... Alien technology, don't ask.",

        size = {3, 3},

        showItemOffset = {0, .4},

        maxStorage = 20,
        producedItem= .Sugar,
        productionRate = 20,

        cost = 100,

        output = {{2, 1}, {.West, .East}}
    },

    {
        name = "Candy factory",
        spriteName = "buildings.png",
        spriteRect = {48, 0, 48, 48},

        description = "Transforms sugar into its ultimate form.",

        size = {3, 3},

        showItemOffset = {0, 0},

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
        name = "Star Candy Factory",
        spriteName = "buildings.png",
        spriteRect = {0, 48, 64, 64},

        description = "Apparently the candy was created after the first observation of the  star Gliese 667C. The marketing team couldn't know that she was gonna collapse into a Black Hole just year a later.",

        size = {4, 4},

        showItemOffset = {0.8, .4},

        maxStorage = 20,
        producedItem= .StarCandy,
        productionRate = 10,

        cost = 100,

        unlockedAfterLevel = 1,

        output = {{3, 2}, {.West, .East}},
        
        inputs = {
            {{0, 0},{.West, .East}},
            {{0, 1},{.West, .East}},
        }
    },

    {
        name = "Chocolate factory",
        spriteName = "buildings.png",
        spriteRect = {48, 0, 48, 48},

        description = "What do you mean I need cocoa for that!?",

        size = {3, 3},

        maxStorage = 20,
        producedItem= .Chocolate,
        productionRate = 10,

        unlockedAfterLevel = 2,

        cost = 100,

        output = {{2, 1}, {.West, .East}},
        inputs = {
            {{0, 1}, {.West, .East}}
        },
    },

    {
        name = "Flour factory",
        spriteName = "buildings.png",
        spriteRect = {0, 0, 48, 48},

        description = "Teleports flour from... Moon! Yeah, Moon, good enough...",

        size = {3, 3},

        showItemOffset = {0, .4},

        maxStorage = 20,
        producedItem= .Flour,
        productionRate = 4,

        unlockedAfterLevel = 3,

        cost = 100,

        output = {{2, 1}, {.West, .East}}
    },

    {
        name = "Cookie Factory",
        spriteName = "buildings.png",
        spriteRect = {0, 48, 64, 64},

        description = "Is that an Amanogawa Shiina reference?!",

        size = {4, 4},

        showItemOffset = {0.8, .4},

        unlockedAfterLevel = 3,

        maxStorage = 20,
        producedItem= .Cookie,
        productionRate = 10,

        cost = 100,

        output = {{3, 2}, {.West, .East}},
        
        inputs = {
            {{0, 0},{.West, .East}},
            {{0, 1},{.West, .East}},
        }
    },

    {
        name = "Coffee factory",
        spriteName = "buildings.png",
        spriteRect = {0, 0, 48, 48},

        description = "Only the special coffee beans, blessed by Sakana himself, are used to produce the original Phase Coffee",

        size = {3, 3},

        maxStorage = 20,
        producedItem= .CoffeeBean,
        productionRate = 20,

        unlockedAfterLevel = 4,

        cost = 100,

        output = {{2, 1}, {.West, .East}}
    },

    {
        name = "Phase Coffee Machine",
        spriteName = "buildings.png",
        spriteRect = {0, 48, 64, 64},

        description = "The original Jelly Hoshiumi of Phase Connect, generation ?, Phase Invaders. Availble now at shop.phase-connect.com\nServed only with sugar because I didn't want to add another item.",

        size = {4, 4},

        showItemOffset = {0.8, .4},

        unlockedAfterLevel = 4,

        maxStorage = 20,
        producedItem= .PhaseCoffee,
        productionRate = 10,

        cost = 100,

        output = {{3, 2}, {.West, .East}},
        
        inputs = {
            {{0, 0},{.West, .East}},
            {{0, 1},{.West, .East}},
        }
    },

}