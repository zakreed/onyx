package main

import "core:fmt"
import sdl "vendor:sdl3"

CURSOR_BLINK_DURATION :: 0.5

Cursor :: struct {
    pos:            vec2i,
    prev_pos:       vec2i,
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

// move the cursor to a new absolute position
cursor_move_abs :: proc(x: i32 = globals.cursor.pos.x, y: i32 = globals.cursor.pos.y) {
    globals.cursor.pos.x = x
    globals.cursor.pos.y = y
    globals.cursor.has_just_moved = true
}

cursor_move_down :: proc() {
    globals.cursor.prev_pos.y = globals.cursor.pos.y
    globals.cursor.pos.y += 1
    globals.cursor.has_just_moved = true

    if globals.cursor.pos.y > i32(len(globals.active_buffer)) - 1 {
        globals.cursor.pos.y = i32(len(globals.active_buffer)) - 1
    }
    if len(globals.active_buffer[int(globals.cursor.pos.y)]) < int(globals.cursor.desired_x) {
        globals.cursor.pos.x = i32(len(globals.active_buffer[int(globals.cursor.pos.y)]))
    } else {
        globals.cursor.pos.x = globals.cursor.desired_x
    }
}

cursor_move_up :: proc() {
    globals.cursor.prev_pos.y = globals.cursor.pos.y
    globals.cursor.pos.y -= 1
    globals.cursor.has_just_moved = true

    if globals.cursor.pos.y < 0 {
        globals.cursor.pos.y = 0
    }
    if i32(len(globals.active_buffer[int(globals.cursor.pos.y)])) < globals.cursor.desired_x {
        globals.cursor.pos.x = i32(len(globals.active_buffer[int(globals.cursor.pos.y)]))
    } else {
        globals.cursor.pos.x = globals.cursor.desired_x
    }
}

cursor_move_left :: proc() {
    globals.cursor.prev_pos.x = globals.cursor.pos.x
    globals.cursor.pos.x -= 1
    globals.cursor.has_just_moved = true

    if keyboard.holding_cmd {
        for char, i in globals.active_buffer[globals.cursor.pos.y][:globals.cursor.pos.x + 1] {
            if char != ' ' {
                globals.cursor.pos.x = i32(i)
                globals.cursor.desired_x = globals.cursor.pos.x
                return
            }
        }
        globals.cursor.pos.x = 0

    } else if globals.cursor.pos.x < 0 {
        if globals.cursor.pos.y - 1 >= 0 {
            globals.cursor.pos.x = i32(len(globals.active_buffer[int(globals.cursor.pos.y - 1)]))
            if globals.cursor.pos.y != 0 {
                globals.cursor.pos.y = -1
            }
        } else {
            globals.cursor.pos.x = 0
        }
    }
    globals.cursor.desired_x = globals.cursor.pos.x
}

cursor_move_right :: proc() {
    globals.cursor.prev_pos.x = globals.cursor.pos.x
    globals.cursor.pos.x += 1
    globals.cursor.has_just_moved = true

    if keyboard.holding_cmd {
        globals.cursor.pos.x = i32(len(globals.active_buffer[globals.cursor.pos.y]))
    } else if globals.cursor.pos.x > i32(len(globals.active_buffer[int(globals.cursor.pos.y)])) {
        globals.cursor.pos.x = 0
        if globals.cursor.pos.y != i32(len(globals.active_buffer)) - 1 {
            globals.cursor.pos.y += 1
        }
    }
    globals.cursor.desired_x = globals.cursor.pos.x
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
