package main

import "core:fmt"
import "core:strings"
import sdl "vendor:sdl3"

Theme :: struct {
    _default:               string,
    _bg:                    string,
    _cursor:                string,
    _cursor_highlight:      string,
    _line_numbers:          string,
    _pre_proc:              string,
    _include:               string,
    _keyword:               string,
    _keyword_function:      string,
    _keyword_return:        string,
    _storageclass:          string,
    _conditional:           string,
    _conditional_ternary:   string,
    _repeat:                string,
    _variable:              string,
    _namespace:             string,
    _constant:              string,
    _parameter:             string,
    _type:                  string,
    _function:              string,
    _function_call:         string,
    _type_builtin:          string,
    _field:                 string,
    _function_macro:        string,
    _attribute:             string,
    _number:                string,
    _float:                 string,
    _string:                string,
    _character:             string,
    _string_escape:         string,
    _boolean:               string,
    _constant_builtin:      string,
    _variable_builtin:      string,
    _operator:              string,
    _keyword_operator:      string,
    _punctuation_bracket:   string,
    _punctuation_delimiter: string,
    _punctuation_special:   string,
    _comment:               string,
    _spell:                 string,
    _error:                 string,
}

theme_gruvbox_dark := Theme {
    _default               = "EBDBB2",
    _bg                    = "1D2021",
    _cursor                = "83A598",
    _cursor_highlight      = "282828",
    _line_numbers          = "665C54",
    _pre_proc              = "EBDBB2",
    _include               = "FB4934",
    _keyword               = "FB4934",
    _keyword_function      = "FB4934",
    _keyword_return        = "FB4934",
    _storageclass          = "FB4934",
    _conditional           = "FB4934",
    _conditional_ternary   = "FB4934",
    _repeat                = "FB4934",
    _variable              = "EBDBB2",
    _namespace             = "EBDBB2",
    _constant              = "EBDBB2",
    _parameter             = "EBDBB2",
    _type                  = "FABD2F",
    _function              = "B8BB26",
    _function_call         = "B8BB26",
    _type_builtin          = "FABD2F",
    _field                 = "EBDBB2",
    _function_macro        = "EBDBB2",
    _attribute             = "EBDBB2",
    _number                = "D3869B",
    _float                 = "D3869B",
    _string                = "B8BB26",
    _character             = "D3869B",
    _string_escape         = "B8BB26",
    _boolean               = "D3869B",
    _constant_builtin      = "FABD2F",
    _variable_builtin      = "EBDBB2",
    _operator              = "83A598",
    _keyword_operator      = "EBDBB2",
    _punctuation_bracket   = "928374",
    _punctuation_delimiter = "EBDBB2",
    _punctuation_special   = "928374",
    _comment               = "7C6F64",
    _spell                 = "7C6F64",
    _error                 = "FB4934",
}

theme_github_light := Theme {
    _default               = "000000",
    _bg                    = "FFFFFF",
    _cursor                = "1F2329",
    _cursor_highlight      = "F6F8FA",
    _line_numbers          = "59636E",
    _pre_proc              = "1F2329",
    _include               = "CF212E",
    _keyword               = "CF212E",
    _keyword_function      = "CF212E",
    _keyword_return        = "CF212E",
    _storageclass          = "CF212E",
    _conditional           = "CF212E",
    _conditional_ternary   = "CF212E",
    _repeat                = "CF212E",
    _variable              = "1F2329",
    _namespace             = "1F2329",
    _constant              = "1F2329",
    _parameter             = "1F2329",
    _type                  = "CF212E",
    _function              = "1F2329",
    _function_call         = "0350AE",
    _type_builtin          = "CF212E",
    _field                 = "1F2329",
    _function_macro        = "1F2329",
    _attribute             = "1F2329",
    _number                = "0350AE",
    _float                 = "0350AE",
    _string                = "0A3069",
    _character             = "0350AE",
    _string_escape         = "1F2329",
    _boolean               = "1F2329",
    _constant_builtin      = "CF212E",
    _variable_builtin      = "1F2329",
    _operator              = "1F2329",
    _keyword_operator      = "1F2329",
    _punctuation_bracket   = "1F2329",
    _punctuation_delimiter = "1F2329",
    _punctuation_special   = "1F2329",
    _comment               = "59636E",
    _spell                 = "59636E",
    _error                 = "CF212E",
}

@(optimization_mode = "none")
hex_to_sdl_color :: proc(hex_color: string) -> sdl.Color {
    if hex_color == "" {
        fmt.println("[WARNING]: Passed in empty color to hex_to_sdl_color()")
        return sdl.Color{255, 0, 255, 255}
    }

    base := strings.to_lower(hex_color); defer delete(base)
    for char in base {
        if !strings.contains_rune("1234567890abcdef", char) {
            fmt.eprintf("Cannot parse invalid hex code in hex_to_sdl_color %v\n", hex_color)
            return sdl.Color{255, 255, 255, 255}
        }
    }

    red_hex := base[:2]
    green_hex := base[2:4]
    blue_hex := base[4:]
    r := (hex_to_int(red_hex[0]) * 16) + hex_to_int(red_hex[1])
    g := (hex_to_int(green_hex[0]) * 16) + hex_to_int(green_hex[1])
    b := (hex_to_int(blue_hex[0]) * 16) + hex_to_int(blue_hex[1])

    return sdl.Color{u8(r), u8(g), u8(b), 255}
}
