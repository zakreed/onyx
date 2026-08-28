package test

import "../src"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

@(test)
test_pos_to_byte :: proc(t: ^testing.T) {
    file_data, err := os.read_entire_file("tests/treesitter_test_file.txt", context.allocator)
    defer delete(file_data)
    assert(err == nil)
    file_string := string(file_data)
    file_lines := strings.split_lines(file_string)
    defer delete(file_lines)
    buffer: src.Buffer
    defer delete(buffer.data)
    for line in file_lines {
        append(&buffer.data, line)
    }

    testing.expect(t, len(buffer.data) == 18)
    testing.expect(t, src._pos_to_byte(buffer.data[:], {0, 0}) == 0)
    testing.expect(t, src._pos_to_byte(buffer.data[:], {5, 0}) == 5)
    testing.expect(t, src._pos_to_byte(buffer.data[:], {0, 1}) == 13)
    testing.expect(t, src._pos_to_byte(buffer.data[:], {0, 2}) == 14)
    testing.expect(t, src._pos_to_byte(buffer.data[:], {6, 2}) == 20)
    testing.expect(t, src._pos_to_byte(buffer.data[:], {2, 5}) == 51)
}
