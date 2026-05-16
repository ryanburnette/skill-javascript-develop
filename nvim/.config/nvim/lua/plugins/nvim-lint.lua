return {
  "mfussenegger/nvim-lint",
  opts = {
    linters_by_ft = {
      markdown = { "markdownlint-cli2" },
      javascript = { "eslint" },
      javascriptreact = { "eslint" },
      typescript = { "eslint" },
      typescriptreact = { "eslint" },
      vue = { "eslint" },
    },
    linters = {
      eslint = {
        cmd = function()
          local found = vim.fs.find("node_modules/.bin/eslint", { path = vim.fn.getcwd(), upward = true })[1]
          return found or "eslint"
        end,
      },
      ["markdownlint-cli2"] = {
        args = { "--config", vim.fn.stdpath("config") .. "/.markdownlint-cli2.jsonc" },
      },
    },
  },
}
