package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

DEFAULT_SCREEN_WIDTH :: 16 * 100
DEFAULT_SCREEN_HEIGHT :: 9 * 100
SCREEN_MIN_WIDTH :: 16 * 25
SCREEN_MIN_HEIGHT :: 9 * 25
FONT_SIZE :: 12
LINE_HEIGHT :: 20
CHARACTER_SPACING :: 8
TAB_WIDTH :: 4
SCROLL_SPEED :: 200
SCROLL_FRICTION :: 10
SCROLL_MARGIN :: 3
LOADED_FILE :: "src/main.odin"
vec2 :: [2]f32
vec2i :: [2]i32

COLOR_WHITE :: sdl.Color{255, 255, 255, 255}
COLOR_GRAY :: sdl.Color{128, 128, 128, 255}
COLOR_BLACK :: sdl.Color{0, 0, 0, 255}
BUFFER_PADDING :: 32
GUTTER_PADDING :: 48

Keyboard :: struct {
    holding_shift: bool,
    holding_ctrl:  bool,
    holding_alt:   bool,
    holding_cmd:   bool,
}

Editor :: struct {
    running:           bool,
    fps_timer_prev:    u64,
    fps:               int,
    dt:                f32,
    glyph_map:         map[rune]^sdl.Texture,
    camera_scroll_vel: vec2,
    treesitter:        Treesitter,
    current_theme:     Theme,
    keyboard:          Keyboard,
    buffers:           [dynamic]Buffer,
    active_buffer:     ^Buffer,
}

editor := Editor {
    running        = true,
    current_theme  = theme_gruvbox_dark,
    fps_timer_prev = sdl.GetPerformanceCounter(),
}

calc_frame_info :: proc() {
    fps_timer_now := sdl.GetPerformanceCounter()
    editor.dt = (f32(fps_timer_now - editor.fps_timer_prev)) / f32(sdl.GetPerformanceFrequency())
    editor.fps = int(1 / editor.dt)
    editor.fps_timer_prev = fps_timer_now
}

load_buffer :: proc(filename: string) {
    raw_file_data, load_ok := os.read_entire_file(filename, context.allocator)
    data := string(raw_file_data)
    data_lines := strings.split_lines(data)
    append(&editor.buffers, Buffer{})
    editor.active_buffer = &editor.buffers[len(editor.buffers) - 1]
    for line, i in data_lines {
        append(&editor.active_buffer.data, line)
    }
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
    buffer.viewport_offset.x += editor.camera_scroll_vel.x * f32(editor.dt)
    buffer.viewport_offset.y += editor.camera_scroll_vel.y * f32(editor.dt)

    if buffer.viewport_offset.y < 0 {
        buffer.viewport_offset.y = 0
    }
    if buffer.viewport_offset.y > f32(len(buffer.data)) * get_line_height(window) {
        buffer.viewport_offset.y = f32(len(buffer.data)) * get_line_height(window)
    }

    editor.camera_scroll_vel.x = math.lerp(editor.camera_scroll_vel.x, f32(0), f32(SCROLL_FRICTION) * f32(editor.dt))
    editor.camera_scroll_vel.y = math.lerp(editor.camera_scroll_vel.y, f32(0), f32(SCROLL_FRICTION) * f32(editor.dt))
}

sdl_poll_events :: proc(window: ^sdl.Window, buffer: ^Buffer) {
    event: sdl.Event
    for sdl.PollEvent(&event) {
        #partial switch event.type {
        case .QUIT:
            editor.running = false
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
                    fmt.println("hello")
                    show_open_file_dialog(window)
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
                col_number := int(math.floor(pos.x - BUFFER_PADDING) / get_character_spacing(window))

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

show_unsaved_changes_dialog :: proc(window: ^sdl.Window) -> int {
    buttons := []sdl.MessageBoxButtonData {
        {flags = {.RETURNKEY_DEFAULT}, buttonID = 0, text = "Save"},
        {flags = nil, buttonID = 1, text = "Discard"},
        {flags = {.ESCAPEKEY_DEFAULT}, buttonID = 2, text = "Cancel"},
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

    return int(button_id)
}

open_file_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
    context = runtime.default_context()
    if filelist != nil {
        file_path := string(filelist[0])
        load_buffer(file_path)
    }
}

show_open_file_dialog :: proc(window: ^sdl.Window) {
    sdl.ShowOpenFileDialog(open_file_callback, nil, window, nil, 0, "", false)
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
    load_buffer(LOADED_FILE)

    for (editor.running) {
        sdl_poll_events(sdl_window, editor.active_buffer)
        camera_update(sdl_window, editor.active_buffer)
        cursor_update(editor.active_buffer)
        sdl.GetWindowSizeInPixels(sdl_window, &editor.active_buffer.viewbounds.x, &editor.active_buffer.viewbounds.y)

        bg_color := hex_to_sdl_color(editor.current_theme._bg)
        sdl.SetRenderDrawColor(sdl_renderer, bg_color.r, bg_color.g, bg_color.b, bg_color.a)
        sdl.RenderClear(sdl_renderer)
        buffer_draw(sdl_window, sdl_renderer, editor.active_buffer)

        cursor_color := hex_to_sdl_color(editor.current_theme._cursor)
        sdl.SetRenderDrawColor(sdl_renderer, cursor_color.r, cursor_color.g, cursor_color.b, cursor_color.a)
        cursor_draw(sdl_window, sdl_renderer, editor.active_buffer)

        sdl.SetWindowTitle(sdl_window, fmt.ctprintf("Editor - %vfps", editor.fps))
        sdl.RenderPresent(sdl_renderer)
        calc_frame_info()
        free_all(context.temp_allocator)
    }

    // unsaved_value := show_unsaved_changes_dialog()
}
