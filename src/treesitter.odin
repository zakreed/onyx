package main

import ts "../vendor/odin-tree-sitter"
import ts_odin "../vendor/odin-tree-sitter/parsers/odin"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import sdl "vendor:sdl3"

TreesitterCapture :: struct {
    start_byte: u32,
    end_byte:   u32,
    token:      string,
    type:       string,
}

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
    editor.treesitter.parser = parser
    odin_lang := ts_odin.tree_sitter_odin()
    ts.parser_set_language(parser, odin_lang)
    raw_file_data, load_ok := os.read_entire_file(LOADED_FILE, context.allocator)
    source := string(raw_file_data)
    editor.treesitter.source = source
    editor.treesitter.tree = ts.parser_parse_string(parser, source)
    editor.treesitter.root = ts.tree_root_node(editor.treesitter.tree)
    query, _, _ := ts.query_new(odin_lang, ts_odin.HIGHLIGHTS)
    editor.treesitter.query = query
    editor.treesitter.cursor = ts.query_cursor_new()
    editor.treesitter.outdated = true
}

treesitter_get_char_color :: proc(index: int, char: rune, line_num: int) -> sdl.Color {
    type := editor.treesitter.char_type_map[index]

    switch type {
    case "bg":
        return hex_to_sdl_color(editor.current_theme._bg)
    case "pre.proc":
        return hex_to_sdl_color(editor.current_theme._pre_proc)
    case "include":
        return hex_to_sdl_color(editor.current_theme._include)
    case "keyword":
        return hex_to_sdl_color(editor.current_theme._keyword)
    case "keyword.function":
        return hex_to_sdl_color(editor.current_theme._keyword_function)
    case "keyword.return":
        return hex_to_sdl_color(editor.current_theme._keyword_return)
    case "storageclass":
        return hex_to_sdl_color(editor.current_theme._storageclass)
    case "conditional":
        return hex_to_sdl_color(editor.current_theme._conditional)
    case "conditional.ternary":
        return hex_to_sdl_color(editor.current_theme._conditional_ternary)
    case "repeat":
        return hex_to_sdl_color(editor.current_theme._repeat)
    case "variable":
        return hex_to_sdl_color(editor.current_theme._variable)
    case "namespace":
        return hex_to_sdl_color(editor.current_theme._namespace)
    case "constant":
        return hex_to_sdl_color(editor.current_theme._conditional)
    case "parameter":
        return hex_to_sdl_color(editor.current_theme._parameter)
    case "type":
        return hex_to_sdl_color(editor.current_theme._type)
    case "function":
        return hex_to_sdl_color(editor.current_theme._function)
    case "function.call":
        return hex_to_sdl_color(editor.current_theme._function_call)
    case "type.builtin":
        return hex_to_sdl_color(editor.current_theme._type_builtin)
    case "field":
        return hex_to_sdl_color(editor.current_theme._field)
    case "function.macro":
        return hex_to_sdl_color(editor.current_theme._function_macro)
    case "attribute":
        return hex_to_sdl_color(editor.current_theme._attribute)
    case "number":
        return hex_to_sdl_color(editor.current_theme._number)
    case "float":
        return hex_to_sdl_color(editor.current_theme._float)
    case "string":
        return hex_to_sdl_color(editor.current_theme._string)
    case "character":
        return hex_to_sdl_color(editor.current_theme._character)
    case "string.escape":
        return hex_to_sdl_color(editor.current_theme._string_escape)
    case "boolean":
        return hex_to_sdl_color(editor.current_theme._boolean)
    case "constant.builtin":
        return hex_to_sdl_color(editor.current_theme._constant_builtin)
    case "variable.builtin":
        return hex_to_sdl_color(editor.current_theme._variable_builtin)
    case "operator":
        return hex_to_sdl_color(editor.current_theme._operator)
    case "keyword.operator":
        return hex_to_sdl_color(editor.current_theme._keyword_operator)
    case "punctuation.bracket":
        return hex_to_sdl_color(editor.current_theme._punctuation_bracket)
    case "punctuation.delimiter":
        return hex_to_sdl_color(editor.current_theme._punctuation_delimiter)
    case "punctuation.special":
        return hex_to_sdl_color(editor.current_theme._punctuation_special)
    case "comment":
        return hex_to_sdl_color(editor.current_theme._comment)
    case "spell":
        return hex_to_sdl_color(editor.current_theme._spell)
    case "error":
        return hex_to_sdl_color(editor.current_theme._error)
    }

    return sdl.Color{255, 255, 255, 255}
}

