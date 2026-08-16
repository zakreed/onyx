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
FONT_SIZE :: 12
LINE_HEIGHT :: 16
CHARACTER_SPACING :: 8
vec2 :: [2]f32

COLOR_WHITE :: sdl.Color{255, 255, 255, 255}
COLOR_GRAY :: sdl.Color{128, 128, 128, 255}
COLOR_BLACK :: sdl.Color{0, 0, 0, 255}
BUFFER_PADDING :: 16
GUTTER_PADDING :: 48

Globals :: struct {
    running: bool,
    fps:     int,
    dt:      f64,
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
    sdl_window = sdl.CreateWindow("Editor", SCREEN_WIDTH, SCREEN_HEIGHT, {.RESIZABLE, .HIGH_PIXEL_DENSITY})
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
    delete(ctext)
}

main :: proc() {
    sdl_init()
    ttf_init := ttf.Init(); assert(ttf_init)
    font = ttf.OpenFont("GeistMono-Regular.ttf", FONT_SIZE)

    raw_file_data, load_ok := os.read_entire_file("main.odin", context.allocator)
    data := string(raw_file_data)
    lines := strings.split_lines(data)

    for (globals.running) {
        sdl_poll_events()

        sdl.SetRenderDrawColor(sdl_renderer, 0, 0, 0, 255)
        sdl.RenderClear(sdl_renderer)

        // for line, i in lines {
        //     draw_file_text(
        //         fmt.tprint(i),
        //         {CHARACTER_SPACING + BUFFER_PADDING, f32(i * LINE_HEIGHT) + BUFFER_PADDING},
        //         COLOR_GRAY,
        //     )
        //     for char, j in line {
        //         char_str := utf8.runes_to_string({char}, context.temp_allocator)
        //         draw_file_text(
        //             char_str,
        //             {f32(j * CHARACTER_SPACING) + BUFFER_PADDING + GUTTER_PADDING, f32(i * LINE_HEIGHT) + BUFFER_PADDING},
        //             COLOR_WHITE,
        //         )
        //     }
        // }

        calc_frame_info()
        sdl.RenderPresent(sdl_renderer)
    }
}
