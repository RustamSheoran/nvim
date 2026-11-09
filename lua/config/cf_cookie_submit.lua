-- ==============================================================================
-- Codeforces Headless Cookie Submission & Cookie Consent System
-- ==============================================================================
local M = {}

-- ==============================================================================
-- Browser Profile Discovery & System Default Detection
-- ==============================================================================
-- Auto-detects the user's default browser and active cookie database.
-- Never hardcodes a browser. Users can optionally set vim.g.cp_browser or vim.g.cf_browser.
M.custom_cookie_path = nil
M.last_detected_browser = nil

local function get_system_default_browser_name()
  if vim.g.cp_browser and vim.g.cp_browser ~= "" then
    return vim.g.cp_browser:lower()
  end
  if vim.g.cf_browser and vim.g.cf_browser ~= "" then
    return vim.g.cf_browser:lower()
  end

  -- 1. Check omarchy-cmd-default-browser on Arch / Omarchy
  if vim.fn.executable("omarchy-cmd-default-browser") == 1 then
    local res = vim.system({ "omarchy-cmd-default-browser" }, { text = true }):wait()
    if res.code == 0 and res.stdout and vim.trim(res.stdout) ~= "" then
      local val = vim.trim(res.stdout):lower():gsub("%.desktop$", "")
      for _, name in ipairs({ "chromium", "google-chrome", "chrome", "helium", "brave", "firefox", "zen", "floorp", "librewolf", "waterfox", "edge" }) do
        if val:find(name) then
          return (name == "google-chrome") and "chrome" or name
        end
      end
    end
  end

  -- 2. Check xdg-settings on Linux
  if vim.fn.executable("xdg-settings") == 1 then
    local res = vim.system({ "xdg-settings", "get", "default-web-browser" }, { text = true }):wait()
    if res.code == 0 and res.stdout then
      local val = res.stdout:lower():gsub("%.desktop$", "")
      for _, name in ipairs({ "chromium", "google-chrome", "chrome", "helium", "brave", "firefox", "zen", "floorp", "librewolf", "waterfox", "edge" }) do
        if val:find(name) then
          return (name == "google-chrome") and "chrome" or name
        end
      end
    end
  end

  -- 3. Check xdg-mime on Linux (http and https handlers)
  if vim.fn.executable("xdg-mime") == 1 then
    for _, scheme in ipairs({ "x-scheme-handler/http", "x-scheme-handler/https" }) do
      local res = vim.system({ "xdg-mime", "query", "default", scheme }, { text = true }):wait()
      if res.code == 0 and res.stdout then
        local val = res.stdout:lower():gsub("%.desktop$", "")
        for _, name in ipairs({ "chromium", "google-chrome", "chrome", "helium", "brave", "firefox", "zen", "floorp", "librewolf", "waterfox", "edge" }) do
          if val:find(name) then
            return (name == "google-chrome") and "chrome" or name
          end
        end
      end
    end
  end

  -- 4. Check $BROWSER environment variable
  local browser_env = (vim.env.BROWSER or ""):lower()
  if browser_env ~= "" then
    for _, name in ipairs({ "chromium", "google-chrome", "chrome", "helium", "brave", "firefox", "zen", "floorp", "librewolf", "waterfox", "edge" }) do
      if browser_env:find(name) then
        return (name == "google-chrome") and "chrome" or name
      end
    end
  end

  -- 5. macOS default browser check
  if vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1 then
    local res = vim.system({ "defaults", "read", "com.apple.LaunchServices/com.apple.launchservices.secure", "LSHandlers" }, { text = true }):wait()
    if res.code == 0 and res.stdout then
      local val = res.stdout:lower()
      for _, name in ipairs({ "chromium", "chrome", "brave", "firefox", "zen", "floorp", "librewolf", "waterfox", "safari" }) do
        if val:find(name) then
          return name
        end
      end
    end
  end

  return nil
end

