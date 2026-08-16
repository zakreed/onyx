package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:unicode/utf8"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

DEFAULT_SCREEN_WIDTH :: 16 * 50
DEFAULT_SCREEN_HEIGHT :: 9 * 50
SCREEN_MIN_WIDTH :: 16 * 25
SCREEN_MIN_HEIGHT :: 9 * 25
FONT_SIZE :: 12
LINE_HEIGHT :: 16
CHARACTER_SPACING :: 8
SCROLL_SPEED :: 50
vec2 :: [2]f32

COLOR_WHITE :: sdl.Color{255, 255, 255, 255}
COLOR_GRAY :: sdl.Color{128, 128, 128, 255}
COLOR_BLACK :: sdl.Color{0, 0, 0, 255}
BUFFER_PADDING :: 16
GUTTER_PADDING :: 48

Globals :: struct {
    running:         bool,
    fps:             int,
    dt:              f64,
    glyph_map:       map[rune]^sdl.Texture,
    viewport_offset: vec2,
    cursor_pos:      vec2,
}

globals := Globals {
    running = true,
}
sdl_window: ^sdl.Window
sdl_renderer: ^sdl.Renderer
font: ^ttf.Font
bg_color := sdl.Color{255, 255, 255, 255}
font_color := sdl.Color{0, 0, 0, 255}
fps_timer_prev := sdl.GetPerformanceCounter()

calc_frame_info :: proc() {
    fps_timer_now := sdl.GetPerformanceCounter()
    globals.dt = (f64(fps_timer_now) - f64(fps_timer_prev)) / f64(sdl.GetPerformanceFrequency())
    globals.fps = int(1 / globals.dt)
    fps_timer_prev = fps_timer_now
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

sdl_poll_events :: proc() {
    event: sdl.Event
    for sdl.PollEvent(&event) {
        #partial switch event.type {
        case .QUIT:
            globals.running = false
        case .KEY_DOWN:
            #partial switch event.key.scancode {
            case .DOWN:
                globals.cursor_pos.y += LINE_HEIGHT
            case .UP:
                globals.cursor_pos.y -= LINE_HEIGHT
                if globals.cursor_pos.y < 0 {
                    globals.cursor_pos.y = 0
                }
            case .LEFT:
                globals.cursor_pos.x -= 8
                if globals.cursor_pos.x < 0 {
                    globals.cursor_pos.x = 0
                }
            case .RIGHT:
                globals.cursor_pos.x += 8
            }
        case .MOUSE_WHEEL:
            if event.wheel.y < 0 {
                globals.viewport_offset.y += SCROLL_SPEED
            } else if event.wheel.y > 0 {
                globals.viewport_offset.y -= SCROLL_SPEED
                if globals.viewport_offset.y < 0 {
                    globals.viewport_offset.y = 0
                }
            }
        }
    }
}

generate_glyph_map :: proc() -> map[rune]^sdl.Texture {
    glyphs_to_generate := "1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ\"£$%^&*()-_=+[]{};:'@#~,./<>?\\|¬"
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
            x = pos.x - globals.viewport_offset.x,
            y = pos.y - globals.viewport_offset.y,
            w = w,
            h = h,
        }
        sdl.RenderTexture(sdl_renderer, texture, nil, &dst)
    }
}

draw_file_text :: proc(file_data: string) {
    lines := strings.split_lines(file_data, context.temp_allocator)
    for line, i in lines {
        // draw_text(fmt.tprint(i), {CHARACTER_SPACING + BUFFER_PADDING, f32(i * LINE_HEIGHT) + BUFFER_PADDING}, COLOR_GRAY)
        for char, j in line {
            char_str := utf8.runes_to_string({char}, context.temp_allocator)
            draw_text(
                char_str,
                {f32(j * CHARACTER_SPACING) + BUFFER_PADDING, f32(i * LINE_HEIGHT) + BUFFER_PADDING},
                COLOR_WHITE,
            )
        }
    }
}

draw_cursor :: proc() {
    rect := sdl.FRect {
        x = globals.cursor_pos.x + BUFFER_PADDING,
        y = globals.cursor_pos.y + BUFFER_PADDING + 3,
        w = 1,
        h = FONT_SIZE,
    }
    sdl.RenderFillRect(sdl_renderer, &rect)
}

main :: proc() {
    sdl_init()
    ttf_init := ttf.Init(); assert(ttf_init)
    font = ttf.OpenFont("GeistMono-Regular.ttf", FONT_SIZE)
    globals.glyph_map = generate_glyph_map()

    raw_file_data, load_ok := os.read_entire_file("main.odin", context.allocator)
    data := string(raw_file_data)

    for (globals.running) {
        sdl_poll_events()

        sdl.SetRenderDrawColor(sdl_renderer, 0, 0, 0, 255)
        sdl.RenderClear(sdl_renderer)
        draw_file_text(data)

        sdl.SetRenderDrawColor(sdl_renderer, 255, 255, 255, 255)
        draw_cursor()

        sdl.RenderPresent(sdl_renderer)
        calc_frame_info()
        free_all(context.temp_allocator)
    }
}
