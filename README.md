# greyout.nvim

Dim less important code to focus on what matters. 

A Neovim plugin that uses Treesitter to visually de-emphasize boilerplate code like error handling and logging.

## Features

- **Smart Pattern Detection** - Automatically identifies error handling (`if err != nil`) and logging statements
- **Multiple Display Modes** - Grey out, conceal, or fold matched patterns
- **Treesitter Powered** - Accurate syntax-aware matching
- **Language Support** - Currently supports Go with extensible architecture

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "kungfusheep/greyout.nvim",
    opts = {},
}
```

## Usage

The plugin automatically activates for supported file types. Use these commands:

- `:GreyoutToggle` - Turn on/off
- `:GreyoutCycle` - Cycle through display modes (grey → conceal → fold)
- `:GreyoutMode [mode]` - Set specific mode: `grey`, `conceal`, or `fold`

Default keymaps:
- `<leader>gt` - Toggle greyout
- `<leader>gc` - Cycle display modes

## Configuration

```lua
require("greyout").setup({
    enabled = true,
    mode = "grey",  -- "grey", "conceal", or "fold"
    languages = {
        go = {
            enabled = true,
            patterns = {
                error_handling = true,  -- if err != nil blocks
                logging = true,         -- log.* and fmt.Print* calls
            }
        },
    },
    highlight = {
        link = "Comment",  -- or use custom = { fg = "#808080" }
    },
})
```

## Custom Patterns

Add your own Treesitter queries:

```lua
custom_patterns = {
  go = {
    my_pattern = [[(comment) @comment]]
  }
}
```

## License

Apache 2.0 
