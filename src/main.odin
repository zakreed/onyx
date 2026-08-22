package main

import ts "../vendor/tree-sitter-odin"
import ts_odin "../vendor/tree-sitter-odin/parsers/odin"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import "core:unicode/utf8"
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

TreesitterCapture :: struct {
    start_byte: u32,
    end_byte:   u32,
    token:      string,
    type:       string,
}

Treesitter :: struct {
    source:         string,
    tree:           ts.Tree,
    root:           ts.Node,
    query:          ts.Query,
    cursor:         ts.Query_Cursor,
    outdated:       bool,
    data:           [dynamic]TreesitterCapture,
    char_type_list: [dynamic]string,
}

Globals :: struct {
    cursor:                     Cursor,
    running:                    bool,
    fps:                        int,
    dt:                         f32,
    glyph_map:                  map[rune]^sdl.Texture,
    camera_scroll_vel:          vec2,
    viewport_offset:            vec2,
    active_buffer:              [dynamic]string,
    active_buffer_bounds:       vec2i,
    treesitter:                 Treesitter,
    lines_to_redraw_this_frame: [dynamic]int,
    chars_per_line:             [dynamic]int,
}

globals := Globals {
    running = true,
}
keyboard: Keyboard
sdl_window: ^sdl.Window
sdl_renderer: ^sdl.Renderer
font: ^ttf.Font
bg_color := sdl.Color{255, 255, 255, 255}
font_color := sdl.Color{0, 0, 0, 255}
fps_timer_prev := sdl.GetPerformanceCounter()

calc_frame_info :: proc() {
    fps_timer_now := sdl.GetPerformanceCounter()
    globals.dt = (f32(fps_timer_now - fps_timer_prev)) / f32(sdl.GetPerformanceFrequency())
    globals.fps = int(1 / globals.dt)
    fps_timer_prev = fps_timer_now
}

load_buffer :: proc(filename: string) {
    raw_file_data, load_ok := os.read_entire_file(filename, context.allocator)
    data := string(raw_file_data)
    data_lines := strings.split_lines(data)
    for line, i in data_lines {
        append(&globals.active_buffer, line)
        append(&globals.lines_to_redraw_this_frame, i)
        append(&globals.chars_per_line, len(line))
    }
}

sdl_init :: proc() {
    ok_init := sdl.Init({.VIDEO})
    sdl_window = sdl.CreateWindow("Editor", DEFAULT_SCREEN_WIDTH, DEFAULT_SCREEN_HEIGHT, {.RESIZABLE, .HIGH_PIXEL_DENSITY})
    sdl_renderer = sdl.CreateRenderer(sdl_window, nil)
    sdl.SetWindowMinimumSize(sdl_window, SCREEN_MIN_WIDTH, SCREEN_MIN_HEIGHT)
    ok_vsync := sdl.SetRenderVSync(sdl_renderer, 1)

    assert(ok_init)
    assert(sdl_window != nil)
    assert(sdl_renderer != nil)
    assert(ok_vsync)
}

// TODO: Deduce language to use instead of hard coding it to odin
treesitter_init :: proc() {
    parser := ts.parser_new()
    odin_lang := ts_odin.tree_sitter_odin()
    ts.parser_set_language(parser, odin_lang)
    raw_file_data, load_ok := os.read_entire_file("src/main.odin", context.allocator)
    source := string(raw_file_data)
    globals.treesitter.source = source
    globals.treesitter.tree = ts.parser_parse_string(parser, source)
    globals.treesitter.root = ts.tree_root_node(globals.treesitter.tree)
    query, _, _ := ts.query_new(odin_lang, ts_odin.HIGHLIGHTS)
    globals.treesitter.query = query
    globals.treesitter.cursor = ts.query_cursor_new()
    globals.treesitter.outdated = true
}

