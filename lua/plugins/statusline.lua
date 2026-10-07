return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.sections = opts.sections or {}
      opts.sections.lualine_y = {
        {
          function()
            local line = vim.fn.line(".")
            local col = vim.fn.col(".")
            local total = vim.fn.line("$")
            return string.format("Ln %d, Col %d / %d lines", line, col, total)
          end,
          padding = { left = 1, right = 1 },
        },
      }
    end,
  },
}
