-- Omarchy ships a small tweak to silence LazyVim's "what's new" popup so the
-- editor opens straight to work. The popup is controlled by LazyVim's `news`
-- option (see https://www.lazyvim.org/configuration).
return {
  {
    "LazyVim/LazyVim",
    opts = {
      news = {
        lazyvim = false,
        neovim = false,
      },
    },
  },
}
