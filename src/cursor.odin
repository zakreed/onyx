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
_cursor_move_cursor_on_screen :: proc(window: ^sdl.Window, x, y: i32) {
    lines_on_screen := (editor.active_buffer_bounds.y - BUFFER_PADDING) / i32(get_line_height(window))
    cursor_screen_pos_y := editor.cursor.pos.y - (i32(editor.viewport_offset.y) / i32(get_line_height(window)))

    if y > 0 && cursor_screen_pos_y > lines_on_screen - SCROLL_MARGIN {
        editor.viewport_offset.y += get_line_height(window)
    }
    if y < 0 && cursor_screen_pos_y < SCROLL_MARGIN - BUFFER_PADDING / i32(get_line_height(window)) {
        editor.viewport_offset.y -= get_line_height(window)
    }
}

cursor_move :: proc(x: i32 = editor.cursor.pos.x, y: i32 = editor.cursor.pos.y) {
    prev_prev_pos := editor.cursor.prev_pos
    editor.cursor.prev_pos = editor.cursor.pos
    editor.cursor.pos.x = x
    editor.cursor.pos.y = y
    editor.cursor.has_just_moved = true
    move_delta := editor.cursor.pos - editor.cursor.prev_pos

    if move_delta.x < 0 {
        if editor.keyboard.holding_cmd {
            for char, i in editor.active_buffer[editor.cursor.pos.y][:editor.cursor.pos.x] {
                if char != ' ' {
                    editor.cursor.pos.x = i32(i)
                    editor.cursor.desired_x = editor.cursor.pos.x
                    return
                }
            }
            editor.cursor.pos.x = 0

        } else if editor.cursor.pos.x < 0 {
            if editor.cursor.pos.y - 1 >= 0 {
                editor.cursor.pos.x = i32(len(editor.active_buffer[int(editor.cursor.pos.y - 1)]))
                if editor.cursor.pos.y != 0 {
                    editor.cursor.pos.y -= 1
                }
            } else {
                editor.cursor.pos.x = 0
            }
        }
        editor.cursor.desired_x = editor.cursor.pos.x
    }
    if move_delta.x > 0 {
        if editor.keyboard.holding_cmd {
            editor.cursor.pos.x = i32(len(editor.active_buffer[editor.cursor.pos.y]))
        } else if editor.cursor.pos.x > i32(len(editor.active_buffer[int(editor.cursor.pos.y)])) {
            editor.cursor.pos.x = 0
            if editor.cursor.pos.y != i32(len(editor.active_buffer)) - 1 {
                editor.cursor.pos.y += 1
            }
        }
        editor.cursor.desired_x = editor.cursor.pos.x
    }
    if move_delta.y < 0 {
        if editor.cursor.pos.y < 0 {
            editor.cursor.pos.y = 0
        }
        if i32(len(editor.active_buffer[int(editor.cursor.pos.y)])) < editor.cursor.desired_x {
            editor.cursor.pos.x = i32(len(editor.active_buffer[int(editor.cursor.pos.y)]))
        } else {
            editor.cursor.pos.x = editor.cursor.desired_x
        }
    }
    if move_delta.y > 0 {
        if editor.cursor.pos.y > i32(len(editor.active_buffer)) - 1 {
            editor.cursor.pos.y = i32(len(editor.active_buffer)) - 1
        }
        if len(editor.active_buffer[int(editor.cursor.pos.y)]) < int(editor.cursor.desired_x) {
            editor.cursor.pos.x = i32(len(editor.active_buffer[int(editor.cursor.pos.y)]))
        } else {
            editor.cursor.pos.x = editor.cursor.desired_x
        }
    }

    // disallow prev_pos to be equal to the current pos as it will break a lot of the treesitter parsing
    if editor.cursor.pos == editor.cursor.prev_pos {
        editor.cursor.prev_pos = prev_prev_pos
    }
}

cursor_update :: proc() {
    if editor.cursor.has_just_moved {
        editor.cursor.visible = true
        editor.cursor.blink_timer = 0
        editor.cursor.has_just_moved = false
    }

    editor.cursor.blink_timer += editor.dt
    if editor.cursor.blink_timer > CURSOR_BLINK_DURATION {
        editor.cursor.visible = !editor.cursor.visible
        editor.cursor.blink_timer = 0
    }
}

cursor_draw :: proc(window: ^sdl.Window, renderer: ^sdl.Renderer) {
    if !editor.cursor.visible {return}

    rect := sdl.FRect {
        x = ((f32(editor.cursor.pos.x) * get_character_spacing(window)) + BUFFER_PADDING) - editor.viewport_offset.x,
        y = ((f32(editor.cursor.pos.y) * get_line_height(window)) + BUFFER_PADDING - 3) - editor.viewport_offset.y,
        w = 2,
        h = get_line_height(window),
    }
    sdl.RenderFillRect(renderer, &rect)
}