-- Candidate paths for persistent consent storage across restarts
-- Stored strictly in local machine state directory (~/.local/state/nvim/)
local function get_consent_file()
  local state_dir = vim.fn.stdpath("state")
  pcall(vim.fn.mkdir, state_dir, "p")
  local candidates = {
    state_dir .. "/cf_cookie_consent.txt",
    vim.fn.stdpath("data") .. "/cf_cookie_consent.txt",
    (vim.env.HOME or "") .. "/.cf_cookie_consent.txt",
    "/tmp/cf_cookie_consent.txt",
  }
  for _, path in ipairs(candidates) do
    if vim.fn.filereadable(path) == 1 then
      return path
    end
  end
  return candidates[1]
end

-- ==============================================================================
-- Global Cookie Consent System
-- ==============================================================================
-- If disabled by the user via <leader>rk, Neovim will NEVER access, read, or
-- touch browser cookies or sqlite files. Submissions will directly use cph-submit.
function M.is_cookie_allowed()
  local file = get_consent_file()
  if vim.fn.filereadable(file) == 1 then
    local lines = vim.fn.readfile(file)
    if #lines > 0 then
      local val = vim.trim(lines[1]):lower()
      if val == "disabled" or val == "false" or val == "0" or val == "no" then
        return false
      end
      if val == "enabled" or val == "true" or val == "1" or val == "yes" then
        return true
      end
    end
  end
  -- Default is enabled
  return true
end

function M.set_cookie_allowed(allowed)
  local val = allowed and "enabled" or "disabled"
  local state_dir = vim.fn.stdpath("state")
  pcall(vim.fn.mkdir, state_dir, "p")
  local candidates = {
    state_dir .. "/cf_cookie_consent.txt",
    vim.fn.stdpath("data") .. "/cf_cookie_consent.txt",
    (vim.env.HOME or "") .. "/.cf_cookie_consent.txt",
    "/tmp/cf_cookie_consent.txt",
  }
  for _, path in ipairs(candidates) do
    local ok, res = pcall(vim.fn.writefile, { val }, path)
    if ok and res == 0 then
      return true
    end
  end
  return false
end

function M.toggle_cookie_allowed()
  local current = M.is_cookie_allowed()
  local new_state = not current
  M.set_cookie_allowed(new_state)
  if new_state then
    vim.notify("🍪 Codeforces Headless Cookie Submission: ENABLED globally.\nUsing browser cookies for instant 1-click submission.", vim.log.levels.INFO, { title = "Cookie Consent" })
  else
    vim.notify("🔒 Codeforces Headless Cookie Submission: DISABLED globally.\nBrowser cookies will NEVER be read or accessed.\nSubmissions will use cph-submit via browser.", vim.log.levels.WARN, { title = "Cookie Consent" })
  end
  return new_state
end

