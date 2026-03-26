return {
  "stevearc/conform.nvim",
  opts = function(_, opts)
    opts.formatters_by_ft = {
      javascript = { "prettier" },
      vue = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      markdown = { "prettier" },
    }
    opts.formatters.prettier = {
      condition = function(_, ctx)
        return vim.fn.filereadable(vim.fs.dirname(ctx.filename) .. "/.prettierrc") > 0
      end,
    }
  end,
}
