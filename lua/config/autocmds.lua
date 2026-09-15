-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = {
    vim.fn.expand("~/cp") .. "/*.cpp",
    vim.fn.expand("~/cp") .. "/**/*.cpp",
  },
  callback = function()
    -- Only trigger if entering a freshly created template file
    if vim.fn.line("$") >= 15 then
      local search_pattern = [[\vvoid\s+solve\s*\(\s*\)\s*\{]]
      local match_line = vim.fn.search(search_pattern, "nw")
      if match_line > 0 and vim.fn.line(".") == 1 then
        local line_text = vim.fn.getline(match_line)
        -- If clang-format collapsed the function into one line
        if line_text:match("}$") then
          vim.fn.setline(match_line, "void solve() {")
          vim.fn.append(match_line, { "    ", "}" })
        elseif vim.trim(vim.fn.getline(match_line + 1)) == "" then
          vim.fn.setline(match_line + 1, "    ")
        end
        vim.api.nvim_win_set_cursor(0, { match_line + 1, 4 })
        vim.cmd("startinsert!")
      end
    end
  end,
})
