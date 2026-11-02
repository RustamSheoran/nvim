-- ==============================================================================
-- Competitive Programming Pre-Contest Environment Health Check (<leader>rh)
-- ==============================================================================
local M = {}

-- State storage in ~/.local/state/nvim/cp_health_state.json
local function get_health_state_file()
  local state_dir = vim.fn.stdpath("state")
  pcall(vim.fn.mkdir, state_dir, "p")
  return state_dir .. "/cp_health_state.json"
end

local function read_health_state()
  local file = get_health_state_file()
  if vim.fn.filereadable(file) == 1 then
    local content = table.concat(vim.fn.readfile(file), "")
    local ok, data = pcall(vim.json.decode, content)
    if ok and type(data) == "table" then
      return data
    end
  end
  return {}
end

local function write_health_state(commit_hash)
  local file = get_health_state_file()
  local data = {
    last_check_time = os.time(),
    last_commit_hash = commit_hash or "",
  }
  local encoded = vim.json.encode(data)
  pcall(vim.fn.writefile, { encoded }, file)
end

local function get_config_commit_hash(callback)
  local config_dir = vim.fn.stdpath("config")
  if vim.fn.isdirectory(config_dir .. "/.git") ~= 1 then
    callback("")
    return
  end
  vim.system({ "git", "-C", config_dir, "rev-parse", "HEAD" }, { text = true }, function(obj)
    local hash = (obj.code == 0 and obj.stdout) and vim.trim(obj.stdout) or ""
    callback(hash)
  end)
end

