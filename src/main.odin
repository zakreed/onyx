package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

DEFAULT_SCREEN_WIDTH :: 16 * 100
DEFAULT_SCREEN_HEIGHT :: 9 * 100
SCREEN_MIN_WIDTH :: 16 * 25
SCREEN_MIN_HEIGHT :: 9 * 25
FONT_SIZE :: 12
LINE_HEIGHT :: 20
CHARACTER_SPACING :: 7
TAB_WIDTH :: 4
SCROLL_SPEED :: 6
SCROLL_FRICTION :: 0.2
SCROLL_MARGIN :: 3
LOADED_FILE :: "src/main.odin"
vec2 :: [2]f32
vec2i :: [2]i32

COLOR_WHITE :: sdl.Color{255, 255, 255, 255}
COLOR_GRAY :: sdl.Color{128, 128, 128, 255}
COLOR_BLACK :: sdl.Color{0, 0, 0, 255}
BUFFER_PADDING :: 24
GUTTER_PADDING :: 48

Keyboard :: struct {
    holding_shift: bool,
    holding_ctrl:  bool,
    holding_alt:   bool,
    holding_cmd:   bool,
}

MouseCursors :: struct {
    default: ^sdl.Cursor,
    text:    ^sdl.Cursor,
}

Editor :: struct {
    running:                   bool,
    requested_exit:            bool,
    fps_timer_prev:            u64,
    fps:                       int,
    dt:                        f32,
    glyph_map:                 map[rune]^sdl.Texture,
    camera_scroll_vel:         vec2,
    treesitter:                Treesitter,
    current_theme:             Theme,
    keyboard:                  Keyboard,
    buffers:                   [dynamic]Buffer,
    active_buffer:             ^Buffer,
    mouse_pos:                 vec2i,
    mouse_cursors:             MouseCursors,
    line_number_section_width: f32,
}

SaveModalOption :: enum {
    SAVE,
    DISCARD,
    CANCEL,
}

editor := Editor {
    running       = true,
    current_theme = theme_gruvbox_dark,
}

calc_frame_info :: proc() {
    fps_timer_now := sdl.GetPerformanceCounter()
    editor.dt = (f32(fps_timer_now - editor.fps_timer_prev)) / f32(sdl.GetPerformanceFrequency())
    editor.fps = int(1 / editor.dt)
    editor.fps_timer_prev = fps_timer_now
}

sdl_init :: proc() -> (^sdl.Window, ^sdl.Renderer) {
    ok_init := sdl.Init({.VIDEO})
    sdl_window := sdl.CreateWindow("Editor", DEFAULT_SCREEN_WIDTH, DEFAULT_SCREEN_HEIGHT, {.RESIZABLE, .HIGH_PIXEL_DENSITY})
    sdl_renderer := sdl.CreateRenderer(sdl_window, nil)
    sdl.SetWindowMinimumSize(sdl_window, SCREEN_MIN_WIDTH, SCREEN_MIN_HEIGHT)
    ok_vsync := sdl.SetRenderVSync(sdl_renderer, 1)

    assert(ok_init)
    assert(sdl_window != nil)
    assert(sdl_renderer != nil)
    assert(ok_vsync)

    return sdl_window, sdl_renderer
}

camera_update :: proc(window: ^sdl.Window, buffer: ^Buffer) {
    buffer.viewport_offset.x += editor.camera_scroll_vel.x
    buffer.viewport_offset.y += editor.camera_scroll_vel.y

    if buffer.viewport_offset.y < 0 {
        buffer.viewport_offset.y = 0
    }
    if buffer.viewport_offset.y > f32(len(buffer.data)) * get_line_height(window) {
        buffer.viewport_offset.y = f32(len(buffer.data)) * get_line_height(window)
    }

    editor.camera_scroll_vel.x = math.lerp(editor.camera_scroll_vel.x, f32(0), f32(SCROLL_FRICTION))
    editor.camera_scroll_vel.y = math.lerp(editor.camera_scroll_vel.y, f32(0), f32(SCROLL_FRICTION))
    if math.abs(editor.camera_scroll_vel.x) < 0.001 {editor.camera_scroll_vel.x = 0}
    if math.abs(editor.camera_scroll_vel.y) < 0.001 {editor.camera_scroll_vel.y = 0}
}