treesitter_generate_color_list :: proc() {
    clear(&editor.treesitter.data)
    clear(&editor.treesitter.char_type_map)

    ts.query_cursor_exec(editor.treesitter.cursor, editor.treesitter.query, editor.treesitter.root)
    for match, cap_idx in ts.query_cursor_next_capture(editor.treesitter.cursor) {
        cap := match.captures[cap_idx]
        if len(ts.query_predicates_for_pattern(editor.treesitter.query, u32(match.pattern_index))) > 0 {
            continue
        }

        // fmt.println(
        //     ts.node_text(cap.node, editor.treesitter.source),
        //     ts.query_capture_name_for_id(editor.treesitter.query, cap.index),
        // )

        append(
            &editor.treesitter.data,
            TreesitterCapture {
                start_byte = ts.node_start_byte(cap.node),
                end_byte = ts.node_end_byte(cap.node),
                token = ts.node_text(cap.node, editor.treesitter.source),
                type = ts.query_capture_name_for_id(editor.treesitter.query, cap.index),
            },
        )
    }

    for capture in editor.treesitter.data {
        for byte_index in capture.start_byte ..< capture.end_byte {
            editor.treesitter.char_type_map[int(byte_index)] = capture.type
        }
    }
}

_min_point :: proc(p1, p2: ts.Point) -> ts.Point {
    if p1.row < p2.row {
        return p1
    } else if p2.row < p1.row {
        return p2
    } else if p1.row == p2.row {
        if p1.col < p2.col {
            return p1
        } else if p2.col < p1.col {
            return p2
        }
    }

    return p1
}

_pos_to_byte :: proc(buffer: []string, pos: vec2i) -> int {
    byte: int
    for line, i in buffer {
        if pos.y == i32(i) {break}
        byte += len(line) + 1
    }

    return byte + int(pos.x)
}

treesitter_update :: proc(buffer: ^Buffer) {
    previous_buffer_data := strings.split_lines(editor.treesitter.source)
    defer delete(previous_buffer_data)
    prev_byte := _pos_to_byte(previous_buffer_data, buffer.cursor.prev_pos)
    cur_byte := _pos_to_byte(editor.active_buffer.data[:], buffer.cursor.pos)
    start_byte := math.min(prev_byte, cur_byte)
    prev_point := ts.Point {
        row = u32(buffer.cursor.prev_pos.y),
        col = u32(buffer.cursor.prev_pos.x),
    }
    cur_point := ts.Point {
        row = u32(buffer.cursor.pos.y),
        col = u32(buffer.cursor.pos.x),
    }
    start_point := _min_point(prev_point, cur_point)

    edit := ts.Input_Edit {
        start_byte    = u32(start_byte),
        old_end_byte  = u32(prev_byte),
        new_end_byte  = u32(cur_byte),
        start_point   = start_point,
        old_end_point = prev_point,
        new_end_point = cur_point,
    }
    ts.tree_edit(editor.treesitter.tree, &edit)

    new_buffer_string := buffer_to_string(buffer)
    delete(editor.treesitter.source)
    editor.treesitter.source = new_buffer_string
    editor.treesitter.tree = ts.parser_parse_string(editor.treesitter.parser, new_buffer_string, editor.treesitter.tree)
    editor.treesitter.root = ts.tree_root_node(editor.treesitter.tree)
}
