package main

import "core:fmt"
import sdl "vendor:sdl3"

CURSOR_BLINK_DURATION :: 0.5

Cursor :: struct {
    pos:            vec2i,
    desired_x:      i32,
    blink_timer:    f32,
    visible:        bool,
    has_just_moved: bool,
}

// TODO: Add some polish to this. You can also click on a line that is mostly offscreen and the camera doesn't move it fully into view.
// 		 Scrolling when the cursor is already out of the scroll margin causes issues too.
_cursor_move_cursor_on_screen :: proc(x, y: i32) {
    lines_on_screen := (globals.active_buffer_bounds.y - BUFFER_PADDING) / i32(get_line_height())
    cursor_screen_pos_y := globals.cursor.pos.y - (i32(globals.viewport_offset.y) / i32(get_line_height()))

    if y > 0 && cursor_screen_pos_y > lines_on_screen - SCROLL_MARGIN {
        globals.viewport_offset.y += get_line_height()
    }
    if y < 0 && cursor_screen_pos_y < SCROLL_MARGIN - BUFFER_PADDING / i32(get_line_height()) {
        globals.viewport_offset.y -= get_line_height()
    }
}

// move the cursor relative to its current position
cursor_move_rel :: proc(x: i32 = 0, y: i32 = 0) {
    globals.cursor.pos.x += x
    globals.cursor.pos.y += y
    globals.cursor.has_just_moved = true

    _cursor_move_cursor_on_screen(x, y)
}

// move the cursor to a new absolute position
cursor_move_abs :: proc(x: i32 = globals.cursor.pos.x, y: i32 = globals.cursor.pos.y) {
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