sdl_handle_event :: proc(window: ^sdl.Window, buffer: ^Buffer, event: sdl.Event) {
    #partial switch event.type {
    case .QUIT:
        editor.requested_exit = true
    case .TEXT_INPUT:
        buffer_handle_input(buffer, event.text.text)
    case .KEY_DOWN:
        editor.treesitter.outdated = true
        #partial switch event.key.scancode {
        case .TAB:
            for i in 0 ..< TAB_WIDTH {
                buffer_insert(buffer, " ")
            }
        case .LGUI:
            editor.keyboard.holding_cmd = true
        case .BACKSPACE:
            if buffer.cursor.pos == 0 {return}
            if buffer.cursor.pos.x == 0 {
                buffer_remove_line(buffer)
            } else {
                if editor.keyboard.holding_cmd {
                    buffer_remove_line_content(buffer)
                } else {
                    buffer_remove_at_cursor(buffer)
                }
            }
            treesitter_update(buffer)
        case .RETURN:
            buffer_insert_newline(buffer)
            if buffer.cursor.pos != 0 {
                spaces_before_content_on_prev_line := 0
                for char in buffer.data[buffer.cursor.pos.y - 1] {
                    if char == ' ' {
                        spaces_before_content_on_prev_line += 1
                    } else {
                        break
                    }
                }
                for i in 0 ..< spaces_before_content_on_prev_line {
                    buffer_insert(buffer, " ")
                }
            }
            treesitter_update(buffer)
        case .DOWN:
            cursor_move(buffer, y = buffer.cursor.pos.y + 1)
        case .UP:
            cursor_move(buffer, y = buffer.cursor.pos.y - 1)
        case .LEFT:
            cursor_move(buffer, x = buffer.cursor.pos.x - 1)
        case .RIGHT:
            cursor_move(buffer, x = buffer.cursor.pos.x + 1)

        case .O:
            if editor.keyboard.holding_cmd {
                show_open_file_dialog(window)
            }
        case .S:
            if editor.keyboard.holding_cmd {
                buffer_save(editor.active_buffer)
            }
        }

    case .KEY_UP:
        #partial switch event.key.scancode {
        case .LGUI:
            editor.keyboard.holding_cmd = false
        }
    case .MOUSE_WHEEL:
        if event.wheel.y != 0 {
            editor.camera_scroll_vel.y -= event.wheel.y * SCROLL_SPEED
        }
    case .MOUSE_BUTTON_DOWN:
        if event.button.button == 1 {
            pos := screen_to_world_pos(window, buffer, vec2{event.button.x, event.button.y})
            line_number := int(math.floor((pos.y - BUFFER_PADDING) / get_line_height(window)))
            col_number := int(
                math.floor(pos.x - BUFFER_PADDING * 2 - editor.line_number_section_width) / get_character_spacing(window),
            )

            if line_number >= len(buffer.data) {
                cursor_move(buffer, y = i32(len(buffer.data)) - 1)
            } else if line_number >= 0 {
                cursor_move(buffer, y = i32(line_number))
            }

            if col_number >= len(buffer.data[buffer.cursor.pos.y]) {
                cursor_move(buffer, x = i32(len(buffer.data[buffer.cursor.pos.y])))
            } else if col_number >= 0 {
                cursor_move(buffer, x = i32(col_number))
            }
        }
    }
}

sdl_poll_events :: proc(window: ^sdl.Window, buffer: ^Buffer) {
    is_animating := editor.camera_scroll_vel.x != 0 || editor.camera_scroll_vel.y != 0
    event: sdl.Event
    got_event: bool
    if is_animating {
        got_event = sdl.WaitEventTimeout(&event, 0)
    } else {
        got_event = sdl.WaitEvent(&event)
    }

    for got_event {
        sdl_handle_event(window, buffer, event)
        got_event = sdl.PollEvent(&event)
    }
}

// draws a non monospace font word
draw_word :: proc(window: ^sdl.Window, renderer: ^sdl.Renderer, buffer: ^Buffer, word: string, pos: vec2) {
    x_pos_count: f32 = 0

    for char in word {
        if char == ' ' {
            x_pos_count += get_font_size(window) / 2
            continue
        }

        texture := editor.glyph_map[char]
        w, h: f32
        sdl.GetTextureSize(texture, &w, &h)
        dst := sdl.FRect {
            x = pos.x + x_pos_count - buffer.viewport_offset.x,
            y = pos.y - buffer.viewport_offset.y,
            w = w,
            h = h,
        }
        sdl.RenderTexture(renderer, texture, nil, &dst)
        x_pos_count += w
    }
}

get_font_size :: proc(window: ^sdl.Window) -> f32 {
    return FONT_SIZE * sdl.GetWindowPixelDensity(window)
}

get_line_height :: proc(window: ^sdl.Window) -> f32 {
    return LINE_HEIGHT * sdl.GetWindowPixelDensity(window)
}

get_character_spacing :: proc(window: ^sdl.Window) -> f32 {
    return CHARACTER_SPACING * sdl.GetWindowPixelDensity(window)
}