camera_update :: proc() {
    globals.viewport_offset.x += globals.camera_scroll_vel.x * f32(globals.dt)
    globals.viewport_offset.y += globals.camera_scroll_vel.y * f32(globals.dt)

    if globals.viewport_offset.y < 0 {
        globals.viewport_offset.y = 0
    }
    if globals.viewport_offset.y > f32(len(globals.active_buffer)) * get_line_height() {
        globals.viewport_offset.y = f32(len(globals.active_buffer)) * get_line_height()
    }

    globals.camera_scroll_vel.x = math.lerp(globals.camera_scroll_vel.x, f32(0), f32(SCROLL_FRICTION) * f32(globals.dt))
    globals.camera_scroll_vel.y = math.lerp(globals.camera_scroll_vel.y, f32(0), f32(SCROLL_FRICTION) * f32(globals.dt))
}

sdl_poll_events :: proc() {
    event: sdl.Event
    for sdl.PollEvent(&event) {
        #partial switch event.type {
        case .QUIT:
            globals.running = false
        case .TEXT_INPUT:
            buffer_insert(fmt.tprint(event.text.text))
            if event.text.text == fmt.ctprint('{') {
                buffer_insert("}")
                cursor_move_rel(x = -1)
            }
            if event.text.text == fmt.ctprint('(') {
                buffer_insert(")")
                cursor_move_rel(x = -1)
            }
            if event.text.text == fmt.ctprint('[') {
                buffer_insert("]")
                cursor_move_rel(x = -1)
            }
        case .KEY_DOWN:
            #partial switch event.key.scancode {
            case .TAB:
                for i in 0 ..< TAB_WIDTH {
                    buffer_insert(" ")
                }
            case .LGUI:
                keyboard.holding_cmd = true
            case .BACKSPACE:
                if globals.cursor.pos == 0 {return}
                if globals.cursor.pos.x == 0 {
                    buffer_remove_line()
                } else {
                    if keyboard.holding_cmd {
                        buffer_remove_line_content()
                    } else {
                        buffer_remove_at_cursor()
                    }
                }
            case .RETURN:
                buffer_insert_newline()
                if globals.cursor.pos != 0 {
                    spaces_before_content_on_prev_line := 0
                    for char in globals.active_buffer[globals.cursor.pos.y - 1] {
                        if char == ' ' {
                            spaces_before_content_on_prev_line += 1
                        } else {
                            break
                        }
                    }
                    for i in 0 ..< spaces_before_content_on_prev_line {
                        buffer_insert(" ")
                    }
                }
            case .DOWN:
                cursor_move_rel(y = 1)
                if globals.cursor.pos.y > i32(len(globals.active_buffer)) - 1 {
                    cursor_move_abs(y = i32(len(globals.active_buffer)) - 1)
                }
                if len(globals.active_buffer[int(globals.cursor.pos.y)]) < int(globals.cursor.desired_x) {
                    cursor_move_abs(x = i32(len(globals.active_buffer[int(globals.cursor.pos.y)])))
                } else {
                    cursor_move_abs(x = globals.cursor.desired_x)
                }
            case .UP:
                cursor_move_rel(y = -1)
                if globals.cursor.pos.y < 0 {
                    cursor_move_abs(y = 0)
                }
                if i32(len(globals.active_buffer[int(globals.cursor.pos.y)])) < globals.cursor.desired_x {
                    cursor_move_abs(x = i32(len(globals.active_buffer[int(globals.cursor.pos.y)])))
                } else {
                    cursor_move_abs(x = globals.cursor.desired_x)
                }
            case .LEFT:
                cursor_move_rel(x = -1)

                if keyboard.holding_cmd {
                    for char, i in globals.active_buffer[globals.cursor.pos.y][:globals.cursor.pos.x + 1] {
                        if char != ' ' {
                            cursor_move_abs(x = i32(i))
                            globals.cursor.desired_x = globals.cursor.pos.x
                            return
                        }
                    }
                    cursor_move_abs(x = 0)

                } else if globals.cursor.pos.x < 0 {
                    if globals.cursor.pos.y - 1 >= 0 {
                        cursor_move_abs(x = i32(len(globals.active_buffer[int(globals.cursor.pos.y - 1)])))
                        if globals.cursor.pos.y != 0 {
                            cursor_move_rel(y = -1)
                        }
                    } else {
                        cursor_move_abs(x = 0)
                    }
                }
                globals.cursor.desired_x = globals.cursor.pos.x
            case .RIGHT:
                cursor_move_rel(x = 1)
                if keyboard.holding_cmd {
                    globals.cursor.pos.x = i32(len(globals.active_buffer[globals.cursor.pos.y]))
                } else if globals.cursor.pos.x > i32(len(globals.active_buffer[int(globals.cursor.pos.y)])) {
                    cursor_move_abs(x = 0)
                    if globals.cursor.pos.y != i32(len(globals.active_buffer)) - 1 {
                        cursor_move_rel(y = 1)
                    }
                }
                globals.cursor.desired_x = globals.cursor.pos.x
            }

        case .KEY_UP:
            #partial switch event.key.scancode {
            case .LGUI:
                keyboard.holding_cmd = false
            }
        case .MOUSE_WHEEL:
            if event.wheel.y != 0 {
                globals.camera_scroll_vel.y -= event.wheel.y * SCROLL_SPEED
            }
        case .MOUSE_BUTTON_DOWN:
            if event.button.button == 1 {
                pos := screen_to_world_pos(vec2{event.button.x, event.button.y})
                line_number := int(math.floor((pos.y - BUFFER_PADDING) / get_line_height()))
                col_number := int(math.floor(pos.x - BUFFER_PADDING) / get_character_spacing())

                if line_number >= len(globals.active_buffer) {
                    cursor_move_abs(y = i32(len(globals.active_buffer)) - 1)
                } else if line_number >= 0 {
                    cursor_move_abs(y = i32(line_number))
                }

                if col_number >= len(globals.active_buffer[globals.cursor.pos.y]) {
                    cursor_move_abs(x = i32(len(globals.active_buffer[globals.cursor.pos.y])))
                } else if col_number >= 0 {
                    cursor_move_abs(x = i32(col_number))
                }
            }
        }
    }
}

