-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
require('config.remote_clipboard').setup()
-- Auto-save on buffer leave / before commands
vim.opt.autowrite = true
vim.opt.autowriteall = true

-- Relative line numbers (current line is 0, above/below are 1, 2, 3...)
vim.opt.number = false
vim.opt.relativenumber = true

-- Command aliases for common Shift typos (:Q -> :q, :W -> :w, etc.)
vim.api.nvim_create_user_command("Q", function(opts)
  vim.cmd("quit" .. (opts.bang and "!" or ""))
end, { bang = true, desc = "Quit alias" })

vim.api.nvim_create_user_command("Qa", function(opts)
  vim.cmd("quitall" .. (opts.bang and "!" or ""))
end, { bang = true, desc = "Quit all alias" })

vim.api.nvim_create_user_command("W", function(opts)
  vim.cmd("write" .. (opts.bang and "!" or ""))
end, { bang = true, desc = "Write alias" })

vim.api.nvim_create_user_command("Wq", function(opts)
  vim.cmd("wq" .. (opts.bang and "!" or ""))
end, { bang = true, desc = "Write and quit alias" })

vim.api.nvim_create_user_command("Wa", function(opts)
  vim.cmd("wall" .. (opts.bang and "!" or ""))
end, { bang = true, desc = "Write all alias" })


