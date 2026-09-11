return {
  "vyfor/cord.nvim",
  opts = {
    display = {
      theme = "default", -- 'default', 'atom', 'catppuccin', 'minecraft', 'void', 'classic'
      flavor = "dark",   -- 'dark', 'light', 'accent'
    },
    text = {
      editing = "Editing a file",
      viewing = "Reading some code",
      workspace = "",
      terminal = function(opts)
        return "In a terminal (" .. opts.name .. ")"
      end,
      file_browser = false,
    },
  },
}
