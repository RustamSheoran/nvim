-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Toggle GitHub Copilot ON/OFF (Contest Mode)
local copilot_enabled = true
vim.keymap.set("n", "<leader>tc", function()
  if copilot_enabled then
    vim.cmd("Copilot disable")
    copilot_enabled = false
    vim.notify("Copilot disabled (Contest Mode)", vim.log.levels.WARN, { title = "Copilot" })
  else
    vim.cmd("Copilot enable")
    copilot_enabled = true
    vim.notify("Copilot enabled", vim.log.levels.INFO, { title = "Copilot" })
  end
end, { desc = "Toggle Copilot (Contest Mode)" })
