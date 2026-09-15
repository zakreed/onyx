package test

import "../src"
import "core:testing"

@(test)
test_hex_to_int :: proc(t: ^testing.T) {
    testing.expect(t, src.hex_to_int('0') == 0)
    testing.expect(t, src.hex_to_int('5') == 5)
    testing.expect(t, src.hex_to_int('9') == 9)
    testing.expect(t, src.hex_to_int('A') == 10)
    testing.expect(t, src.hex_to_int('a') == 10)
}