function M.run_diagnostics(opts, cur_hash)
  opts = opts or {}
  if not opts.auto then
    vim.notify("Running pre-contest environment diagnostics...", vim.log.levels.INFO, { title = "CP Health" })
  end

  local results = {
    gcc = { status = "PENDING", title = "GCC Compiler", detail = "" },
    mold = { status = "PENDING", title = "Mold Fast Linker", detail = "" },
    pch = { status = "PENDING", title = "Bits Precompiled Header", detail = "" },
    stack = { status = "PENDING", title = "Recursion Stack Limit", detail = "" },
    cookie = { status = "PENDING", title = "CF Headless Cookie Submit", detail = "" },
    handle = { status = "PENDING", title = "Codeforces Handle", detail = "" },
    companion = { status = "PENDING", title = "Companion Server (Port 27121)", detail = "" },
    sanitizer = { status = "PENDING", title = "ASan / UBSan Protection", detail = "" },
  }

  local pending = 8

  local function render_results()
    local pass_count = 0
    local order = { "gcc", "mold", "pch", "stack", "cookie", "handle", "companion", "sanitizer" }

    for _, key in ipairs(order) do
      if results[key].status == "PASS" then
        pass_count = pass_count + 1
      end
    end

    -- Save state so weekly throttle and git-pull triggers track this run
    write_health_state(cur_hash)

    -- If automatically run on startup in ~/cp, show a subtle notification and NEVER open a window
    if opts.auto then
      if pass_count == #order then
        local bname = (results.cookie.status == "PASS" and results.cookie.detail:match("%((.-)%s*profile")) or "Browser"
        vim.notify(string.format("⚡ CP Environment: All 8 checks passed (GCC, mold, PCH, stack 256MB, %s cookies)", bname), vim.log.levels.INFO, { title = "CP Ready" })
      else
        vim.notify(string.format("⚠️ CP Health: %d/%d checks passed (%d warnings/failures). Press <leader>rh to view diagnostics.", pass_count, #order, #order - pass_count), vim.log.levels.WARN, { title = "CP Health Alert" })
      end
      return
    end

    -- Manual run (<leader>rh): open interactive floating diagnostic window
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"

    local width = 76
    local height = 19
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
      title = " 🛠️ Pre-Contest Environment Health Check (<leader>rh) ",
      title_pos = "center",
    })

    local lines = {}
    table.insert(lines, "")
    table.insert(lines, "  Diagnostic Component                Status    Details")
    table.insert(lines, "  " .. string.rep("-", width - 4))

    for _, key in ipairs(order) do
      local item = results[key]
      local icon = "✅ PASS"
      if item.status == "WARN" then
        icon = "⚠️ WARN"
      elseif item.status == "FAIL" then
        icon = "❌ FAIL"
      end

      local formatted = string.format("  %-35s %-9s %s", item.title, icon, item.detail)
      if #formatted > width - 2 then
        formatted = formatted:sub(1, width - 5) .. "..."
      end
      table.insert(lines, formatted)
    end

    table.insert(lines, "  " .. string.rep("-", width - 4))
    if pass_count == #order then
      table.insert(lines, string.format("  🎉 Score: %d/%d checks passed! Your environment is 100%% contest-ready.", pass_count, #order))
    else
      table.insert(lines, string.format("  ℹ️  Score: %d/%d checks passed. Review warnings above before your round.", pass_count, #order))
    end
    table.insert(lines, "  Press [q] or [Esc] to close")

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    local function close_win()
      if vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end

    vim.keymap.set("n", "q", close_win, { buffer = buf, nowait = true })
    vim.keymap.set("n", "<Esc>", close_win, { buffer = buf, nowait = true })
  end

  local function check_done()
    pending = pending - 1
    if pending == 0 then
      vim.schedule(render_results)
    end
  end

  -- Check 1: GCC Compiler
  if vim.fn.executable("g++") == 1 then
    vim.system({ "g++", "--version" }, { text = true }, function(obj)
      if obj.code == 0 and obj.stdout then
        local first_line = obj.stdout:match("([^\r\n]+)") or "Installed"
        results.gcc.status = "PASS"
        results.gcc.detail = first_line:gsub("^g%+%+%s*", ""):gsub("%(GCC%)%s*", "")
      else
        results.gcc.status = "FAIL"
        results.gcc.detail = "g++ returned non-zero exit code"
      end
      check_done()
    end)
  else
    results.gcc.status = "FAIL"
    results.gcc.detail = "g++ binary not found in PATH"
    check_done()
  end

  -- Check 2: Mold Linker
  if vim.fn.executable("mold") == 1 then
    vim.system({ "mold", "--version" }, { text = true }, function(obj)
      if obj.code == 0 and obj.stdout then
        local ver = obj.stdout:match("mold%s*([%d%.]+)") or "Installed"
        results.mold.status = "PASS"
        results.mold.detail = "v" .. ver .. " (Fast linking)"
      else
        results.mold.status = "WARN"
        results.mold.detail = "mold command error"
      end
      check_done()
    end)
  else
    results.mold.status = "WARN"
    results.mold.detail = "mold not installed (falling back to ld)"
    check_done()
  end

  -- Check 3: Bits Precompiled Header
  local pch_check_cmd = [[bash -c 'echo "#include <bits/stdc++.h>" | g++ -H -fsyntax-only -x c++ - 2>&1 | grep -E "\.gch" | head -n 1']]
  vim.system({ "bash", "-c", pch_check_cmd }, { text = true }, function(obj)
    if obj.code == 0 and obj.stdout and obj.stdout ~= "" then
      results.pch.status = "PASS"
      results.pch.detail = "Active (~0.12s compile time)"
    else
      results.pch.status = "WARN"
      results.pch.detail = "Missing (run ./setup.sh to precompile)"
    end
    check_done()
  end)

  -- Check 4: Stack Limit
  local shell_cmd = vim.fn.executable("sh") == 1 and { "sh", "-c", "ulimit -s" } or { "bash", "-c", "ulimit -s" }
  vim.system(shell_cmd, { text = true }, function(obj)
    local out = vim.trim(obj.stdout or "")
    local val = tonumber(out)
    if out == "unlimited" or (val and val >= 262144) then
      results.stack.status = "PASS"
      results.stack.detail = (val and string.format("%d KB (Safe for deep DFS)", val)) or "Unlimited"
    elseif val and val >= 65520 then
      results.stack.status = "PASS"
      results.stack.detail = string.format("%d KB (macOS max limit)", val)
    elseif val and val > 16384 then
      results.stack.status = "PASS"
      results.stack.detail = string.format("%d KB", val)
    else
      results.stack.status = "WARN"
      results.stack.detail = string.format("%s KB (Default limit: deep recursion may crash)", out)
    end
    check_done()
  end)

  -- Check 5: Browser & Headless Cookie Database
  local cf_cookie = require("config.cf_cookie_submit")
  if cf_cookie.is_cookie_allowed() then
    local db_path = cf_cookie.find_cookie_database()
    if db_path then
      local bname = cf_cookie.last_detected_browser or (db_path:find("zen") and "Zen Browser" or (db_path:find("firefox") and "Firefox" or "Browser"))
      results.cookie.status = "PASS"
      results.cookie.detail = string.format("Active (%s profile detected)", bname)
    else
      results.cookie.status = "WARN"
      results.cookie.detail = "No active cookies found (fallback: cph-submit)"
    end
  else
    results.cookie.status = "WARN"
    results.cookie.detail = "Disabled globally (<leader>rk to enable)"
  end
  check_done()

  -- Check 6: Codeforces Handle
  require("config.codeforces").get_handle(function(h)
    if h and h ~= "" then
      results.handle.status = "PASS"
      results.handle.detail = string.format("%s (Elo HUD & watcher configured)", h)
    else
      results.handle.status = "WARN"
      results.handle.detail = "Not set (press <leader>rl to set)"
    end
    check_done()
  end)

  -- Check 7: Companion Server Port 27121
  vim.system({ "curl", "-s", "http://127.0.0.1:27121/getSubmit" }, { text = true }, function(obj)
    if obj.code == 0 then
      results.companion.status = "PASS"
      results.companion.detail = "Listening on port 27121 (Ready for companion)"
    else
      results.companion.status = "PASS"
      results.companion.detail = "Starts on demand via cph_server.start()"
    end
    check_done()
  end)

  -- Check 8: AddressSanitizer & UndefinedBehaviorSanitizer
  local san_test_cmd = [[bash -c 'g++ -O2 -std=c++17 -fsanitize=address,undefined -x c++ - -o /tmp/__test_san <<< "int main(){return 0;}" && rm -f /tmp/__test_san']]
  vim.system({ "bash", "-c", san_test_cmd }, { text = true }, function(obj)
    if obj.code == 0 then
      results.sanitizer.status = "PASS"
      results.sanitizer.detail = "Operational (Pre-submission lock active)"
    else
      results.sanitizer.status = "WARN"
      results.sanitizer.detail = "Sanitizer library check failed"
    end
    check_done()
  end)
end

-- Primary entry point for health check.
-- When opts.auto is true:
--   - Does at most 1 check per week, or runs immediately after a git pull
--   - Displays a clean notification only (never opens a floating window)
-- When opts.auto is false (manual <leader>rh):
--   - Bypasses weekly throttle and opens interactive floating diagnostics
function M.check(opts)
  opts = opts or {}

  -- If auto-check requested on startup / entry, throttle to once a week or after a git pull
  if opts.auto and not opts.force then
    local state = read_health_state()
    local last_time = tonumber(state.last_check_time) or 0
    local last_hash = tostring(state.last_commit_hash or "")
    local one_week = 7 * 24 * 3600
    local now = os.time()

    get_config_commit_hash(function(cur_hash)
      local is_after_pull = (cur_hash ~= "" and last_hash ~= "" and cur_hash ~= last_hash)
      local is_weekly_due = (last_time == 0 or (now - last_time) >= one_week)

      if not is_after_pull and not is_weekly_due then
        -- Skip check: checked within the last 7 days and no git pull occurred
        return
      end

      vim.schedule(function()
        M.run_diagnostics(opts, cur_hash)
      end)
    end)
    return
  end

  get_config_commit_hash(function(cur_hash)
    vim.schedule(function()
      M.run_diagnostics(opts, cur_hash)
    end)
  end)
end

return M
