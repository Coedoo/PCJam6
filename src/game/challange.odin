package game

import dm "../dmcore"
import "core:fmt"


Challange :: struct {
    name: string,
    time: f32,
    items: []ItemCount,

    messages: []Message,
}

Message :: struct {
    message: string,
    imageName: string,
}

Challanges := [?]Challange{
    {
        name = "Test 1",
        time = 10,
        items = {{.Candy, 5}},
        messages = {
            {
                imageName = "Jelly_VN_Normal.png",
                message = "Dang",
            },
            {
                imageName = "Jelly_VN_Thinking.png",
                message = "Fucking",
            },
            {
                imageName = "Jelly_VN_NotLikeThis.png",
                message = "DAMN IT",
            },
        }
        
    }
}