package main

import "core:fmt"
import "core:math"
import "core:strings"
import "core:unicode/utf8"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

glyph_map_new :: proc() -> map[rune]^sdl.Texture {
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

glyph_map_destroy :: proc() {
    for key in globals.glyph_map {
        sdl.DestroyTexture(globals.glyph_map[key])
    }
    delete(globals.glyph_map)
}

buffer_insert :: proc(char: string) {
    builder: strings.Builder
    current_line := globals.active_buffer[int(globals.cursor.pos.y)]

    strings.builder_init(&builder)
    strings.write_string(&builder, current_line[:int(globals.cursor.pos.x)])
    strings.write_string(&builder, char)
    strings.write_string(&builder, current_line[int(globals.cursor.pos.x):])

    globals.active_buffer[int(globals.cursor.pos.y)] = strings.to_string(builder)
    cursor_move_right()
}

buffer_remove_at_cursor :: proc() {
    if globals.cursor.pos.x == 0 {return}

    builder: strings.Builder
    current_line := globals.active_buffer[int(globals.cursor.pos.y)]

    strings.builder_init(&builder)
    strings.write_string(&builder, current_line[:int(globals.cursor.pos.x) - 1])
    strings.write_string(&builder, current_line[int(globals.cursor.pos.x):])

    globals.active_buffer[int(globals.cursor.pos.y)] = strings.to_string(builder)
    cursor_move_left()
}

buffer_insert_newline :: proc() {
    current_line := globals.active_buffer[globals.cursor.pos.y]
    text_before_cursor := current_line[:globals.cursor.pos.x]
    text_beyond_cursor := current_line[globals.cursor.pos.x:]

    globals.active_buffer[globals.cursor.pos.y] = text_before_cursor
    inject_at(&globals.active_buffer, globals.cursor.pos.y + 1, text_beyond_cursor)
    cursor_move_down()
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

buffer_to_string :: proc() -> string {
    builder: strings.Builder
    strings.builder_init(&builder)
    for line in globals.active_buffer {
        strings.write_string(&builder, line)
        strings.write_string(&builder, "\n")
    }

    return strings.to_string(builder)
}

buffer_handle_input :: proc(char: cstring) {
    buffer_insert(fmt.tprint(char))
    if char == fmt.ctprint('{') {
        buffer_insert("}")
        cursor_move_left()
    }
    if char == fmt.ctprint('(') {
        buffer_insert(")")
        cursor_move_left()
    }
    if char == fmt.ctprint('[') {
        buffer_insert("]")
        cursor_move_left()
    }
    treesitter_update()
}

buffer_draw_char :: proc(text: string, pos: vec2, color: sdl.Color) {
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

buffer_draw :: proc() {
    if globals.treesitter.outdated {
        treesitter_generate_color_list()
        globals.treesitter.outdated = false
    }

    start_draw_line := i32(globals.viewport_offset.y / get_line_height()) - 2
    end_draw_line :=
        (globals.active_buffer_bounds.y) / i32(get_line_height()) + i32(globals.viewport_offset.y / get_line_height())

    char_byte := 0
    for line, i in globals.active_buffer {
        if i32(i) < start_draw_line || i32(i) > end_draw_line {
            char_byte += len(line) + 1
            continue
        }
        for char, j in line {
            char_str := utf8.runes_to_string({char}, context.temp_allocator)
            color := treesitter_get_char_color(char_byte, char, i)
            buffer_draw_char(
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