generate_glyph_map :: proc() -> map[rune]^sdl.Texture {
    glyphs_to_generate := "1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ\"£$%^&*()-_=+[]{};:'@#~,./<>?\\|"
    glyph_map := map[rune]^sdl.Texture{}

    for glyph in glyphs_to_generate {
        crune := fmt.ctprint(glyph)
        text := ttf.RenderText_Blended(font, crune, 0, COLOR_WHITE)
        texture := sdl.CreateTextureFromSurface(sdl_renderer, text)
        if texture == nil {
            fmt.println("Failed to create texture for glyph", glyph)
        }
        glyph_map[glyph] = texture
    }

    return glyph_map
}

destroy_glyph_map :: proc() {
    for key in globals.glyph_map {
        sdl.DestroyTexture(globals.glyph_map[key])
    }
    delete(globals.glyph_map)
}

draw_text :: proc(text: string, pos: vec2, color: sdl.Color) {
    for char in text {
        texture := globals.glyph_map[char]
        w, h: f32
        sdl.GetTextureSize(texture, &w, &h)
        dst := sdl.FRect {
            x = math.round(pos.x - globals.viewport_offset.x),
            y = math.round(pos.y - globals.viewport_offset.y),
            w = w,
            h = h,
        }
        sdl.SetTextureColorMod(texture, color.r, color.g, color.b)
        sdl.SetTextureAlphaMod(texture, color.a)
        sdl.RenderTexture(sdl_renderer, texture, nil, &dst)
    }
}

// draws a non monospace font word
draw_word :: proc(word: string, pos: vec2) {
    x_pos_count: f32 = 0

    for char in word {
        if char == ' ' {
            x_pos_count += get_font_size() / 2
            continue
        }

        texture := globals.glyph_map[char]
        w, h: f32
        sdl.GetTextureSize(texture, &w, &h)
        dst := sdl.FRect {
            x = pos.x + x_pos_count - globals.viewport_offset.x,
            y = pos.y - globals.viewport_offset.y,
            w = w,
            h = h,
        }
        sdl.RenderTexture(sdl_renderer, texture, nil, &dst)
        x_pos_count += w
    }
}