show_unsaved_changes_dialog :: proc(window: ^sdl.Window) -> SaveModalOption {
    buttons := []sdl.MessageBoxButtonData {
        {flags = {.RETURNKEY_DEFAULT}, buttonID = i32(SaveModalOption.SAVE), text = "Save"},
        {flags = nil, buttonID = i32(SaveModalOption.DISCARD), text = "Discard"},
        {flags = {.ESCAPEKEY_DEFAULT}, buttonID = i32(SaveModalOption.CANCEL), text = "Cancel"},
    }
    data := sdl.MessageBoxData {
        flags      = {.WARNING},
        window     = window,
        title      = "Unsaved changes",
        message    = "You have unsaved changes in this file. Do you want to save them?",
        numbuttons = i32(len(buttons)),
        buttons    = raw_data(buttons),
    }
    button_id: i32

    sdl.ShowMessageBox(data, &button_id)

    return SaveModalOption(button_id)
}

open_file_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
    context = runtime.default_context()
    if filelist != nil {
        file_path := string(filelist[0])
        buffer_load(file_path)
    }
}

show_open_file_dialog :: proc(window: ^sdl.Window) {
    sdl.ShowOpenFileDialog(open_file_callback, nil, window, nil, 0, "", false)
}

mouse_cursors_init :: proc() {
    default := sdl.SystemCursor.DEFAULT
    text := sdl.SystemCursor.TEXT
    editor.mouse_cursors.default = sdl.CreateSystemCursor(default)
    editor.mouse_cursors.text = sdl.CreateSystemCursor(text)
    ok := sdl.SetCursor(editor.mouse_cursors.default)
}

mouse_cursors_set :: proc(c: ^sdl.Cursor) {
    cursor_ok := sdl.SetCursor(c)
    if !cursor_ok {
        fmt.println("[ERROR]: Failed to set mouse cursor")
    }
}

mouse_cursors_update :: proc() {
    mouse_x, mouse_y: f32
    mouse_pos := sdl.GetGlobalMouseState(&mouse_x, &mouse_y)
    editor.mouse_pos.x = i32(mouse_x)
    editor.mouse_pos.y = i32(mouse_y)
    if point_in_rect(editor.mouse_pos, editor.active_buffer.viewbounds) {
        mouse_cursors_set(editor.mouse_cursors.text)
    }
}

main :: proc() {
    sdl_window, sdl_renderer := sdl_init()
    active_buffers := make([dynamic]Buffer); defer delete(active_buffers)
    ttf_init := ttf.Init(); assert(ttf_init)
    font := ttf.OpenFont("GeistMono-Medium.ttf", get_font_size(sdl_window))
    keyboard: Keyboard
    editor.glyph_map = glyph_map_new(sdl_renderer, font)
    ok := sdl.StartTextInput(sdl_window)
    if !ok {
        fmt.println("[ERROR]: Failed to start text input")
    }
    treesitter_init()
    mouse_cursors_init()
    buffer_load(LOADED_FILE)
    sdl.SetWindowTitle(sdl_window, fmt.ctprint(filename_from_path(LOADED_FILE)))

    for (editor.running) {
        calc_frame_info()
        sdl_poll_events(sdl_window, editor.active_buffer)
        camera_update(sdl_window, editor.active_buffer)
        cursor_update(editor.active_buffer)
        buffer_update(sdl_window, editor.active_buffer)
        mouse_cursors_update()

        bg_color := hex_to_sdl_color(editor.current_theme._bg)
        sdl.SetRenderDrawColor(sdl_renderer, bg_color.r, bg_color.g, bg_color.b, bg_color.a)
        sdl.RenderClear(sdl_renderer)
        buffer_draw(sdl_window, sdl_renderer, editor.active_buffer)

        cursor_color := hex_to_sdl_color(editor.current_theme._cursor)
        sdl.SetRenderDrawColor(sdl_renderer, cursor_color.r, cursor_color.g, cursor_color.b, cursor_color.a)
        cursor_draw(sdl_window, sdl_renderer, editor.active_buffer)

        sdl.RenderPresent(sdl_renderer)

        if editor.requested_exit {
            if editor.active_buffer.has_unsaved_changes {
                save_modal_option := show_unsaved_changes_dialog(sdl_window)
                #partial switch save_modal_option {
                case .SAVE:
                    buffer_save(editor.active_buffer)
                    editor.running = false
                case .DISCARD:
                    editor.running = false
                case .CANCEL:
                    editor.requested_exit = false
                }
            } else {
                editor.running = false
            }
        }

        free_all(context.temp_allocator)
    }
}
