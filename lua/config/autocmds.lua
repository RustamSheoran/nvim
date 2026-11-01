-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
local M = {}

-- Helper to position cursor inside void solve() { ... }
function M.position_at_solve(bufnr, winnr, force)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  winnr = winnr or 0
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  -- Prevent LazyVim last_loc from resetting cursor back to line 1
  vim.b[bufnr].lazyvim_last_loc = true

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if line_count < 10 then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local match_line = nil
  for i, line in ipairs(lines) do
    if line:match("void%s+solve%s*%(") then
      match_line = i
      break
    end
  end

  if not match_line then
    return false
  end

  -- Check if solve() is empty/unmodified
  local is_empty = false
  local line_text = lines[match_line] or ""

  if line_text:match("}%s*$") then
    -- Collapsed one-liner: void solve() {}
    is_empty = true
    lines[match_line] = "void solve() {"
    table.insert(lines, match_line + 1, "    ")
    table.insert(lines, match_line + 2, "}")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  else
    local next_idx = match_line + 1
    local next_line = lines[next_idx]
    if not next_line or vim.trim(next_line) == "}" then
      is_empty = true
      table.insert(lines, next_idx, "    ")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    elseif vim.trim(next_line) == "" then
      local next_next = lines[next_idx + 1]
      if next_next and vim.trim(next_next) == "}" then
        is_empty = true
        if next_line ~= "    " then
          lines[next_idx] = "    "
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        end
      end
    end
  end

  -- Only position inside solve if empty or forced
  if not is_empty and not force then
    return false
  end

  local target_line = match_line + 1
  local target_col = 4

  local function apply_cursor()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    if winnr ~= 0 and vim.api.nvim_win_is_valid(winnr) then
      pcall(vim.api.nvim_set_current_win, winnr)
    end
    pcall(vim.api.nvim_win_set_cursor, 0, { target_line, target_col })
    pcall(vim.cmd, "startinsert!")
    vim.b[bufnr].cp_positioned = true
  end

  apply_cursor()
  vim.schedule(apply_cursor)
  return true
end

local cp_patterns = {
  vim.fn.expand("~/cp") .. "/*.cpp",
  vim.fn.expand("~/cp") .. "/**/*.cpp",
}

-- Suppress LazyVim last_loc before it can reset cursor to line 1 on newly opened CP buffers
vim.api.nvim_create_autocmd("BufReadPre", {
  pattern = cp_patterns,
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    if mark[1] <= 1 then
      vim.b[args.buf].lazyvim_last_loc = true
    end
  end,
})

vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
  pattern = cp_patterns,
  callback = function(args)
    local buf = args.buf
    if vim.b[buf].cp_positioned then
      return
    end
    M.position_at_solve(buf, 0, false)
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

-- Keep void solve() { ... } with a clean empty line when empty
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = { "*.cpp" },
  callback = function(args)
    local buf = args.buf
    if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
      return
    end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local modified = false
    for i, line in ipairs(lines) do
      if line:match("^void%s+solve%s*%(%s*%)%s*%{%s*%}%s*$") then
        lines[i] = "void solve() {"
        table.insert(lines, i + 1, "    ")
        table.insert(lines, i + 2, "}")
        modified = true
        break
      elseif line:match("^void%s+solve%s*%(%s*%)%s*%{%s*$") and lines[i + 1] and lines[i + 1]:match("^%}%s*$") then
        table.insert(lines, i + 1, "    ")
        modified = true
        break
      end
    end
    if modified then
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.cmd("silent! noautocmd write")
    end
  end,
})

-- ==================== Auto Health Check on CP Directory Entry ====================
local cp_health_checked = false
local function try_check()
  if cp_health_checked then
    return
  end
  local cwd = vim.fs.normalize(vim.fn.getcwd())
  local bufname = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
  local cp_path = vim.fs.normalize(vim.fn.expand("~/cp"))

  if cwd:find(cp_path, 1, true) or bufname:find(cp_path, 1, true) then
    cp_health_checked = true
    vim.defer_fn(function()
      pcall(function()
        require("config.cp_health").check({ auto = true })
      end)
    end, 600)
  end
end

vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter" }, {
  group = vim.api.nvim_create_augroup("CpAutoHealthCheck", { clear = true }),
  callback = try_check,
})

-- Also trigger immediately if autocmds was loaded after VimEnter / initial BufEnter
try_check()

-- If startup buffer is an empty CP template, position at solve immediately
local cur_buf = vim.api.nvim_get_current_buf()
local cur_name = vim.fs.normalize(vim.api.nvim_buf_get_name(cur_buf))
local cp_root = vim.fs.normalize(vim.fn.expand("~/cp"))
if cur_name:find(cp_root, 1, true) and cur_name:match("%.cpp$") and not vim.b[cur_buf].cp_positioned then
  M.position_at_solve(cur_buf, 0, false)
end

return M



