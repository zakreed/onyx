# Onyx

Onyx is a native code editor.

## Building

Download and install the [Odin compiler](https://odin-lang.org/docs/install).

Run `odin build ./src`, or use the provided makefile

This project depends on `(odin-tree-sitter)[https://github.com/laytan/odin-tree-sitter]`.

To install, navigate to the `/vendor/odin-tree-sitter` directory and run `odin run build -- install`.

You will also need to install a treesitter grammar for any language you want to create parser for.

For Odin I recommend https://github.com/tree-sitter-grammars/tree-sitter-odin

This can be installed with `odin run build -- install-parser -parser:https://github.com/tree-sitter-grammars/tree-sitter-odin`

## Screenshots

[screenshot1](images/screenshot1.png)
[screenshot2](images/screenshot2.png)
