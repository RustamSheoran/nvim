return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.sections = opts.sections or {}
      opts.sections.lualine_x = opts.sections.lualine_x or {}
      table.insert(opts.sections.lualine_x, 1, {
        function()
          return (vim.g.autoformat == true) and "󰉠 FMT" or ""
        end,
        color = { fg = "#7aa2f7", gui = "bold" },
        cond = function()
          return vim.g.autoformat == true
        end,
      })
      opts.sections.lualine_y = {
        { "progress", separator = " ", padding = { left = 1, right = 0 } },
        {
          function()
            local line = vim.fn.line(".")
            local col = vim.fn.col(".")
            local total = vim.fn.line("$")
            return string.format("Ln %d, Col %d / %d lines", line, col, total)
          end,
          padding = { left = 0, right = 1 },
        },
      }
    end,
  },
}
