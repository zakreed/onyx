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
_cursor_move_cursor_on_screen :: proc(window: ^sdl.Window, buffer: ^Buffer, x, y: i32) {
    lines_on_screen := (buffer.viewbounds.h - BUFFER_PADDING) / get_line_height(window)
    cursor_screen_pos_y := buffer.cursor.pos.y - (i32(buffer.viewport_offset.y) / i32(get_line_height(window)))

    if y > 0 && f32(cursor_screen_pos_y) > lines_on_screen - SCROLL_MARGIN {
        buffer.viewport_offset.y += get_line_height(window)
    }
    if y < 0 && cursor_screen_pos_y < SCROLL_MARGIN - BUFFER_PADDING / i32(get_line_height(window)) {
        buffer.viewport_offset.y -= get_line_height(window)
    }
}

cursor_move :: proc(buffer: ^Buffer, x: Maybe(i32) = nil, y: Maybe(i32) = nil) {
    target_x := x.? or_else buffer.cursor.pos.x
    target_y := y.? or_else buffer.cursor.pos.y
    prev_prev_pos := buffer.cursor.prev_pos
    buffer.cursor.prev_pos = buffer.cursor.pos
    buffer.cursor.pos.x = target_x
    buffer.cursor.pos.y = target_y
    buffer.cursor.has_just_moved = true
    move_delta := buffer.cursor.pos - buffer.cursor.prev_pos

    if move_delta.x < 0 {
        if editor.keyboard.holding_cmd {
            for char, i in buffer.data[buffer.cursor.pos.y][:buffer.cursor.pos.x] {
                if char != ' ' {
                    buffer.cursor.pos.x = i32(i)
                    buffer.cursor.desired_x = buffer.cursor.pos.x
                    return
                }
            }
            buffer.cursor.pos.x = 0

        } else if buffer.cursor.pos.x < 0 {
            if buffer.cursor.pos.y - 1 >= 0 {
                buffer.cursor.pos.x = i32(len(buffer.data[int(buffer.cursor.pos.y - 1)]))
                if buffer.cursor.pos.y != 0 {
                    buffer.cursor.pos.y -= 1
                }
            } else {
                buffer.cursor.pos.x = 0
            }
        }
        buffer.cursor.desired_x = buffer.cursor.pos.x
    }
    if move_delta.x > 0 {
        if editor.keyboard.holding_cmd {
            buffer.cursor.pos.x = i32(len(buffer.data[buffer.cursor.pos.y]))
        } else if buffer.cursor.pos.x > i32(len(buffer.data[int(buffer.cursor.pos.y)])) {
            buffer.cursor.pos.x = 0
            if buffer.cursor.pos.y != i32(len(buffer.data)) - 1 {
                buffer.cursor.pos.y += 1
            }
        }
        buffer.cursor.desired_x = buffer.cursor.pos.x
    }
    if move_delta.y < 0 {
        if buffer.cursor.pos.y < 0 {
            buffer.cursor.pos.y = 0
        }
        if i32(len(buffer.data[int(buffer.cursor.pos.y)])) < buffer.cursor.desired_x {
            buffer.cursor.pos.x = i32(len(buffer.data[int(buffer.cursor.pos.y)]))
        } else {
            buffer.cursor.pos.x = buffer.cursor.desired_x
        }
    }
    if move_delta.y > 0 {
        if buffer.cursor.pos.y > i32(len(buffer.data)) - 1 {
            buffer.cursor.pos.y = i32(len(buffer.data)) - 1
        }
        if len(buffer.data[int(buffer.cursor.pos.y)]) < int(buffer.cursor.desired_x) {
            buffer.cursor.pos.x = i32(len(buffer.data[int(buffer.cursor.pos.y)]))
        } else {
            buffer.cursor.pos.x = buffer.cursor.desired_x
        }
    }

    // disallow prev_pos to be equal to the current pos as it will break a lot of the treesitter parsing
    if buffer.cursor.pos == buffer.cursor.prev_pos {
        buffer.cursor.prev_pos = prev_prev_pos
    }
}

cursor_update :: proc(buffer: ^Buffer) {
    if buffer.cursor.has_just_moved {
        buffer.cursor.visible = true
        buffer.cursor.blink_timer = 0
        buffer.cursor.has_just_moved = false
    }

    if buffer.cursor.blink_timer > CURSOR_BLINK_DURATION {
        buffer.cursor.visible = !buffer.cursor.visible
        buffer.cursor.blink_timer = 0
    }
}

cursor_draw :: proc(window: ^sdl.Window, renderer: ^sdl.Renderer, buffer: ^Buffer) {
    if !buffer.cursor.visible {return}

    rect := sdl.FRect {
        x = ((f32(buffer.cursor.pos.x) * get_character_spacing(window)) +
            BUFFER_PADDING) - buffer.viewport_offset.x + (editor.line_number_section_width + BUFFER_PADDING),
        y = ((f32(buffer.cursor.pos.y) * get_line_height(window)) + BUFFER_PADDING - 3) - buffer.viewport_offset.y,
        w = 2,
        h = get_line_height(window),
    }
    sdl.RenderFillRect(renderer, &rect)
}
