package main

import sdl "vendor:sdl3"

screen_to_world_pos_f32 :: proc(window: ^sdl.Window, buffer: ^Buffer, pos: vec2) -> vec2 {
    return (pos * sdl.GetWindowPixelDensity(window)) + buffer.viewport_offset
}

screen_to_world_pos_i32 :: proc(window: ^sdl.Window, buffer: ^Buffer, pos: vec2i) -> vec2 {
    return (vec2{f32(pos.x), f32(pos.y)} * sdl.GetWindowPixelDensity(window)) + buffer.viewport_offset
}

world_to_screen_pos_f32 :: proc(window: ^sdl.Window, buffer: ^Buffer, pos: vec2) -> vec2 {
    return pos - buffer.viewport_offset
}

world_to_screen_pos_i32 :: proc(window: ^sdl.Window, buffer: ^Buffer, pos: vec2i) -> vec2 {
    return vec2{f32(pos.x), f32(pos.y)} - buffer.viewport_offset
}

screen_to_world_pos :: proc {
    screen_to_world_pos_f32,
    screen_to_world_pos_i32,
}

world_to_screen_pos :: proc {
    world_to_screen_pos_f32,
    world_to_screen_pos_i32,
}

point_in_rect_f32 :: proc(point: vec2i, rect: sdl.FRect) -> bool {
    if f32(point.x) >= rect.x && f32(point.x) <= rect.x + rect.w && f32(point.y) >= rect.y && f32(point.y) <= rect.y + rect.h {
        return true
    }
    return false
}

point_in_rect_i32 :: proc(point: vec2, rect: sdl.FRect) -> bool {
    if point.x >= rect.x && point.x <= rect.x + rect.w && point.y >= rect.y && point.y <= rect.y + rect.h {
        return true
    }
    return false
}

point_in_rect :: proc {
    point_in_rect_f32,
    point_in_rect_i32,
}
