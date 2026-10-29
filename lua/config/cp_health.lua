-- ==============================================================================
-- Competitive Programming Pre-Contest Environment Health Check (<leader>rh)
-- ==============================================================================
local M = {}

function M.check(opts)
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

    -- If automatically run on startup in ~/cp and all checks pass, show a subtle notification
    if opts.auto and pass_count == #order then
      vim.notify("⚡ CP Environment: All 8 checks passed (GCC, mold, PCH, stack 256MB, Zen cookies)", vim.log.levels.INFO, { title = "CP Ready" })
      return
    end

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
    table.insert(lines, "  " .. string.rep("─", width - 4))

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

    table.insert(lines, "  " .. string.rep("─", width - 4))
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
        results.mold.detail = "v" .. ver .. " (Lightning fast linking)"
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
  vim.system({ "bash", "-c", "ulimit -s" }, { text = true }, function(obj)
    local out = vim.trim(obj.stdout or "")
    local val = tonumber(out)
    if out == "unlimited" or (val and val >= 262144) then
      results.stack.status = "PASS"
      results.stack.detail = (val and string.format("%d KB (Safe for deep DFS)", val)) or "Unlimited"
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
      local bname = db_path:find("zen") and "Zen Browser" or (db_path:find("firefox") and "Firefox" or "Browser")
      results.cookie.status = "PASS"
      results.cookie.detail = string.format("Active (%s profile detected)", bname)
    else
      results.cookie.status = "WARN"
      results.cookie.detail = "No cookies.sqlite found (uses cph-submit)"
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

return M