get_char_color :: proc(index: int, char: rune, line_num: int) -> sdl.Color {
    type: string
    for token in globals.treesitter.data {
        if index >= int(token.start_byte) && index <= int(token.end_byte) {
            type = token.type
        }
    }

    switch type {
    case "include":
        return sdl.Color{232, 59, 59, 255}
    case "variable":
    case "punctuation.delimiter":
    case "namespace":
        return sdl.Color{255, 255, 255, 255}
    case "string":
        return sdl.Color{30, 188, 115, 255}
    case "type":
        return sdl.Color{249, 194, 43, 255}
    case "operator":
        return sdl.Color{143, 211, 255, 255}
    case "function.call":
        return sdl.Color{77, 155, 230, 255}
    case "number":
        return sdl.Color{234, 173, 237, 255}
    case "punctuation.bracket":
        return sdl.Color{199, 220, 208, 255}
    case "comment":
    case "spell":
        return sdl.Color{98, 85, 101, 255}
    case "keyword.function":
    case "keyword.return":
    case "keyword.for":
        return sdl.Color{195, 36, 84, 255}
    }
    return sdl.Color{255, 255, 255, 255}
}

generate_treesitter_color_list :: proc() {
    ts.query_cursor_exec(globals.treesitter.cursor, globals.treesitter.query, globals.treesitter.root)
    for match, cap_idx in ts.query_cursor_next_capture(globals.treesitter.cursor) {
        cap := match.captures[cap_idx]
        if len(ts.query_predicates_for_pattern(globals.treesitter.query, u32(match.pattern_index))) > 0 {
            continue
        }

        append(
            &globals.treesitter.data,
            TreesitterCapture {
                start_byte = ts.node_start_byte(cap.node),
                end_byte = ts.node_end_byte(cap.node),
                token = ts.node_text(cap.node, globals.treesitter.source),
                type = ts.query_capture_name_for_id(globals.treesitter.query, cap.index),
            },
        )
    }
    for token_pair, i in globals.treesitter.data {
        for char in token_pair.token {
            append(&globals.treesitter.char_type_list, token_pair.type)
        }
    }
}

draw_buffer :: proc() {
    if globals.treesitter.outdated {
        generate_treesitter_color_list()
        globals.treesitter.outdated = false
    }

    start_draw_line := i32(globals.viewport_offset.y / get_line_height())
    end_draw_line :=
        (globals.active_buffer_bounds.y) / i32(get_line_height()) + i32(globals.viewport_offset.y / get_line_height())

    char_byte := 0
    for line, i in globals.active_buffer {
        if i32(i) < start_draw_line || i32(i) > end_draw_line {continue}
        for char, j in line {
            char_str := utf8.runes_to_string({char}, context.temp_allocator)
            color := get_char_color(char_byte, char, i)
            draw_text(
                char_str,
                {f32(j) * get_character_spacing() + BUFFER_PADDING, f32(i) * get_line_height() + BUFFER_PADDING},
                color,
            )

            char_byte += utf8.rune_size(char)
        }
        // increment for newline character
        char_byte += 1
    }
}

get_font_size :: proc() -> f32 {
    return FONT_SIZE * sdl.GetWindowPixelDensity(sdl_window)
}

get_line_height :: proc() -> f32 {
    return LINE_HEIGHT * sdl.GetWindowPixelDensity(sdl_window)
}

get_character_spacing :: proc() -> f32 {
    return CHARACTER_SPACING * sdl.GetWindowPixelDensity(sdl_window)
}

buffer_insert :: proc(char: string) {
    builder: strings.Builder
    current_line := globals.active_buffer[int(globals.cursor.pos.y)]

    strings.builder_init(&builder)
    strings.write_string(&builder, current_line[:int(globals.cursor.pos.x)])
    strings.write_string(&builder, char)
    strings.write_string(&builder, current_line[int(globals.cursor.pos.x):])

    globals.active_buffer[int(globals.cursor.pos.y)] = strings.to_string(builder)
    cursor_move_rel(x = 1)
}

