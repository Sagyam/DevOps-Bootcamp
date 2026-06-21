-- Omarchy's default Neovim look is Tokyo Night ("tokyonight-night").
-- This mirrors the theme spec Omarchy ships so the container matches a
-- fresh Omarchy box out of the box.
return {
  { "folke/tokyonight.nvim", priority = 1000, opts = {} },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight-night",
    },
  },
}
