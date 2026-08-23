package main

import ts "../vendor/tree-sitter-odin"
import ts_odin "../vendor/tree-sitter-odin/parsers/odin"
import "core:fmt"
import "core:math"
import "core:os"
import sdl "vendor:sdl3"

Treesitter :: struct {
    source:        string,
    parser:        ts.Parser,
    tree:          ts.Tree,
    root:          ts.Node,
    query:         ts.Query,
    cursor:        ts.Query_Cursor,
    outdated:      bool,
    data:          [dynamic]TreesitterCapture,
    char_type_map: map[int]string,
}

// TODO: Deduce language to use instead of hard coding it to odin
treesitter_init :: proc() {
    parser := ts.parser_new()
    globals.treesitter.parser = parser
    odin_lang := ts_odin.tree_sitter_odin()
    ts.parser_set_language(parser, odin_lang)
    raw_file_data, load_ok := os.read_entire_file(LOADED_FILE, context.allocator)
    source := string(raw_file_data)
    globals.treesitter.source = source
    globals.treesitter.tree = ts.parser_parse_string(parser, source)
    globals.treesitter.root = ts.tree_root_node(globals.treesitter.tree)
    query, _, _ := ts.query_new(odin_lang, ts_odin.HIGHLIGHTS)
    globals.treesitter.query = query
    globals.treesitter.cursor = ts.query_cursor_new()
    globals.treesitter.outdated = true
}

treesitter_get_char_color :: proc(index: int, char: rune, line_num: int) -> sdl.Color {
    type := globals.treesitter.char_type_map[index]

    switch type {
    case "bg":
        return hex_to_sdl_color(globals.current_theme._bg)
    case "pre.proc":
        return hex_to_sdl_color(globals.current_theme._pre_proc)
    case "include":
        return hex_to_sdl_color(globals.current_theme._include)
    case "keyword":
        return hex_to_sdl_color(globals.current_theme._keyword)
    case "keyword.function":
        return hex_to_sdl_color(globals.current_theme._keyword_function)
    case "keyword.return":
        return hex_to_sdl_color(globals.current_theme._keyword_return)
    case "storageclass":
        return hex_to_sdl_color(globals.current_theme._storageclass)
    case "conditional":
        return hex_to_sdl_color(globals.current_theme._conditional)
    case "conditional.ternary":
        return hex_to_sdl_color(globals.current_theme._conditional_ternary)
    case "repeat":
        return hex_to_sdl_color(globals.current_theme._repeat)
    case "variable":
        return hex_to_sdl_color(globals.current_theme._variable)
    case "namespace":
        return hex_to_sdl_color(globals.current_theme._namespace)
    case "constant":
        return hex_to_sdl_color(globals.current_theme._conditional)
    case "parameter":
        return hex_to_sdl_color(globals.current_theme._parameter)
    case "type":
        return hex_to_sdl_color(globals.current_theme._type)
    case "function":
        return hex_to_sdl_color(globals.current_theme._function)
    case "function.call":
        return hex_to_sdl_color(globals.current_theme._function_call)
    case "type.builtin":
        return hex_to_sdl_color(globals.current_theme._type_builtin)
    case "field":
        return hex_to_sdl_color(globals.current_theme._field)
    case "function.macro":
        return hex_to_sdl_color(globals.current_theme._function_macro)
    case "attribute":
        return hex_to_sdl_color(globals.current_theme._attribute)
    case "number":
        return hex_to_sdl_color(globals.current_theme._number)
    case "float":
        return hex_to_sdl_color(globals.current_theme._float)
    case "string":
        return hex_to_sdl_color(globals.current_theme._string)
    case "character":
        return hex_to_sdl_color(globals.current_theme._character)
    case "string.escape":
        return hex_to_sdl_color(globals.current_theme._string_escape)
    case "boolean":
        return hex_to_sdl_color(globals.current_theme._boolean)
    case "constant.builtin":
        return hex_to_sdl_color(globals.current_theme._constant_builtin)
    case "variable.builtin":
        return hex_to_sdl_color(globals.current_theme._variable_builtin)
    case "operator":
        return hex_to_sdl_color(globals.current_theme._operator)
    case "keyword.operator":
        return hex_to_sdl_color(globals.current_theme._keyword_operator)
    case "punctuation.bracket":
        return hex_to_sdl_color(globals.current_theme._punctuation_bracket)
    case "punctuation.delimiter":
        return hex_to_sdl_color(globals.current_theme._punctuation_delimiter)
    case "punctuation.special":
        return hex_to_sdl_color(globals.current_theme._punctuation_special)
    case "comment":
        return hex_to_sdl_color(globals.current_theme._comment)
    case "spell":
        return hex_to_sdl_color(globals.current_theme._spell)
    case "error":
        return hex_to_sdl_color(globals.current_theme._error)
    }

    return sdl.Color{255, 255, 255, 255}
}

treesitter_generate_color_list :: proc() {
    clear(&globals.treesitter.data)
    clear(&globals.treesitter.char_type_map)

    ts.query_cursor_exec(globals.treesitter.cursor, globals.treesitter.query, globals.treesitter.root)
    for match, cap_idx in ts.query_cursor_next_capture(globals.treesitter.cursor) {
        cap := match.captures[cap_idx]
        if len(ts.query_predicates_for_pattern(globals.treesitter.query, u32(match.pattern_index))) > 0 {
            continue
        }

        fmt.println(
            ts.node_text(cap.node, globals.treesitter.source),
            ts.query_capture_name_for_id(globals.treesitter.query, cap.index),
        )

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

    for capture in globals.treesitter.data {
        for byte_index in capture.start_byte ..< capture.end_byte {
            globals.treesitter.char_type_map[int(byte_index)] = capture.type
        }
    }
}

_pos_to_byte :: proc(pos: vec2i) -> int {
    byte: int
    for line, i in globals.active_buffer {
        if globals.cursor.prev_pos.y == i32(i) {break}
        byte += len(line) + 1
    }

    return byte + int(pos.x)
}

treesitter_update :: proc() {
    prev_byte := _pos_to_byte(globals.cursor.prev_pos)
    cur_byte := _pos_to_byte(globals.cursor.pos)
    start_byte := math.min(prev_byte, cur_byte)

    edit := ts.Input_Edit {
        start_byte = u32(start_byte),
        old_end_byte = u32(prev_byte),
        new_end_byte = u32(cur_byte),
        start_point = ts.Point{row = u32(globals.cursor.prev_pos.y), col = u32(globals.cursor.prev_pos.x)},
        old_end_point = ts.Point{row = u32(globals.cursor.prev_pos.y), col = u32(globals.cursor.prev_pos.x)},
        new_end_point = ts.Point{row = u32(globals.cursor.pos.y), col = u32(globals.cursor.pos.x)},
    }
    ts.tree_edit(globals.treesitter.tree, &edit)

    new_buffer_string := buffer_to_string()
    defer delete(new_buffer_string)

    globals.treesitter.source = new_buffer_string
    globals.treesitter.tree = ts.parser_parse_string(globals.treesitter.parser, new_buffer_string, globals.treesitter.tree)
    globals.treesitter.root = ts.tree_root_node(globals.treesitter.tree)
}