buffer_remove_at_cursor :: proc() {
    if globals.cursor.pos.x == 0 {return}

    builder: strings.Builder
    current_line := globals.active_buffer[int(globals.cursor.pos.y)]

    strings.builder_init(&builder)
    strings.write_string(&builder, current_line[:int(globals.cursor.pos.x) - 1])
    strings.write_string(&builder, current_line[int(globals.cursor.pos.x):])

    globals.active_buffer[int(globals.cursor.pos.y)] = strings.to_string(builder)
    cursor_move_rel(x = -1)
}

buffer_insert_newline :: proc() {
    current_line := globals.active_buffer[globals.cursor.pos.y]
    text_before_cursor := current_line[:globals.cursor.pos.x]
    text_beyond_cursor := current_line[globals.cursor.pos.x:]

    globals.active_buffer[globals.cursor.pos.y] = text_before_cursor
    inject_at(&globals.active_buffer, globals.cursor.pos.y + 1, text_beyond_cursor)
    cursor_move_rel(y = 1)
    cursor_move_abs(x = 0)
}

buffer_remove_line :: proc() {
    ordered_remove(&globals.active_buffer, globals.cursor.pos.y)
    if globals.cursor.pos.y != 0 {
        globals.cursor.pos.y -= 1
    }
    cursor_move_abs(x = i32(len(globals.active_buffer[globals.cursor.pos.y])))
}

buffer_remove_line_content :: proc() {
    current_line := globals.active_buffer[globals.cursor.pos.y]
    text_beyond_cursor := current_line[globals.cursor.pos.x:]
    globals.active_buffer[globals.cursor.pos.y] = text_beyond_cursor
    cursor_move_abs(x = 0)
}

show_unsaved_changes_dialog :: proc() -> int {
    buttons := []sdl.MessageBoxButtonData {
        {flags = {.RETURNKEY_DEFAULT}, buttonID = 0, text = "Save"},
        {flags = nil, buttonID = 1, text = "Discard"},
        {flags = {.ESCAPEKEY_DEFAULT}, buttonID = 2, text = "Cancel"},
    }
    data := sdl.MessageBoxData {
        flags      = {.WARNING},
        window     = sdl_window,
        title      = "Unsaved changes",
        message    = "You have unsaved changes in this file. Do you want to save them?",
        numbuttons = i32(len(buttons)),
        buttons    = raw_data(buttons),
    }
    button_id: i32

    sdl.ShowMessageBox(data, &button_id)

    return int(button_id)
}

main :: proc() {
    sdl_init()
    ttf_init := ttf.Init(); assert(ttf_init)
    font = ttf.OpenFont("GeistMono-Regular.ttf", get_font_size())
    globals.glyph_map = generate_glyph_map()
    load_buffer("src/main.odin")
    ok := sdl.StartTextInput(sdl_window)
    if !ok {
        fmt.println("[ERROR]: Failed to start text input")
    }
    treesitter_init()

    for (globals.running) {
        sdl_poll_events()
        camera_update()
        cursor_update()
        sdl.GetWindowSize(sdl_window, &globals.active_buffer_bounds.x, &globals.active_buffer_bounds.y)

        sdl.SetRenderDrawColor(sdl_renderer, 0, 0, 0, 255)
        sdl.RenderClear(sdl_renderer)
        draw_buffer()

        sdl.SetRenderDrawColor(sdl_renderer, 255, 255, 255, 255)
        cursor_draw()

        sdl.SetWindowTitle(sdl_window, fmt.ctprintf("Editor - %vfps", globals.fps))
        fmt.println(globals.fps)
        sdl.RenderPresent(sdl_renderer)
        calc_frame_info()
        free_all(context.temp_allocator)
    }

    // unsaved_value := show_unsaved_changes_dialog()
}
