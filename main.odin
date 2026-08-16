package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:unicode/utf8"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

SCREEN_WIDTH :: 16 * 50
SCREEN_HEIGHT :: 9 * 50
SCREEN_MIN_WIDTH :: 16 * 25
SCREEN_MIN_HEIGHT :: 9 * 25
FONT_SIZE :: 24
vec2 :: [2]f32

COLOR_WHITE :: sdl.Color{255, 255, 255, 255}
COLOR_GRAY :: sdl.Color{128, 128, 128, 255}
COLOR_BLACK :: sdl.Color{0, 0, 0, 255}
BUFFER_PADDING :: 16
GUTTER_PADDING :: 64

running := true
sdl_window: ^sdl.Window
sdl_renderer: ^sdl.Renderer
font: ^ttf.Font
bg_color := sdl.Color{255, 255, 255, 255}
font_color := sdl.Color{0, 0, 0, 255}

sdl_init :: proc() {
    ok_init := sdl.Init({.VIDEO})
    sdl_window = sdl.CreateWindow("Editor", SCREEN_WIDTH, SCREEN_HEIGHT, {.RESIZABLE, .HIGH_PIXEL_DENSITY})
    sdl_renderer = sdl.CreateRenderer(sdl_window, nil)
    sdl.SetWindowMinimumSize(sdl_window, SCREEN_MIN_WIDTH, SCREEN_MIN_HEIGHT)

    assert(ok_init)
    assert(sdl_window != nil)
    assert(sdl_renderer != nil)
}

sdl_poll_events :: proc() {
    event: sdl.Event
    for sdl.PollEvent(&event) {
        #partial switch event.type {
        case .QUIT:
            running = false
        }
    }
}

draw_file_text :: proc(text: string, pos: vec2, color: sdl.Color) {
    ctext := strings.clone_to_cstring(text)
    text := ttf.RenderText_Blended(font, ctext, 0, color)
    texture: ^sdl.Texture
    if text != nil {
        texture = sdl.CreateTextureFromSurface(sdl_renderer, text)
        sdl.DestroySurface(text)
    }

    w, h: f32
    sdl.GetTextureSize(texture, &w, &h)
    dst := sdl.FRect {
        x = pos.x,
        y = pos.y,
        w = w,
        h = h,
    }

    sdl.SetRenderDrawColor(sdl_renderer, 255, 255, 255, 255)
    sdl.RenderTexture(sdl_renderer, texture, nil, &dst)
    sdl.DestroyTexture(texture)
    sdl.DestroySurface(text)
    delete(ctext)
}

main :: proc() {
    sdl_init()
    ttf_init := ttf.Init(); assert(ttf_init)
    font = ttf.OpenFont("GeistMono-Regular.ttf", FONT_SIZE)

    raw_file_data, load_ok := os.read_entire_file("test.txt", context.allocator)
    data := string(raw_file_data)
    lines := strings.split_lines(data)

    current_line := 0
    for (running) {
        sdl_poll_events()

        sdl.SetRenderDrawColor(sdl_renderer, 0, 0, 0, 255)
        sdl.RenderClear(sdl_renderer)

        for line, i in lines {
            draw_file_text(fmt.tprint(i), {16 + BUFFER_PADDING, f32(i * 32) + BUFFER_PADDING}, COLOR_WHITE)
            for char, j in line {
                char_str := utf8.runes_to_string({char}, context.temp_allocator)
                draw_file_text(
                    char_str,
                    {f32(j * 16) + BUFFER_PADDING + GUTTER_PADDING, f32(i * 32) + BUFFER_PADDING},
                    COLOR_WHITE,
                )
            }
        }

        sdl.RenderPresent(sdl_renderer)
    }
}
