package main

import sdl "vendor:sdl3"

screen_to_world_pos_f32 :: proc(window: ^sdl.Window, pos: vec2) -> vec2 {
    return (pos * sdl.GetWindowPixelDensity(window)) + editor.viewport_offset
}

screen_to_world_pos_i32 :: proc(window: ^sdl.Window, pos: vec2i) -> vec2 {
    return (vec2{f32(pos.x), f32(pos.y)} * sdl.GetWindowPixelDensity(window)) + editor.viewport_offset
}

world_to_screen_pos_f32 :: proc(window: ^sdl.Window, pos: vec2) -> vec2 {
    return pos - editor.viewport_offset
}

world_to_screen_pos_i32 :: proc(window: ^sdl.Window, pos: vec2i) -> vec2 {
    return vec2{f32(pos.x), f32(pos.y)} - editor.viewport_offset
}

screen_to_world_pos :: proc {
    screen_to_world_pos_f32,
    screen_to_world_pos_i32,
}

world_to_screen_pos :: proc {
    world_to_screen_pos_f32,
    world_to_screen_pos_i32,
}
