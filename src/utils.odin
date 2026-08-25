package main

import sdl "vendor:sdl3"

screen_to_world_pos_f32 :: proc(pos: vec2) -> vec2 {
    return (pos * sdl.GetWindowPixelDensity(sdl_window)) + globals.viewport_offset
}

screen_to_world_pos_i32 :: proc(pos: vec2i) -> vec2 {
    return (vec2{f32(pos.x), f32(pos.y)} * sdl.GetWindowPixelDensity(sdl_window)) + globals.viewport_offset
}

world_to_screen_pos_f32 :: proc(pos: vec2) -> vec2 {
    return pos - globals.viewport_offset
}

world_to_screen_pos_i32 :: proc(pos: vec2i) -> vec2 {
    return vec2{f32(pos.x), f32(pos.y)} - globals.viewport_offset
}

screen_to_world_pos :: proc {
    screen_to_world_pos_f32,
    screen_to_world_pos_i32,
}

world_to_screen_pos :: proc {
    world_to_screen_pos_f32,
    world_to_screen_pos_i32,
}
