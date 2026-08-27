package main

import "core:fmt"
import "core:math"
import "core:strings"
import "core:unicode/utf8"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

Buffer :: struct {
    data:            [dynamic]string,
    filename:        string,
    cursor:          Cursor,
    viewbounds:      vec2i,
    viewport_offset: vec2,
}

glyph_map_new :: proc(renderer: ^sdl.Renderer, font: ^ttf.Font) -> map[rune]^sdl.Texture {
    glyphs_to_generate := "1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ\"!£$%^&*()-_=+[]{};:'@#~,./<>?\\|"
    glyph_map := map[rune]^sdl.Texture{}

    for glyph in glyphs_to_generate {
        crune := fmt.ctprint(glyph)
        text := ttf.RenderText_Blended(font, crune, 0, COLOR_WHITE)
        texture := sdl.CreateTextureFromSurface(renderer, text)
        if texture == nil {
            fmt.println("Failed to create texture for glyph", glyph)
        }
        glyph_map[glyph] = texture
    }

    return glyph_map
}

glyph_map_destroy :: proc() {
    for key in editor.glyph_map {
        sdl.DestroyTexture(editor.glyph_map[key])
    }
    delete(editor.glyph_map)
}

buffer_insert :: proc(buffer: ^Buffer, char: string) {
    builder: strings.Builder
    current_line := buffer.data[int(buffer.cursor.pos.y)]

    strings.builder_init(&builder)
    strings.write_string(&builder, current_line[:int(buffer.cursor.pos.x)])
    strings.write_string(&builder, char)
    strings.write_string(&builder, current_line[int(buffer.cursor.pos.x):])

    buffer.data[int(buffer.cursor.pos.y)] = strings.to_string(builder)
    cursor_move(buffer, x = buffer.cursor.pos.x + 1)
    treesitter_update(buffer)
}

buffer_remove_at_cursor :: proc(buffer: ^Buffer) {
    if buffer.cursor.pos.x == 0 {return}

    builder: strings.Builder
    current_line := buffer.data[int(buffer.cursor.pos.y)]

    strings.builder_init(&builder)
    strings.write_string(&builder, current_line[:int(buffer.cursor.pos.x) - 1])
    strings.write_string(&builder, current_line[int(buffer.cursor.pos.x):])

    buffer.data[int(buffer.cursor.pos.y)] = strings.to_string(builder)
    cursor_move(buffer, x = buffer.cursor.pos.x - 1)
}

buffer_insert_newline :: proc(buffer: ^Buffer) {
    current_line := buffer.data[buffer.cursor.pos.y]
    text_before_cursor := current_line[:buffer.cursor.pos.x]
    text_beyond_cursor := current_line[buffer.cursor.pos.x:]

    buffer.data[buffer.cursor.pos.y] = text_before_cursor
    inject_at(&buffer.data, buffer.cursor.pos.y + 1, text_beyond_cursor)
    cursor_move(buffer, x = 0, y = buffer.cursor.pos.y + 1)
}

buffer_remove_line :: proc(buffer: ^Buffer) {
    ordered_remove(&buffer.data, buffer.cursor.pos.y)
    if buffer.cursor.pos.y != 0 {
        cursor_move(buffer, y = buffer.cursor.pos.y - 1)
    }
    cursor_move(buffer, x = i32(len(buffer.data[buffer.cursor.pos.y])))
}

buffer_remove_line_content :: proc(buffer: ^Buffer) {
    current_line := buffer.data[buffer.cursor.pos.y]
    text_beyond_cursor := current_line[buffer.cursor.pos.x:]
    buffer.data[buffer.cursor.pos.y] = text_beyond_cursor
    cursor_move(buffer, x = 0)
}

buffer_to_string :: proc(buffer: ^Buffer) -> string {
    builder: strings.Builder
    strings.builder_init(&builder)
    for line in buffer.data {
        strings.write_string(&builder, line)
        strings.write_string(&builder, "\n")
    }

    return strings.to_string(builder)
}

buffer_handle_input :: proc(buffer: ^Buffer, char: cstring) {
    buffer_insert(buffer, fmt.tprint(char))
    if char == fmt.ctprint('{') {
        buffer_insert(buffer, "}")
        treesitter_update(buffer)
        cursor_move(buffer, x = buffer.cursor.pos.x - 1)
    }
    if char == fmt.ctprint('(') {
        buffer_insert(buffer, ")")
        treesitter_update(buffer)
        cursor_move(buffer, x = buffer.cursor.pos.x - 1)
    }
    if char == fmt.ctprint('[') {
        buffer_insert(buffer, "]")
        treesitter_update(buffer)
        cursor_move(buffer, x = buffer.cursor.pos.x - 1)
    }
    treesitter_update(buffer)
}

buffer_draw_char :: proc(renderer: ^sdl.Renderer, buffer: ^Buffer, text: string, pos: vec2, color: sdl.Color) {
    for char in text {
        texture := editor.glyph_map[char]
        w, h: f32
        sdl.GetTextureSize(texture, &w, &h)
        dst := sdl.FRect {
            x = math.round(pos.x - buffer.viewport_offset.x),
            y = math.round(pos.y - buffer.viewport_offset.y),
            w = w,
            h = h,
        }
        sdl.SetTextureColorMod(texture, color.r, color.g, color.b)
        sdl.SetTextureAlphaMod(texture, color.a)
        sdl.RenderTexture(renderer, texture, nil, &dst)
    }
}

buffer_draw :: proc(window: ^sdl.Window, renderer: ^sdl.Renderer, buffer: ^Buffer) {
    if editor.treesitter.outdated {
        treesitter_generate_color_list()
        editor.treesitter.outdated = false
    }

    start_draw_line := i32(buffer.viewport_offset.y / get_line_height(window)) - 2
    end_draw_line :=
        (buffer.viewbounds.y) / i32(get_line_height(window)) + i32(buffer.viewport_offset.y / get_line_height(window))

    char_byte := 0
    for line, i in buffer.data {
        if i32(i) < start_draw_line || i32(i) > end_draw_line {
            char_byte += len(line) + 1
            continue
        }
        for char, j in line {
            char_str := utf8.runes_to_string({char}, context.temp_allocator)
            color := treesitter_get_char_color(char_byte, char, i)
            buffer_draw_char(
                renderer,
                buffer,
                char_str,
                {f32(j) * get_character_spacing(window) + BUFFER_PADDING, f32(i) * get_line_height(window) + BUFFER_PADDING},
                color,
            )
            char_byte += utf8.rune_size(char)
        }
        // increment for newline character
        char_byte += 1
    }
}