-- ==============================================================================
-- Browser Profile Discovery
-- ==============================================================================
function M.find_cookie_database()
  if M.custom_cookie_path and vim.fn.filereadable(M.custom_cookie_path) == 1 then
    M.last_detected_browser = "Custom Browser"
    return M.custom_cookie_path
  end

  local browser_globs = {
    chromium = {
      name = "Chromium",
      type = "chromium",
      patterns = {
        "~/.config/chromium/Default/Cookies",
        "~/.config/chromium/*/Cookies",
        "~/Library/Application Support/Chromium/Default/Cookies",
        "~/Library/Application Support/Chromium/*/Cookies",
      },
    },
    chrome = {
      name = "Google Chrome",
      type = "chromium",
      patterns = {
        "~/.config/google-chrome/Default/Cookies",
        "~/.config/google-chrome/*/Cookies",
        "~/Library/Application Support/Google/Chrome/Default/Cookies",
        "~/Library/Application Support/Google/Chrome/*/Cookies",
      },
    },
    helium = {
      name = "Helium",
      type = "chromium",
      patterns = {
        "~/.config/helium/Default/Cookies",
        "~/.config/helium/*/Cookies",
        "~/Library/Application Support/Helium/Default/Cookies",
        "~/Library/Application Support/Helium/*/Cookies",
      },
    },
    brave = {
      name = "Brave",
      type = "chromium",
      patterns = {
        "~/.config/BraveSoftware/Brave-Browser/Default/Cookies",
        "~/.config/BraveSoftware/Brave-Browser/*/Cookies",
        "~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies",
        "~/Library/Application Support/BraveSoftware/Brave-Browser/*/Cookies",
      },
    },
    edge = {
      name = "Microsoft Edge",
      type = "chromium",
      patterns = {
        "~/.config/microsoft-edge/Default/Cookies",
        "~/.config/microsoft-edge/*/Cookies",
        "~/Library/Application Support/Microsoft Edge/Default/Cookies",
      },
    },
    firefox = {
      name = "Firefox",
      type = "gecko",
      patterns = {
        "~/.mozilla/firefox/*/cookies.sqlite",
        "~/Library/Application Support/Firefox/Profiles/*/cookies.sqlite",
      },
    },
    zen = {
      name = "Zen Browser",
      type = "gecko",
      patterns = {
        "~/.config/zen/*/cookies.sqlite",
        "~/.zen/*/cookies.sqlite",
        "~/Library/Application Support/zen/Profiles/*/cookies.sqlite",
      },
    },
    floorp = {
      name = "Floorp",
      type = "gecko",
      patterns = {
        "~/.floorp/*/cookies.sqlite",
        "~/.config/floorp/*/cookies.sqlite",
        "~/Library/Application Support/Floorp/Profiles/*/cookies.sqlite",
      },
    },
    librewolf = {
      name = "LibreWolf",
      type = "gecko",
      patterns = {
        "~/.librewolf/*/cookies.sqlite",
        "~/.config/librewolf/*/cookies.sqlite",
        "~/Library/Application Support/LibreWolf/Profiles/*/cookies.sqlite",
      },
    },
    waterfox = {
      name = "Waterfox",
      type = "gecko",
      patterns = {
        "~/.waterfox/*/cookies.sqlite",
        "~/Library/Application Support/Waterfox/Profiles/*/cookies.sqlite",
      },
    },
  }

  local function check_has_cf_cookies(path, btype)
    if vim.fn.filereadable(path) ~= 1 then
      return false, 0
    end
    local uri = string.format("file:%s?immutable=1", path)
    if btype == "gecko" then
      local obj = vim.system({ "sqlite3", uri, "SELECT count(*) FROM moz_cookies WHERE host LIKE '%codeforces.com%';" }, { text = true }):wait()
      if obj.code == 0 and obj.stdout then
        local count = tonumber(vim.trim(obj.stdout)) or 0
        return count > 0, count
      end
    else
      local obj = vim.system({ "sqlite3", uri, "SELECT count(*) FROM cookies WHERE host_key LIKE '%codeforces.com%';" }, { text = true }):wait()
      if obj.code == 0 and obj.stdout then
        local count = tonumber(vim.trim(obj.stdout)) or 0
        return count > 0, count
      end
    end
    return false, 0
  end

  local function get_best_match(entry, require_cf_cookies)
    local matches = {}
    for _, pat in ipairs(entry.patterns) do
      local found = vim.fn.glob(pat, false, true)
      for _, f in ipairs(found) do
        if vim.fn.filereadable(f) == 1 then
          local has_cf, count = check_has_cf_cookies(f, entry.type)
          if not require_cf_cookies or has_cf then
            table.insert(matches, {
              path = f,
              mtime = vim.fn.getftime(f),
              has_cf = has_cf,
              count = count,
            })
          end
        end
      end
    end
    if #matches == 0 then
      return nil
    end
    table.sort(matches, function(a, b)
      if a.has_cf ~= b.has_cf then
        return a.has_cf
      end
      if a.count ~= b.count and a.count > 0 and b.count > 0 then
        return a.count > b.count
      end
      return a.mtime > b.mtime
    end)
    return matches[1].path
  end

  -- 1. Check user default browser for profiles with active Codeforces cookies
  local default_bname = get_system_default_browser_name()
  if default_bname and browser_globs[default_bname] then
    local best = get_best_match(browser_globs[default_bname], true)
    if best then
      M.last_detected_browser = browser_globs[default_bname].name
      return best
    end
  end

  -- 2. Check all other installed browsers for profiles with active Codeforces cookies
  local all_with_cf = {}
  for _, entry in pairs(browser_globs) do
    local best = get_best_match(entry, true)
    if best then
      table.insert(all_with_cf, {
        path = best,
        name = entry.name,
        mtime = vim.fn.getftime(best),
      })
    end
  end

  if #all_with_cf > 0 then
    table.sort(all_with_cf, function(a, b)
      return a.mtime > b.mtime
    end)
    M.last_detected_browser = all_with_cf[1].name
    return all_with_cf[1].path
  end

  -- 3. Fallback: if no browser has Codeforces cookies yet, return the default browser profile
  if default_bname and browser_globs[default_bname] then
    local fallback = get_best_match(browser_globs[default_bname], false)
    if fallback then
      M.last_detected_browser = browser_globs[default_bname].name
      return fallback
    end
  end

  -- 4. Final fallback: return any existing browser profile
  for _, entry in pairs(browser_globs) do
    local best = get_best_match(entry, false)
    if best then
      M.last_detected_browser = entry.name
      return best
    end
  end

  M.last_detected_browser = nil
  return nil
