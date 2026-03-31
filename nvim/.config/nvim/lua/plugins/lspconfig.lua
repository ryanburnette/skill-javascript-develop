return {
  "neovim/nvim-lspconfig",
  opts = {
    inlay_hints = { enabled = false },
  },
  init = function()
    vim.diagnostic.config({ virtual_text = false })
  end,
}
