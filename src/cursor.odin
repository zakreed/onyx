package main

import sdl "vendor:sdl3"

CURSOR_BLINK_DURATION :: 0.5

Cursor :: struct {
    pos:            vec2i,
    desired_x:      int,
    blink_timer:    f32,
    visible:        bool,
    has_just_moved: bool,
}

// move the cursor relative to its current position
cursor_move_rel :: proc(x: int = 0, y: int = 0) {
    globals.cursor.pos.x += x
    globals.cursor.pos.y += y
    globals.cursor.has_just_moved = true
}

// move the cursor to a new absolute position
cursor_move_abs :: proc(x: int = globals.cursor.pos.x, y: int = globals.cursor.pos.y) {
    globals.cursor.pos.x = x
    globals.cursor.pos.y = y
    globals.cursor.has_just_moved = true
}

cursor_update :: proc() {
    if globals.cursor.has_just_moved {
        globals.cursor.visible = true
        globals.cursor.blink_timer = 0
        globals.cursor.has_just_moved = false
    }

    globals.cursor.blink_timer += globals.dt
    if globals.cursor.blink_timer > CURSOR_BLINK_DURATION {
        globals.cursor.visible = !globals.cursor.visible
        globals.cursor.blink_timer = 0
    }
}

cursor_draw :: proc() {
    if !globals.cursor.visible {return}

    rect := sdl.FRect {
        x = ((f32(globals.cursor.pos.x) * get_character_spacing()) + BUFFER_PADDING) - globals.viewport_offset.x,
        y = ((f32(globals.cursor.pos.y) * get_line_height()) + BUFFER_PADDING - 3) - globals.viewport_offset.y,
        w = 2,
        h = get_line_height(),
    }
    sdl.RenderFillRect(sdl_renderer, &rect)
}
