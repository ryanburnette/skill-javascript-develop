return {
  "mfussenegger/nvim-lint",
  opts = {
    linters_by_ft = {
      markdown = { "markdownlint-cli2" }, -- Re-enable markdownlint-cli2
      javascript = { "jshint" },
      javascriptreact = { "jshint" },
      vue = { "jshint" },
    },
    linters = {
      ["markdownlint-cli2"] = {
        args = {
          "--config",
          vim.fn.stdpath("config") .. "/.markdownlint.json", -- Point to config file
        },
      },
    },
  },
}
