package main

import "core:math"
import "core:strings"
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

filename_from_path :: proc(path: string) -> string {
    split_path := strings.split(path, "/")
    defer delete(split_path)
    filename: string
    if len(split_path) >= 1 {
        filename = split_path[len(split_path) - 1]
    } else {
        filename = path
    }

    return filename
}

number_of_digits_in_int :: proc(i: int) -> int {
    if math.abs(i) < 10 {return 1}
    if math.abs(i) < 100 {return 2}
    if math.abs(i) < 1_000 {return 3}
    if math.abs(i) < 10_000 {return 4}
    if math.abs(i) < 100_000 {return 5}
    if math.abs(i) < 1_000_000 {return 6}
    if math.abs(i) < 10_000_000 {return 7}
    if math.abs(i) < 100_000_000 {return 8}
    if math.abs(i) < 1_000_000_000 {return 9}
    return 10
}
