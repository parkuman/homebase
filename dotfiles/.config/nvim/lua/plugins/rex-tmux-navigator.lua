return {
  "baggiponte/rex-navigator.nvim",
  main = "rex-navigator",
  lazy = false,
  opts = {},
  -- Declaring keys here makes LazyVim skip its own <C-h/j/k/l> window maps.
  keys = {
    { "<C-h>", "<Plug>(RexNavigateLeft)", desc = "Navigate left" },
    { "<C-j>", "<Plug>(RexNavigateDown)", desc = "Navigate down" },
    { "<C-k>", "<Plug>(RexNavigateUp)", desc = "Navigate up" },
    { "<C-l>", "<Plug>(RexNavigateRight)", desc = "Navigate right" },
  },
}
