# PackUI.nvim

A modern plugin manager UI for Neovim.

## Features

- Interactive interface to manage installed plugins
- View available updates with changelogs
- Update or delete plugins with simple keybindings
- Clean, informative UI with syntax highlighting

## Installation

### Using Neovim 0.12+ built-in packmodule

PackUI can be installed using Neovim's native package manager in version 0.12 and later:

```lua
vim.pack.add({
  {
    source = "crixuamg/packui.nvim",
  }
})
```

## Usage

After installing, run `:PackUI` to open the plugin manager interface.

Keybindings in the PackUI window:
- `u` - Update plugin under cursor
- `d` - Delete plugin under cursor
- `q` or `<Esc>` - Close the window

## Configuration

Call `require("packui").setup()` to initialize the plugin. No configuration options are currently available.

## License

MIT
