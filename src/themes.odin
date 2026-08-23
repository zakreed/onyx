package main

import "core:fmt"
import "core:strings"
import sdl "vendor:sdl3"

Theme :: struct {
    _bg:                    string,
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
    _bg                    = "1D2021",
    _pre_proc              = "FFFFFF",
    _include               = "FB4934",
    _keyword               = "FB4934",
    _keyword_function      = "FB4934",
    _keyword_return        = "FB4934",
    _storageclass          = "FB4934",
    _conditional           = "FB4934",
    _conditional_ternary   = "FB4934",
    _repeat                = "FB4934",
    _variable              = "FFFFFF",
    _namespace             = "FFFFFF",
    _constant              = "FFFFFF",
    _parameter             = "FFFFFF",
    _type                  = "FABD2F",
    _function              = "B8BB26",
    _function_call         = "B8BB26",
    _type_builtin          = "FABD2F",
    _field                 = "FFFFFF",
    _function_macro        = "FFFFFF",
    _attribute             = "FFFFFF",
    _number                = "D3869B",
    _float                 = "D3869B",
    _string                = "B8BB26",
    _character             = "D3869B",
    _string_escape         = "B8BB26",
    _boolean               = "D3869B",
    _constant_builtin      = "FABD2F",
    _variable_builtin      = "FFFFFF",
    _operator              = "83A598",
    _keyword_operator      = "FFFFFF",
    _punctuation_bracket   = "928374",
    _punctuation_delimiter = "FFFFFF",
    _punctuation_special   = "928374",
    _comment               = "7C6F64",
    _spell                 = "7C6F64",
    _error                 = "FB4934",
}

hex_to_sdl_color :: proc(hex_color: string) -> sdl.Color {
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

    hex_decimal_map := make(map[u8]int); defer delete(hex_decimal_map)
    hex_decimal_map['0'] = 0
    hex_decimal_map['1'] = 1
    hex_decimal_map['2'] = 2
    hex_decimal_map['3'] = 3
    hex_decimal_map['4'] = 4
    hex_decimal_map['5'] = 5
    hex_decimal_map['6'] = 6
    hex_decimal_map['7'] = 7
    hex_decimal_map['8'] = 8
    hex_decimal_map['9'] = 9
    hex_decimal_map['a'] = 10
    hex_decimal_map['b'] = 11
    hex_decimal_map['c'] = 12
    hex_decimal_map['d'] = 13
    hex_decimal_map['e'] = 14
    hex_decimal_map['f'] = 15

    r := (hex_decimal_map[red_hex[0]] * 16) + hex_decimal_map[red_hex[1]]
    g := (hex_decimal_map[green_hex[0]] * 16) + hex_decimal_map[green_hex[1]]
    b := (hex_decimal_map[blue_hex[0]] * 16) + hex_decimal_map[blue_hex[1]]

    return sdl.Color{u8(r), u8(g), u8(b), 255}
}
