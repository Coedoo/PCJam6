package game

import dm "../dmcore"
import "core:fmt"


Challange :: struct {
    name: string,
    time: f32,
    money: int,

    items: []ItemCount,

    messages: []Message,
}

Message :: struct {
    message: string,
    imageName: string,
    isFinal: bool,
}

ImageNormal :: "Jelly_VN_Normal.png"
ImageThinking :: "Jelly_VN_Thinking.png"
ImageThinkingEx :: "Jelly_VN_Thinking2.png"
ImageNotLikeThis :: "Jelly_VN_NotLikeThis.png"
ImageNotLikeThisEx :: "Jelly_VN_NotLikeThis2.png"

Challenges := [?]Challange{
    // Level 1
    {
        name = "beginning",
        time = 10,
        items = {{.Candy, 10}},
        money = 600,

        messages = {
            {
                imageName = ImageNormal,
                message = "Tomorrow is\n Halloween...",
            },
            {
                imageName = ImageThinking,
                message = "And I don't have any sweets for children",
            },
            {
                imageName = ImageNotLikeThis,
                message = "I would go to shop but I don't want to leave my home,\nand there we be a lot of people everywhere",
            },
            {
                imageName = ImageThinking,
                message = "There is only one way out of this situation",
            },
            {
                imageName = ImageNormal,
                message = "AUTOMATION!",
            },
            {
                imageName = "",
                message = "Place buildings on the map and connect them with belts",
            },
            {
                imageName = "",
                message = "Only items placed in Containers are counted\nto the final score",
            },
        } 
    },

    // Level 2
    {
        name = "More candies",
        time = 10,
        items = {{.Candy, 10}, {.StarCandy, 5}},
        money = 800,

        messages = {
            {
                imageName = ImageNormal,
                message = "That should be enough for tomorrow",
            },

            {
                imageName = ImageThinking,
                message = "Buuut, I can do better than this",
            },

            {
                imageName = "",
                message = "Splitters and Mergers allow to route\nexcess items to different bulidings",
            },
        }
    },

    // Level 2
    {
        name = "Chocolate",
        time = 10,
        items = {{.Candy, 10}, {.StarCandy, 10}, {.Chocolate, 5}},
        money = 1000,

        messages = {
            {
                imageName = ImageThinking,
                message = "All those candies are nice and all...",
            },

            {
                imageName = ImageNormal,
                message = "I want some chocolate though",
            },
        }
    },

    // Level 3
    {
        name = "Cookies",
        time = 10,
        items = {{.Candy, 10}, {.StarCandy, 10}, {.Chocolate, 10}, {.Cookie, 5}},
        money = 1400,

        messages = {
            {
                imageName = ImageNormal,
                message = "Good thing that there was a discount for\nHalloween themed factories at online factory shop",
            },

            {
                imageName = ImageThinkingEx,
                message = "Now that I think about it,\nI probably should just buy sweets online...",
            },

            {
                imageName = ImageNormal,
                message = "...",
            },
            {
                imageName = ImageNormal,
                message = "...\n...",
            },
            {
                imageName = ImageNormal,
                message = "...\n...\n...",
            },
            {
                imageName = ImageNormal,
                message = "AWAWAWAWA!\nLet's make some cookies",
            },
        }
    },

    // Level 4
    {
        name = "Phase Coffee",
        time = 10,
        items = {{.Candy, 10}, {.StarCandy, 10}, {.Chocolate, 10}, {.Cookie, 5}, {.PhaseCoffee, 5}},
        money = 2000,

        messages = {
            {
                imageName = ImageThinking,
                message = "Waait, with this I probably can make my own Coffee",
            },

            {
                imageName = ImageNormal,
                message = "Yeah, who needs Sakana, man",
            },
        }
    },

}

FinalMessage := [?]Message {
    {
        imageName = ImageNormal,
        message = "Now, I have enough sweets for the next 10 years,\nincluding all holidays and birthdays.",
    },

    {
        imageName = ImageNormal,
        message = "And also good enough factory template\nthat I can use *if* I ever need",
    },

    {
        imageName = ImageThinking,
        message = "But...",
    },

    {
        imageName = ImageNotLikeThis,
        message = "Maybe I can optimze it even more?!",
    },

    {
        imageName = "",
        message = "Thank you for playing!",
        isFinal = true,
    },
}