end

local function get_user_agent()
  local is_mac = vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1
  if is_mac then
    return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:134.0) Gecko/20100101 Firefox/134.0"
  else
    return "Mozilla/5.0 (X11; Linux x86_64; rv:134.0) Gecko/20100101 Firefox/134.0"
  end
end

local function open_url_in_browser(target_url)
  if vim.ui and vim.ui.open then
    vim.ui.open(target_url)
  elseif vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1 then
    vim.system({ "open", target_url }, { detach = true })
  else
    vim.system({ "xdg-open", target_url }, { detach = true })
  end
end

-- ==============================================================================
-- Cookie Extraction (Zero Interference / Immutable SQLite Mode)
-- ==============================================================================
function M.export_cookie_jar(cookie_db, jar_path)
  if vim.fn.executable("sqlite3") == 0 then
    return false, "sqlite3 is not installed"
  end

  local uri = string.format("file:%s?immutable=1", cookie_db)
  local browser_label = M.last_detected_browser or "default browser"

  -- 1. Check for Gecko (moz_cookies) table
  local check_gecko = vim.system({ "sqlite3", uri, "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='moz_cookies';" }, { text = true }):wait()
  if check_gecko.code == 0 and vim.trim(check_gecko.stdout or "") == "1" then
    local query = "SELECT host, CASE WHEN host LIKE '.%' THEN 'TRUE' ELSE 'FALSE' END, path, CASE WHEN isSecure = 1 THEN 'TRUE' ELSE 'FALSE' END, expiry, name, value FROM moz_cookies WHERE host LIKE '%codeforces.com%';"
    local cmd = { "sqlite3", "-separator", "\t", uri, query }
    local obj = vim.system(cmd, { text = true }):wait()
    if obj.code ~= 0 or not obj.stdout or obj.stdout == "" then
      return false, "No Codeforces cookies found in " .. browser_label
    end

    local header = "# Netscape HTTP Cookie File\n# http://curl.haxx.se/rfc/cookie_spec.html\n# This is a generated file! Do not edit.\n\n"
    local f = io.open(jar_path, "w")
    if not f then
      return false, "Failed to write cookie jar to " .. jar_path
    end
    f:write(header .. obj.stdout)
    f:close()
    pcall(vim.fn.setfperm, jar_path, "rw-------")
    return true, nil
  end

  -- 2. Check for Chromium (cookies) table
  local check_chrom = vim.system({ "sqlite3", uri, "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='cookies';" }, { text = true }):wait()
  if check_chrom.code == 0 and vim.trim(check_chrom.stdout or "") == "1" then
    local query = "SELECT host_key, CASE WHEN host_key LIKE '.%' THEN 'TRUE' ELSE 'FALSE' END, path, CASE WHEN is_secure = 1 THEN 'TRUE' ELSE 'FALSE' END, expires_utc, name, value, hex(encrypted_value) FROM cookies WHERE host_key LIKE '%codeforces.com%';"
    local cmd = { "sqlite3", "-separator", "\t", uri, query }
    local obj = vim.system(cmd, { text = true }):wait()
    if obj.code ~= 0 or not obj.stdout or obj.stdout == "" then
      return false, "No Codeforces cookies found in " .. browser_label
    end

    local lines = vim.split(vim.trim(obj.stdout), "\n")
    local cookies = {}
    local has_encrypted = false

    for _, line in ipairs(lines) do
      local parts = vim.split(line, "\t")
      if #parts >= 7 then
        local host = parts[1]
        local is_domain = parts[2]
        local path = parts[3]
        local is_secure = parts[4]
        local expires = parts[5]
        local name = parts[6]
        local value = parts[7]
        local enc_hex = parts[8] or ""

        if value and value ~= "" then
          table.insert(cookies, string.format("%s\t%s\t%s\t%s\t%s\t%s\t%s", host, is_domain, path, is_secure, expires, name, value))
        elseif enc_hex ~= "" then
          has_encrypted = true
        end
      end
    end

    if #cookies > 0 then
      local header = "# Netscape HTTP Cookie File\n# http://curl.haxx.se/rfc/cookie_spec.html\n# This is a generated file! Do not edit.\n\n"
      local f = io.open(jar_path, "w")
      if f then
        f:write(header .. table.concat(cookies, "\n") .. "\n")
        f:close()
        pcall(vim.fn.setfperm, jar_path, "rw-------")
        return true, nil
      end
    end

    if has_encrypted then
      return false, "chromium_keyring_locked"
    end

    return false, "No valid Codeforces session cookies found in " .. browser_label
  end

  return false, "Unrecognized browser database format in " .. cookie_db
