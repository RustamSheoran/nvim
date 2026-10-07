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

-- ==================== Idle Auto-Save (2s debounce) ====================
local autosave_timer = nil

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = vim.api.nvim_create_augroup("AutoSaveIdle", { clear = true }),
  callback = function(args)
    local buf = args.buf
    if not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].modified then
      return
    end
    if vim.bo[buf].buftype ~= "" or vim.bo[buf].readonly or vim.api.nvim_buf_get_name(buf) == "" then
      return
    end

    if autosave_timer then
      autosave_timer:stop()
      autosave_timer:close()
      autosave_timer = nil
    end

    autosave_timer = vim.uv.new_timer()
    autosave_timer:start(
      2000,
      0,
      vim.schedule_wrap(function()
        if autosave_timer then
          autosave_timer:close()
          autosave_timer = nil
        end
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified and vim.bo[buf].buftype == "" then
          local mode = vim.api.nvim_get_mode().mode
          vim.api.nvim_buf_call(buf, function()
            if mode:find("^i") then
              vim.cmd("silent! noautocmd write")
            else
              vim.cmd("silent! update")
            end
          end)
        end
      end)
    )
  end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
  group = "AutoSaveIdle",
  callback = function(args)
    local buf = args.buf
    if
      vim.api.nvim_buf_is_valid(buf)
      and vim.bo[buf].modified
      and vim.bo[buf].buftype == ""
      and vim.api.nvim_buf_get_name(buf) ~= ""
    then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("silent! update")
      end)
    end
  end,
})

