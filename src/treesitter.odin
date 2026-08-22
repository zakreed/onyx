package main

import ts "../vendor/tree-sitter-odin"
import ts_odin "../vendor/tree-sitter-odin/parsers/odin"
import "core:os"
import sdl "vendor:sdl3"

Treesitter :: struct {
    source:        string,
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

treesitter_get_char_color :: proc(index: int, char: rune, line_num: int) -> sdl.Color {
    type := globals.treesitter.char_type_map[index]
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

treesitter_generate_color_list :: proc() {
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

    for capture in globals.treesitter.data {
        for byte_index in capture.start_byte ..< capture.end_byte {
            globals.treesitter.char_type_map[int(byte_index)] = capture.type
        }
    }
}