end

-- ==============================================================================
-- Problem & Contest Identification
-- ==============================================================================
function M.parse_contest_and_problem(url, filepath)
  local contest_id, problem_index

  if url and url ~= "" then
    contest_id, problem_index = url:match("contest/(%d+)/problem/([%w_]+)")
    if not contest_id then
      contest_id, problem_index = url:match("problemset/problem/(%d+)/([%w_]+)")
    end
    if not contest_id then
      contest_id, problem_index = url:match("gym/(%d+)/problem/([%w_]+)")
    end
  end

  if not contest_id and filepath then
    contest_id = filepath:match("Codeforces[/\\](%d+)")
      or filepath:match("contest[/\\](%d+)")
      or filepath:match("Round_(%d+)")
      or filepath:match("Round_([%d]+)")
  end

  if not problem_index and filepath then
    local filename = vim.fn.fnamemodify(filepath, ":t")
    problem_index = filename:match("^([A-Z]%d?)_")
      or filename:match("^([A-Z]%d?)%.")
      or filename:match("^([A-Z]%d?)$")
  end

  return contest_id, problem_index
end

-- ==============================================================================
-- Headless Direct Cookie Submission
-- ==============================================================================
function M.submit(url, filepath, callback)
  -- 1. Check Global User Consent
  if not M.is_cookie_allowed() then
    callback(false, "cookie_submit_disabled")
    return
  end

  -- 2. Locate Browser Cookie Database
  local cookie_db = M.find_cookie_database()
  if not cookie_db then
    callback(false, "no_cookie_db_found")
    return
  end

  -- 3. Parse Contest ID and Problem Index
  local contest_id, problem_index = M.parse_contest_and_problem(url, filepath)
  if not contest_id or not problem_index then
    callback(false, "could_not_parse_contest_or_problem")
    return
  end

  -- 4. Export Cookie Jar Non-destructively
  local username = vim.env.USER or "cf_user"
  local jar_path = string.format("/tmp/cf_jar_%s.txt", username)
  local export_ok, export_err = M.export_cookie_jar(cookie_db, jar_path)
  if not export_ok then
    callback(false, export_err or "failed_to_export_cookies")
    return
  end

  -- 5. Prepare URLs and User-Agent
  local is_gym = url:find("/gym/") ~= nil
  local submit_url = is_gym and string.format("https://codeforces.com/gym/%s/submit", contest_id)
    or string.format("https://codeforces.com/contest/%s/submit", contest_id)
  local ua = get_user_agent()

  -- 6. Fetch Submit Page to Extract CSRF Token and Verify Authentication
  local get_cmd = {
    "curl", "-s",
    "-A", ua,
    "-b", jar_path,
    "-c", jar_path,
    submit_url,
  }

  vim.system(get_cmd, { text = true }, function(get_obj)
    if get_obj.code ~= 0 or not get_obj.stdout or get_obj.stdout == "" then
      vim.schedule(function()
        callback(false, "failed_to_reach_codeforces")
      end)
      return
    end

    local html = get_obj.stdout

    -- Check for Cloudflare challenge
    if html:find("Just a moment...") or html:find("challenge%-error%-text") or html:find("cf%-mitigated") then
      vim.schedule(function()
        callback(false, "cloudflare_challenge")
      end)
      return
    end

    -- Verify Login Status: look for authenticated handle
    local handle = html:match('handle%s*=%s*"([^"]+)"')
    if not handle or handle == "" or (html:find('href="/enter"') and not html:find('href="/logout"')) then
      vim.schedule(function()
        vim.notify("⚠️ Not logged in to Codeforces. Opening login page in browser...", vim.log.levels.WARN, { title = "Codeforces Login" })
        open_url_in_browser("https://codeforces.com/enter")
        callback(false, "not_logged_in")
      end)
      return
    end

    -- Extract CSRF Token
    local csrf = html:match('<meta%s+name="X%-Csrf%-Token"%s+content="([a-f0-9]+)"')
      or html:match('data%-csrf=[\'"]([a-f0-9]+)[\'"]')
      or html:match('csrf_token%s*=%s*"([a-f0-9]+)"')
      or html:match('name="csrf_token"%s+value="([a-f0-9]+)"')

    if not csrf or csrf == "" then
      vim.schedule(function()
        callback(false, "csrf_token_not_found")
      end)
      return
    end

    -- 7. Read Source Code and Append Unique Timestamp Comment
    -- (Prevents "You have submitted exactly the same code before" rejection)
    local f = io.open(filepath, "r")
    if not f then
      vim.schedule(function()
        callback(false, "cannot_read_source_file")
      end)
      return
    end
    local original_code = f:read("*a")
    f:close()

    local unique_code = string.format("%s\n[[maybe_unused]] static const long long __cf_sub_ts = %dLL;\n// submit id: %d\n", original_code, os.time(), os.time())
    local temp_src = string.format("/tmp/__cf_sub_%s_%s_%d.cpp", contest_id, problem_index, os.time())
    local tf = io.open(temp_src, "w")
    if not tf then
      vim.schedule(function()
        callback(false, "cannot_write_temp_submission_file")
      end)
      return
    end
    tf:write(unique_code)
    tf:close()

    -- 8. POST Multipart Form Submission via curl
    local post_url = string.format("%s?csrf_token=%s", submit_url, csrf)
    local post_cmd = {
      "curl", "-s", "-i",
      "-X", "POST",
      "-A", ua,
      "-b", jar_path,
      "-c", jar_path,
      "-H", "Referer: " .. submit_url,
      "-H", "Origin: https://codeforces.com",
      "-F", "csrf_token=" .. csrf,
      "-F", "action=submitSolutionFormSubmitted",
      "-F", "submittedProblemIndex=" .. problem_index,
      "-F", "programTypeId=91",
      "-F", string.format("sourceFile=@%s;filename=%s;type=text/x-c++src", temp_src, vim.fn.fnamemodify(filepath, ":t")),
      "-F", "tabSize=4",
      "-F", "sourceCodeConfirmed=true",
      post_url,
    }

    vim.system(post_cmd, { text = true }, function(post_obj)
      pcall(vim.fn.delete, temp_src)

      local post_resp = post_obj.stdout or ""

      -- Codeforces redirects to /contest/<id>/my or /my with HTTP 302 on success
      local is_redirect = post_resp:find("302 Found")
        or post_resp:find("302 Moved")
        or post_resp:find("HTTP/%S+%s+302")

      local has_my_location = post_resp:lower():find("location:%s*/?contest/%d+/my")
        or post_resp:lower():find("location:%s*/?gym/%d+/my")
        or post_resp:lower():find("location:%s*https?://[^/\r\n]+/contest/%d+/my")
        or post_resp:lower():find("location:%s*https?://[^/\r\n]+/gym/%d+/my")

      vim.schedule(function()
        if is_redirect or has_my_location then
          callback(true, {
            handle = handle,
            contest_id = contest_id,
            problem_index = problem_index,
          })
        else
          -- Extract any form error message from HTML body
          local err_msg = post_resp:match('<span%s+class="error%s+for__[^"]*"%s*>(.-)</span>')
            or post_resp:match('<span%s+class="error"%s*>(.-)</span>')
          callback(false, err_msg or "codeforces_submission_rejected")
        end
      end)
    end)
  end)
end

return M
